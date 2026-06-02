import Foundation

/// Strategies for resolving Fajr/Isha (and the night-portion guards) at high
/// latitudes where the sun may not reach the required twilight depression angle.
///
/// - `none`: use the raw computed angle times; may be `nil`/invalid in summer.
/// - `middleOfNight`: clamp Fajr/Isha to at least the night midpoint.
/// - `seventhOfNight`: Fajr ≥ sunrise − night/7, Isha ≤ sunset + night/7.
/// - `angleBased`: portion of night proportional to the twilight angle / 60.
public enum HighLatitudeRule: String, Codable, Sendable, CaseIterable, Hashable {
    case none
    case middleOfNight
    case seventhOfNight
    case angleBased
}
