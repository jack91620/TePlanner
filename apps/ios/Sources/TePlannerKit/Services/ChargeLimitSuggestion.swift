import Foundation

/// Phase D.5 — wire shapes for `POST /vehicles/{vid}/suggest-charge-limit`.
/// The decision logic moved to `app/services/charge_analysis/suggester.py`
/// (Phase A.4 backend port). The iOS-side `ChargeLimitSuggester` static
/// helpers + the `ChargeLimitSuggestion` value type were removed; the
/// hub card now awaits the backend reply directly.

public struct SuggestChargeLimitRequest: Codable, Equatable, Sendable {
    public let currentLimit: Int?
    public let dailyLimitSoc: Int
    public let tripLimitSoc: Int
    public let tripWindowHours: Int

    public init(
        currentLimit: Int?,
        dailyLimitSoc: Int = 80,
        tripLimitSoc: Int = 100,
        tripWindowHours: Int = 12
    ) {
        self.currentLimit = currentLimit
        self.dailyLimitSoc = dailyLimitSoc
        self.tripLimitSoc = tripLimitSoc
        self.tripWindowHours = tripWindowHours
    }

    enum CodingKeys: String, CodingKey {
        case currentLimit = "current_limit"
        case dailyLimitSoc = "daily_limit_soc"
        case tripLimitSoc = "trip_limit_soc"
        case tripWindowHours = "trip_window_hours"
    }
}

public struct SuggestChargeLimitResponse: Codable, Equatable, Sendable {
    public let recommendedPercent: Int
    public let currentPercent: Int?
    /// "daily" or "upcoming_departure" — matches backend
    /// `SuggestionReason` enum.
    public let reason: String
    public let hoursAway: Int?
    public let alreadyMatches: Bool

    public init(
        recommendedPercent: Int,
        currentPercent: Int?,
        reason: String,
        hoursAway: Int? = nil,
        alreadyMatches: Bool
    ) {
        self.recommendedPercent = recommendedPercent
        self.currentPercent = currentPercent
        self.reason = reason
        self.hoursAway = hoursAway
        self.alreadyMatches = alreadyMatches
    }

    enum CodingKeys: String, CodingKey {
        case recommendedPercent = "recommended_percent"
        case currentPercent = "current_percent"
        case reason
        case hoursAway = "hours_away"
        case alreadyMatches = "already_matches"
    }
}
