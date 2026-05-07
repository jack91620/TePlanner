import Foundation

/// Pure value type that decides what to recommend the user set their
/// charge-limit SOC to, given their preferences and any upcoming
/// scheduled departure.
///
/// Algorithm:
/// - If a `ScheduledDeparture` exists and is within `tripWindowHours`,
///   recommend `settings.tripChargeLimitSoc`.
/// - Otherwise recommend `settings.dailyChargeLimitSoc`.
/// - Hide the suggestion entirely when the current limit already
///   matches the recommended value (no UI noise).
public struct ChargeLimitSuggestion: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case daily
        case upcomingDeparture(hoursAway: Int)
    }

    public let recommendedPercent: Int
    public let currentPercent: Int?
    public let reason: Reason

    /// `true` when the recommendation matches the current limit; the
    /// host hides the card in that case.
    public var alreadyMatches: Bool {
        guard let currentPercent else { return false }
        return currentPercent == recommendedPercent
    }
}

public enum ChargeLimitSuggester {
    /// Default trip window — bumping the recommendation 12 hours
    /// ahead of departure leaves enough time for the next overnight
    /// charge to top up to trip-grade SOC. Tunable per call for tests.
    public static let defaultTripWindowHours = 12

    public static func suggest(
        currentLimit: Int?,
        settings: SettingsStore,
        upcomingDeparture: ScheduledDeparture?,
        now: Date,
        tripWindowHours: Int = defaultTripWindowHours
    ) -> ChargeLimitSuggestion {
        let secondsInWindow = TimeInterval(tripWindowHours) * 3600
        if let upcoming = upcomingDeparture,
           upcoming.isInFuture(now: now),
           upcoming.departureAt.timeIntervalSince(now) <= secondsInWindow {
            let hoursAway = max(0, Int(upcoming.departureAt.timeIntervalSince(now) / 3600))
            return ChargeLimitSuggestion(
                recommendedPercent: settings.tripChargeLimitSoc,
                currentPercent: currentLimit,
                reason: .upcomingDeparture(hoursAway: hoursAway)
            )
        }
        return ChargeLimitSuggestion(
            recommendedPercent: settings.dailyChargeLimitSoc,
            currentPercent: currentLimit,
            reason: .daily
        )
    }
}
