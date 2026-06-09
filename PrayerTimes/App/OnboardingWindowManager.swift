import AppKit
import SwiftUI
import OSLog

/// Owns the first-launch setup wizard window. Like `SettingsWindowManager`, it
/// drives the window directly (an `LSUIElement` agent has no app menu / responder
/// chain for SwiftUI window scenes): while the wizard is up the app is a regular
/// Dock app so it can take focus, and it drops back to a menu-bar agent on close.
@MainActor
final class OnboardingWindowManager: NSObject, NSWindowDelegate {
    private let settings: SettingsStore
    private let notifications: NotificationService
    private var window: NSWindow?
    private let log = Logger(subsystem: "co.tareq.prayertimes", category: "onboarding")

    init(settings: SettingsStore, notifications: NotificationService) {
        self.settings = settings
        self.notifications = notifications
    }

    /// Show the wizard only when it hasn't been completed/skipped yet.
    func showIfNeeded() {
        guard settings.needsOnboarding else { return }
        show()
    }

    func show() {
        if window == nil { buildWindow() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }

    private func buildWindow() {
        let root = OnboardingView(
            settings: settings,
            notifications: notifications,
            onFinish: { [weak self] in self?.close() }
        )
        let host = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.title = String(localized: "Set Up Prayer Times")
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.delegate = self
        self.window = window
        log.debug("Built onboarding wizard window")
    }

    private func close() {
        window?.close()
    }

    /// Closing the window (Finish, Skip, or the red button) counts as completing
    /// the wizard so it won't reappear, and hands focus back to the menu bar.
    /// Dropping the window reference means the next `show()` rebuilds a fresh
    /// wizard starting at the welcome step.
    func windowWillClose(_ notification: Notification) {
        settings.completeOnboarding()
        NSApp.setActivationPolicy(.accessory)
        window = nil
        log.debug("Onboarding window closed; onboarding marked complete")
    }

    /// Clear the completion flag and present the wizard from the top (the
    /// General tab's "Run setup again").
    func restart() {
        window?.close()
        window = nil
        settings.resetOnboarding()
        show()
    }
}
