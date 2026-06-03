import SwiftUI
import AppKit
import UserNotifications
import PrayerKit

/// Notification settings (spec §7.3, §7.4): a master toggle plus the per-prayer
/// matrix — prayer-entry notification, early reminder, and iqamah, each with its
/// own sound. M3 owns the configuration surface; M4 wires the actual scheduling,
/// sound previews, and Stop-Adhan control.
struct NotificationsTab: View {
    @Bindable var settings: SettingsStore
    let audio: AudioService
    let notifications: NotificationService

    var body: some View {
        Form {
            if let hint = systemPermissionHint {
                Section {
                    Label {
                        Text(hint.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.callout)
                    if hint.showsSystemSettingsButton {
                        Button("Open System Settings") { Self.openNotificationSettings() }
                    }
                }
            }

            Section {
                Toggle("Enable notifications", isOn: $settings.settings.masterNotificationsEnabled)
                Button {
                    Task { await notifications.sendSampleNotification() }
                } label: {
                    Label("Send a sample notification", systemImage: "bell.badge")
                }
            }

            ForEach(Prayer.allCases, id: \.self) { prayer in
                Section(PrayerFormatting.name(prayer)) {
                    PrayerNotificationRow(prayer: prayer, config: config(for: prayer), audio: audio)
                }
                .disabled(!settings.settings.masterNotificationsEnabled)
            }
        }
        .formStyle(.grouped)
        .task { await notifications.refreshAuthorizationStatus() }
    }

    /// In-app explanation when notifications won't appear because macOS hasn't
    /// granted permission — so the user isn't left wondering why nothing fires.
    private var systemPermissionHint: (message: LocalizedStringKey, showsSystemSettingsButton: Bool)? {
        switch notifications.authorizationStatus {
        case .denied:
            return ("macOS is blocking notifications for Prayer Times. Enable them in System Settings → Notifications to receive prayer alerts.",
                    true)
        case .notDetermined:
            return ("Prayer Times hasn't been granted notification permission yet. Send a sample notification below to trigger the macOS prompt.",
                    false)
        default:
            return nil
        }
    }

    private static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func config(for prayer: Prayer) -> Binding<PrayerNotificationConfig> {
        Binding(
            get: { settings.settings.notifications[prayer] ?? PrayerNotificationConfig() },
            set: { settings.settings.notifications[prayer] = $0 }
        )
    }
}

/// One prayer's notification block.
private struct PrayerNotificationRow: View {
    let prayer: Prayer
    @Binding var config: PrayerNotificationConfig
    let audio: AudioService

    var body: some View {
        // Prayer-entry notification.
        Toggle("Prayer-time notification", isOn: $config.prayerNotificationEnabled)
        if config.prayerNotificationEnabled {
            soundPicker("Sound", selection: $config.prayerSound)
            if prayer.isObligatory {
                Toggle("Play full Adhan audio", isOn: $config.playFullAdhan)
            }
        }

        // Early reminder.
        Toggle("Early reminder", isOn: $config.earlyReminderEnabled)
        if config.earlyReminderEnabled {
            Stepper(value: $config.earlyLeadMinutes, in: 1...60) {
                HStack {
                    Text("Lead time")
                    Spacer(minLength: 12)
                    Text("\(config.earlyLeadMinutes) min").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            soundPicker("Reminder sound", selection: $config.earlySound)
        }

        // Iqamah (obligatory prayers only — not Sunrise).
        if prayer.isObligatory {
            Stepper(value: $config.iqamahOffsetMinutes, in: 0...60) {
                HStack {
                    Text("Iqamah offset")
                    Spacer(minLength: 12)
                    Text(config.iqamahOffsetMinutes == 0 ? String(localized: "Off") : "+\(config.iqamahOffsetMinutes) min")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if config.iqamahOffsetMinutes > 0 {
                Toggle("Iqamah notification", isOn: $config.iqamahNotificationEnabled)
                if config.iqamahNotificationEnabled {
                    soundPicker("Iqamah sound", selection: $config.iqamahSound)
                }
            }
        }
    }

    private func soundPicker(_ title: LocalizedStringKey, selection: Binding<NotificationSound>) -> some View {
        HStack {
            Picker(title, selection: selection) {
                ForEach(NotificationSound.allCases, id: \.self) { sound in
                    Text(PrayerFormatting.soundName(sound)).tag(sound)
                }
            }
            Button {
                if audio.isPlaying { audio.stop() } else { audio.preview(selection.wrappedValue) }
            } label: {
                Image(systemName: audio.isPlaying ? "stop.circle" : "play.circle")
            }
            .buttonStyle(.borderless)
            .help(audio.isPlaying ? "Stop" : "Preview sound")
            .disabled(selection.wrappedValue == .none)
        }
    }
}
