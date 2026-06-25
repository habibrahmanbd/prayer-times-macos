import AppKit
import SwiftUI
import OSLog
import PrayerKit

/// Owns the Focus Mode screen block: a full-screen overlay on every display that
/// covers the desktop at prayer time, holds for a configured duration, then
/// releases. A *discipline aid*, not a true lock — macOS always allows Force Quit
/// — so the design leans on covering, focus capture, and hiding the Dock/menu bar
/// rather than pretending to be a kiosk.
@MainActor
final class FocusModeController {

    private let log = Logger(subsystem: "co.tareq.prayertimes", category: "focus")

    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var releaseTask: Task<Void, Never>?
    private var priorPolicy: NSApplication.ActivationPolicy = .accessory
    private var priorPresentation: NSApplication.PresentationOptions = []

    /// Whether a block is currently up (prevents overlapping prayers stacking).
    private(set) var isActive = false

    // MARK: Entry points

    /// Begin a real block for `prayer`, honoring the safeguards: never engage when
    /// the screen is locked or a fullscreen app (likely a call/presentation) is
    /// frontmost — those would be the worst moments to black out the screen.
    func begin(prayer: Prayer, settings: AppSettings) {
        guard !isActive else { return }
        if sessionIsLocked() {
            log.debug("Focus skipped: session locked")
            return
        }
        if frontmostAppIsFullscreen() {
            log.debug("Focus skipped: a fullscreen app is frontmost")
            return
        }
        start(prayer: prayer,
              duration: TimeInterval(max(1, settings.focusDurationMinutes) * 60),
              emergencyExit: settings.focusEmergencyExitEnabled,
              intensity: settings.focusBlurIntensity)
    }

    /// Short preview for the Settings "Try it" button: always engages (ignores the
    /// fullscreen/lock safeguards) and always allows the emergency exit, so the
    /// user can confirm the look and that Cmd+Esc works before relying on it.
    func runDemo(settings: AppSettings) {
        guard !isActive else { return }
        start(prayer: .dhuhr, duration: 10, emergencyExit: true, intensity: settings.focusBlurIntensity)
    }

    /// Release the block immediately (timer expiry, emergency exit, or programmatic).
    func end() {
        guard isActive else { return }
        isActive = false
        releaseTask?.cancel(); releaseTask = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let globalKeyMonitor { NSEvent.removeMonitor(globalKeyMonitor); self.globalKeyMonitor = nil }

        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            for w in closing { w.animator().alphaValue = 0 }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            for w in closing { w.orderOut(nil); w.close() }
        }

        NSApp.presentationOptions = priorPresentation
        NSApp.setActivationPolicy(priorPolicy)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
        log.debug("Focus ended")
    }

    // MARK: Block lifecycle

    private func start(prayer: Prayer, duration: TimeInterval, emergencyExit: Bool, intensity: FocusBlurIntensity) {
        log.debug("Focus begin: \(prayer.rawValue, privacy: .public) for \(Int(duration))s")
        isActive = true
        priorPolicy = NSApp.activationPolicy()
        priorPresentation = NSApp.presentationOptions

        NSApp.setActivationPolicy(.regular)
        // Hide the Dock and menu bar and steer the user away from app-switching.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching,
                                     .disableAppleMenu, .disableHideApplication]

        let endsAt = Date().addingTimeInterval(duration)
        let scripture = FocusScripture.random()
        // Build windows first so there are real on-screen windows to receive focus,
        // then activate — this ensures the key-window routing is established before
        // the local key monitor begins listening.
        buildWindows(prayer: prayer, scripture: scripture, endsAt: endsAt, emergencyExit: emergencyExit, intensity: intensity)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor(emergencyExit: emergencyExit)

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.end()
        }

        // Remember inputs so a display reconfiguration can rebuild the overlays.
        rebuildContext = (prayer, scripture, endsAt, emergencyExit, intensity)
    }

    private var rebuildContext: (prayer: Prayer, scripture: FocusScripture, endsAt: Date, emergencyExit: Bool, intensity: FocusBlurIntensity)?

    private func buildWindows(prayer: Prayer, scripture: FocusScripture, endsAt: Date, emergencyExit: Bool, intensity: FocusBlurIntensity) {
        for screen in NSScreen.screens {
            let root = FocusOverlayView(prayer: prayer, scripture: scripture, endsAt: endsAt,
                                        emergencyExitEnabled: emergencyExit, intensity: intensity)
            let window = OverlayWindow(
                contentRect: screen.frame, styleMask: [.borderless],
                backing: .buffered, defer: false)
            if emergencyExit {
                window.onEmergencyExit = { [weak self] in self?.end() }
            }
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.alphaValue = 0

            // Desktop blur behind the SwiftUI overlay; intensity is carried mostly
            // by the overlay's own backdrop opacity.
            let blur = NSVisualEffectView()
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            let hosting = NSHostingView(rootView: root)
            hosting.frame = blur.bounds
            hosting.autoresizingMask = [.width, .height]
            blur.addSubview(hosting)
            window.contentView = blur

            window.setFrame(screen.frame, display: true)
            // The primary display window claims key status via makeKeyAndOrderFront
            // (processed through the normal activation path) so keyboard events are
            // reliably routed here. Secondary windows are ordered front without
            // stealing key — only one window should be key at a time.
            if windows.isEmpty {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            window.animator().alphaValue = 1
            windows.append(window)
        }
    }

    @objc private func screensChanged() {
        guard isActive, let ctx = rebuildContext else { return }
        for w in windows { w.orderOut(nil); w.close() }
        windows = []
        buildWindows(prayer: ctx.prayer, scripture: ctx.scripture, endsAt: ctx.endsAt,
                     emergencyExit: ctx.emergencyExit, intensity: ctx.intensity)
    }

    // MARK: Input capture

    /// Swallow keystrokes while the block is up; Cmd+Esc releases it when the
    /// emergency exit is enabled. (Global system shortcuts like Cmd+Opt+Esc are
    /// handled by the WindowServer and intentionally remain available.)
    ///
    /// Two monitors are installed:
    /// - A *local* monitor catches key events already routed to this app's windows.
    /// - A *global* monitor catches key events routed to any *other* app — a
    ///   fallback for the rare race where the WindowServer hasn't yet made the
    ///   overlay window key by the time the user presses the emergency shortcut.
    private func installKeyMonitor(emergencyExit: Bool) {
        // Local key swallowing is handled in `OverlayWindow.sendEvent(_:)` so the
        // same path both blocks input and handles emergency exit.
        keyMonitor = nil

        guard emergencyExit else { return }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isEmergencyExitShortcut(event) {
                Task { @MainActor [weak self] in self?.end() }
            }
        }
    }

    fileprivate static func isEmergencyExitShortcut(_ event: NSEvent, commandDownFallback: Bool = false) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || commandDownFallback else { return false }

        if event.keyCode == 53 { return true } // Esc
        if event.charactersIgnoringModifiers?.lowercased() == "x" { return true } // X
        return false
    }

    // MARK: Safeguards

    private func sessionIsLocked() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Int) == 1
    }

    /// Heuristic: the frontmost app owns an on-screen, base-layer window that covers
    /// a whole display ⇒ it's running fullscreen (Keynote, a video call, full-screen
    /// video). We require the window to match the screen's *full* frame, which a
    /// merely maximized window doesn't (it fills only `visibleFrame`, below the menu
    /// bar), so ordinary maximized windows don't trigger a skip. Public APIs only —
    /// reads PID/layer/bounds, not window names, so no Screen Recording prompt.
    private func frontmostAppIsFullscreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = front.processIdentifier
        let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return false }
        for info in infos {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = b["Width"], let h = b["Height"] else { continue }
            for screen in NSScreen.screens where abs(w - screen.frame.width) < 2 && abs(h - screen.frame.height) < 2 {
                return true
            }
        }
        return false
    }
}

/// Borderless windows can't become key by default; the overlay needs key status to
/// receive the emergency-exit keystroke and to keep focus on itself.
private final class OverlayWindow: NSWindow {
    var onEmergencyExit: (() -> Void)?
    private var commandIsDown = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            commandIsDown = flags.contains(.command)
            return
        }
        if event.type == .keyDown {
            if FocusModeController.isEmergencyExitShortcut(event, commandDownFallback: commandIsDown) {
                onEmergencyExit?()
            }
            return
        }
        if event.type == .keyUp {
            return
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if FocusModeController.isEmergencyExitShortcut(event, commandDownFallback: commandIsDown) {
            onEmergencyExit?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if FocusModeController.isEmergencyExitShortcut(event, commandDownFallback: commandIsDown) {
            onEmergencyExit?()
            return
        }
        super.keyDown(with: event)
    }
}
