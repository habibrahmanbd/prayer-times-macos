import SwiftUI
import PrayerKit

/// First-launch setup wizard. Walks a new user through the choices that are
/// otherwise spread across the five Settings tabs — location, calculation +
/// madhab, notifications, menu-bar display, and Focus Mode — in one designed pass.
///
/// Layout is a branded left rail (wordmark + a vertical step tracker) beside a
/// content pane (hero header + selectable option cards). Every control writes
/// straight through to `SettingsStore` (no staging), so quitting part-way keeps
/// what was chosen; `onFinish` just records completion.
struct OnboardingView: View {
    @Bindable var settings: SettingsStore
    let notifications: NotificationService
    let onFinish: () -> Void

    enum Step: Int, CaseIterable {
        case welcome, location, calculation, notifications, display, focus, done

        /// Header symbol / title / subtitle for the content hero.
        var header: (symbol: String, title: LocalizedStringKey, subtitle: LocalizedStringKey)? {
            switch self {
            case .welcome, .done: return nil
            case .location: return ("location.fill", "Where are you?", "So we compute the right times for your place.")
            case .calculation: return ("moon.stars.fill", "How should we calculate?", "Pick a method and your Asr madhab.")
            case .notifications: return ("bell.badge.fill", "Stay on time", "A nudge — and optionally the Adhan — at each prayer.")
            case .display: return ("menubar.rectangle", "How it looks", "Choose what shows in your menu bar.")
            case .focus: return ("eye.slash.fill", "Focus Mode", "An optional screen cover at prayer time.")
            }
        }
    }

    /// The five middle stages shown in the rail tracker (welcome/done bookend them).
    private static let stages: [(title: LocalizedStringKey, symbol: String)] = [
        ("Location", "location.fill"),
        ("Calculation", "moon.stars.fill"),
        ("Notifications", "bell.badge.fill"),
        ("Display", "menubar.rectangle"),
        ("Focus", "eye.slash.fill"),
    ]

    @State private var step: Step = .welcome

    var body: some View {
        HStack(spacing: 0) {
            rail
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                Divider()
                footer
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 760, height: 560)
        .task { await notifications.refreshAuthorizationStatus() }
    }

    // MARK: Rail

    private var rail: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.brand, Color.brand.opacity(0.78), Color(red: 0.06, green: 0.24, blue: 0.13)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // soft glow
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
                .blendMode(.plusLighter)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image("Mosque")
                        .renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(.white)
                    Text("Prayer Times").font(.headline.weight(.semibold)).foregroundStyle(.white)
                }
                .padding(.bottom, 34)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(Self.stages.enumerated()), id: \.offset) { idx, stage in
                        railRow(index: idx, title: stage.title, symbol: stage.symbol)
                    }
                }

                Spacer()

                Text("Step \(min(step.rawValue + 1, Step.allCases.count)) of \(Step.allCases.count)")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
        }
        .frame(width: 232)
    }

    /// State of a rail stage relative to the current step.
    private func railState(_ index: Int) -> (done: Bool, active: Bool) {
        let active = activeStageIndex
        if step == .done { return (true, false) }
        return (index < active, index == active)
    }

    /// Which rail stage the current step maps to (-1 on welcome, 5 on done).
    private var activeStageIndex: Int {
        switch step {
        case .welcome: return -1
        case .location: return 0
        case .calculation: return 1
        case .notifications: return 2
        case .display: return 3
        case .focus: return 4
        case .done: return 5
        }
    }

    private func railRow(index: Int, title: LocalizedStringKey, symbol: String) -> some View {
        let s = railState(index)
        return HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(s.active ? Color.white : .white.opacity(s.done ? 0.95 : 0.16))
                    .frame(width: 26, height: 26)
                if s.done {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.brand)
                } else {
                    Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(s.active ? Color.brand : .white.opacity(0.85))
                }
            }
            Text(title)
                .font(.subheadline.weight(s.active ? .semibold : .regular))
                .foregroundStyle(s.active || s.done ? .white : .white.opacity(0.7))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(s.active ? .white.opacity(0.16) : .clear))
        .animation(.snappy(duration: 0.2), value: activeStageIndex)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let h = step.header { heroHeader(h.symbol, h.title, h.subtitle) }
                switch step {
                case .welcome: welcomeStep
                case .location: locationStep
                case .calculation: calculationStep
                case .notifications: notificationsStep
                case .display: displayStep
                case .focus: focusStep
                case .done: doneStep
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func heroHeader(_ symbol: String, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.brand)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.brand.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title.weight(.bold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Image("Mosque")
                .renderingMode(.template).resizable().scaledToFit()
                .frame(width: 88, height: 88)
                .foregroundStyle(Color.brand)
                .shadow(color: Color.brand.opacity(0.3), radius: 16, y: 4)
            VStack(spacing: 8) {
                Text("Welcome to Prayer Times").font(.system(size: 30, weight: .bold))
                Text("Let's set things up in a few quick steps. You can change any of this later in Settings.")
                    .font(.title3).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
            }
            VStack(alignment: .leading, spacing: 14) {
                featureRow("location.fill", "Accurate times for your exact location")
                featureRow("bell.badge.fill", "Notifications and the Adhan, your way")
                featureRow("eye.slash.fill", "Focus Mode to pause and pray")
            }
            .padding(.top, 8)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.brand).frame(width: 22)
            Text(text).font(.callout)
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                OptionCard(symbol: "location.fill", title: "Automatic",
                           subtitle: "Detect where you are", selected: settings.settings.locationMode == .automatic) {
                    locationModeBinding.wrappedValue = .automatic
                }
                OptionCard(symbol: "pencil", title: "Manual",
                           subtitle: "Enter coordinates", selected: settings.settings.locationMode == .manual) {
                    locationModeBinding.wrappedValue = .manual
                }
            }

            if settings.settings.locationMode == .automatic {
                groupCard {
                    HStack(spacing: 10) {
                        Button {
                            Task { await settings.detectLocation() }
                        } label: {
                            Label("Grant location access", systemImage: "location.fill")
                        }
                        .disabled(settings.isDetectingLocation)
                        if settings.isDetectingLocation { ProgressView().controlSize(.small) }
                        Spacer()
                    }
                    statusLine
                }
            } else {
                groupCard {
                    coordinateRow("Latitude", \.latitude)
                    Divider()
                    coordinateRow("Longitude", \.longitude)
                    Divider()
                    coordinateRow("Elevation (m)", \.elevation)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let error = settings.locationError {
            Label(error, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.orange)
        } else if settings.detectedCoordinates != nil {
            Label(coordinateSummary, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
        } else {
            Text("Nothing leaves your Mac — the location is used only to compute times.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var calculationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Time source: astronomical vs a fixed mosque jamaat schedule.
            HStack(spacing: 12) {
                OptionCard(symbol: "moon.stars.fill", title: "Calculated",
                           subtitle: "Astronomically from your location", selected: settings.settings.calculationMode == .calculated) {
                    settings.settings.calculationMode = .calculated
                }
                OptionCard(symbol: "calendar", title: "Manual (fixed)",
                           subtitle: "Your mosque's jamaat times", selected: settings.settings.calculationMode == .manual) {
                    settings.settings.calculationMode = .manual
                }
            }

            if settings.settings.calculationMode == .calculated {
                calculatedConfig
            } else {
                manualConfig
            }
        }
    }

    /// Calculated time source: method (auto vs choose) + Asr madhab.
    @ViewBuilder
    private var calculatedConfig: some View {
        HStack(spacing: 12) {
            OptionCard(symbol: "globe", title: "Automatic method",
                       subtitle: "Best for your country", selected: settings.settings.autoDetectMethod) {
                autoDetectBinding.wrappedValue = true
            }
            OptionCard(symbol: "slider.horizontal.3", title: "Choose method",
                       subtitle: "Pick it yourself", selected: !settings.settings.autoDetectMethod) {
                autoDetectBinding.wrappedValue = false
            }
        }

        if settings.settings.autoDetectMethod {
            if let label = settings.autoMethodLabel {
                Label(label, systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
            }
        } else {
            groupCard {
                HStack {
                    Text("Calculation method")
                    Spacer()
                    Picker("", selection: $settings.settings.methodID) {
                        ForEach(MethodRegistry.builtIn, id: \.id) { adapter in
                            Text(adapter.displayName).tag(adapter.id)
                        }
                    }
                    .labelsHidden().fixedSize()
                }
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Asr (madhab)").font(.headline)
            HStack(spacing: 12) {
                OptionCard(symbol: "sun.max.fill", title: "Standard",
                           subtitle: "Shafiʿi · Mālikī · Ḥanbalī", selected: !settings.settings.hanafiAsr) {
                    settings.settings.hanafiAsr = false
                }
                OptionCard(symbol: "sun.haze.fill", title: "Hanafi",
                           subtitle: "Asr later in the afternoon", selected: settings.settings.hanafiAsr) {
                    settings.settings.hanafiAsr = true
                }
            }
        }
    }

    /// Manual (fixed) time source: the global Adhan-before offset + the five
    /// announced jamaat times.
    @ViewBuilder
    private var manualConfig: some View {
        groupCard {
            Stepper(value: $settings.settings.azanBeforeJamaat, in: 0...60) {
                HStack {
                    Text("Adhan before jamaat")
                    Spacer()
                    Text(azanBeforeLabel).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        Text("Enter the times your mosque announces. The Adhan reminder fires the minutes above before each.")
            .font(.caption).foregroundStyle(.secondary)
        groupCard {
            ForEach(Array(Prayer.obligatory.enumerated()), id: \.element) { idx, prayer in
                if idx > 0 { Divider() }
                JamaatRowView(prayer: prayer, minutes: jamaatBinding(prayer),
                              azanBefore: settings.settings.azanBeforeJamaat)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            groupCard {
                Toggle(isOn: $settings.settings.masterNotificationsEnabled) {
                    Text("Enable prayer notifications").fontWeight(.medium)
                }
            }
            if settings.settings.masterNotificationsEnabled {
                groupCard {
                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await notifications.requestAuthorization()
                                await notifications.refreshAuthorizationStatus()
                            }
                        } label: {
                            Label("Allow notifications", systemImage: "bell.badge")
                        }
                        .disabled(notifications.authorizationStatus == .authorized)
                        Spacer()
                        permissionBadge
                    }
                    Divider()
                    HStack {
                        Text("Default sound")
                        Spacer()
                        Picker("", selection: $settings.settings.notificationDefaults.sound) {
                            ForEach(NotificationSound.allCases, id: \.self) { sound in
                                Text(PrayerFormatting.soundName(sound)).tag(sound)
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                    Divider()
                    Toggle("Play the full Adhan at prayer time", isOn: $settings.settings.notificationDefaults.playFullAdhan)
                }
                Text("You can fine-tune each prayer — sounds, early reminders, iqamah — in Settings later.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var permissionBadge: some View {
        switch notifications.authorizationStatus {
        case .authorized:
            Label("Allowed", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green)
        case .denied:
            Label("Blocked in System Settings", systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private var displayStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live-ish preview of the menu-bar item.
            HStack {
                Spacer()
                Text(menuBarPreview)
                    .font(.system(size: 13)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.quaternary))
                Spacer()
            }
            .padding(.vertical, 8)

            groupCard {
                HStack {
                    Text("Menu bar label")
                    Spacer()
                    Picker("", selection: $settings.settings.menuBarStyle) {
                        ForEach(MenuBarStyle.allCases, id: \.self) { style in
                            Text(PrayerFormatting.menuBarStyleName(style)).tag(style)
                        }
                    }
                    .labelsHidden().fixedSize()
                }
                Divider()
                Toggle("Show the Hijri date in the panel", isOn: $settings.settings.showHijriDate)
                Divider()
                Toggle("Show the Ishraq time in the panel", isOn: $settings.settings.showIshraqTime)
            }
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            groupCard {
                Toggle(isOn: $settings.settings.focusModeEnabled) {
                    Text("Enable Focus Mode").fontWeight(.medium)
                }
            }
            Text("At each prayer, Focus Mode gently covers your screen for a short while as a reminder to step away and pray. It's a discipline aid, not a lock — Force Quit always works, and it won't engage during a full-screen call or presentation.")
                .font(.callout).foregroundStyle(.secondary)
            if settings.settings.focusModeEnabled {
                groupCard {
                    HStack {
                        Text("Trigger on")
                        Spacer()
                        Picker("", selection: $settings.settings.focusTrigger) {
                            ForEach(FocusTrigger.allCases, id: \.self) { t in
                                Text(PrayerFormatting.focusTriggerName(t)).tag(t)
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 16)
            ZStack {
                Circle().fill(Color.brand.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundStyle(Color.brand)
            }
            Text("You're all set").font(.system(size: 30, weight: .bold))
            VStack(spacing: 0) {
                summaryRow("Times", settings.settings.calculationMode == .manual
                           ? String(localized: "Manual (jamaat)") : settings.resolvedMethodName)
                Divider()
                summaryRow("Madhab", settings.settings.hanafiAsr ? String(localized: "Hanafi") : String(localized: "Standard"))
                Divider()
                summaryRow("Location", settings.settings.locationMode == .automatic ? String(localized: "Automatic") : String(localized: "Manual"))
                Divider()
                summaryRow("Notifications", settings.settings.masterNotificationsEnabled ? String(localized: "On") : String(localized: "Off"))
                Divider()
                summaryRow("Focus Mode", settings.settings.focusModeEnabled ? String(localized: "On") : String(localized: "Off"))
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 380)
            Text("Change any of this anytime from the menu-bar item → Settings.")
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.callout)
        .padding(.vertical, 10)
    }

    // MARK: Footer / navigation

    private var footer: some View {
        HStack {
            if step != .welcome && step != .done {
                Button("Skip setup") { finish() }.buttonStyle(.link)
            }
            Spacer()
            if step != .welcome {
                Button("Back") { goBack() }.controlSize(.large)
            }
            Button(primaryTitle) { goForward() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.brand)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .welcome: return "Get Started"
        case .done: return "Finish"
        default: return "Continue"
        }
    }

    private func goForward() {
        if step == .done { finish(); return }
        if let next = Step(rawValue: step.rawValue + 1) {
            withAnimation(.snappy(duration: 0.2)) { step = next }
        }
    }

    private func goBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            withAnimation(.snappy(duration: 0.2)) { step = prev }
        }
    }

    private func finish() {
        settings.completeOnboarding()
        onFinish()
    }

    // MARK: Reusable card container

    /// A grouped inset card matching the Settings look (rows separated by Dividers).
    private func groupCard<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Bindings & helpers

    private var coordinateSummary: String {
        let c = settings.resolvedCoordinates
        return String(format: "%.3f, %.3f · %@", c.latitude, c.longitude, settings.resolvedTimeZone.identifier)
    }

    private var azanBeforeLabel: String {
        let m = settings.settings.azanBeforeJamaat
        return m == 0 ? String(localized: "At jamaat") : String(localized: "\(m) min before")
    }

    /// Binding to a prayer's jamaat time (minutes since midnight), seeded from the
    /// default when unset. `JamaatRowView` handles the minutes↔Date bridging.
    private func jamaatBinding(_ prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { JamaatSchedule.minutes(for: prayer, in: settings.settings) },
            set: { settings.settings.jamaatTimes[prayer] = $0 }
        )
    }

    /// A representative menu-bar label for the chosen style (sample data).
    private var menuBarPreview: String {
        let s = settings.settings.menuBarStyle
        var parts: [String] = []
        if s.showsIcon { parts.append("🕌") }
        if s.showsName { parts.append("Asr") }
        switch s.value {
        case .none: break
        case .countdown: parts.append("in 1:24")
        case .clock: parts.append("16:42")
        }
        return parts.isEmpty ? "🕌" : parts.joined(separator: " ")
    }

    private var locationModeBinding: Binding<LocationMode> {
        Binding(get: { settings.settings.locationMode }, set: { settings.setLocationMode($0) })
    }

    private var autoDetectBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.autoDetectMethod },
            set: { on in
                settings.settings.autoDetectMethod = on
                if on { Task { await settings.detectLocation() } }
            }
        )
    }

    private func coordinateRow(_ label: LocalizedStringKey, _ keyPath: WritableKeyPath<Coordinates, Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: coordinateBinding(keyPath), format: .number.precision(.fractionLength(0...4)))
                .multilineTextAlignment(.trailing).frame(width: 120)
        }
    }

    private func coordinateBinding(_ keyPath: WritableKeyPath<Coordinates, Double>) -> Binding<Double> {
        Binding(
            get: { (settings.settings.manualCoordinates ?? SettingsStore.defaultCoordinates)[keyPath: keyPath] },
            set: { newValue in
                var c = settings.settings.manualCoordinates ?? SettingsStore.defaultCoordinates
                c[keyPath: keyPath] = newValue
                settings.settings.manualCoordinates = c
            }
        )
    }
}

/// A selectable, card-styled choice — icon in a tinted disc, title, subtitle, and
/// an accent border/fill when selected. Used for the wizard's key binary choices.
private struct OptionCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? .white : Color.brand)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(selected ? Color.brand : Color.brand.opacity(0.12)))
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.brand.opacity(0.08) : Color(nsColor: .controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.brand : Color.black.opacity(0.10), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: selected)
    }
}
