import SwiftUI
import PrayerKit

/// The compact menu bar label. Renders any combination of the contextual prayer
/// icon, the prayer name, and a trailing value (countdown or clock time) per the
/// configured `MenuBarStyle` (spec §7.1).
struct MenuBarLabel: View {
    let clock: PrayerClock
    let settings: SettingsStore

    var body: some View {
        let style = settings.settings.menuBarStyle
        let next = clock.nextEvent

        HStack(spacing: 4) {
            if style.showsIcon {
                // Sizing/centering is baked into the asset: the Mosque.imageset
                // viewBox carries ~15% vertical padding so the glyph fills ~70% of
                // its square box, centered. The menu bar scales template images to
                // its own icon height (ignoring SwiftUI `.frame`), so the padding —
                // not a view modifier — is what keeps the glyph from looming above
                // the text caps and aligns it with the neighbouring menu-bar icons.
                Image("Mosque")
                    .renderingMode(.template)
            }
            if let text = textPart(style: style, next: next) {
                Text(text)
            }
        }
    }

    // MARK: Composition

    /// The text portion: name and/or value, or nil for icon-only (or when there
    /// is no upcoming prayer, leaving just the icon). A countdown reads as
    /// "Asr in 4h 21m" (or "in 21m" with no name) — unit-bearing so "in" isn't
    /// ambiguous (a bare "1:24" could be 1h24m or 1m24s), matching the panel chip;
    /// the "in" is a localized format so RTL ordering stays correct. A clock value
    /// stays bare ("Asr 16:42").
    private func textPart(style: MenuBarStyle, next: (prayer: Prayer, time: Date)?) -> String? {
        guard let next else { return nil }

        let name = style.showsName ? PrayerFormatting.name(next.prayer) : nil

        switch style.value {
        case .none:
            return name?.nilIfEmpty
        case .countdown:
            let cd = PrayerFormatting.shortCountdown(clock.secondsUntilNext)
            if let name {
                return String(localized: "\(name) in \(cd)", comment: "Menu bar: prayer name + countdown, e.g. 'Asr in 1:24'")
            }
            return String(localized: "in \(cd)", comment: "Menu bar: countdown to next prayer, e.g. 'in 1:24'")
        case .clock:
            let clk = PrayerFormatting.clock(next.time, in: clock.timeZone)
            if let name {
                return "\(name) \(clk)"
            }
            return clk
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
