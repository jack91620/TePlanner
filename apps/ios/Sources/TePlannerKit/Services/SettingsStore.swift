import Foundation

/// Non-sensitive user preferences that need to persist between launches.
/// Mirrors Android's `SettingsDataStore`. For sensitive credentials use
/// `SecureStorage` instead.
public protocol SettingsStore: AnyObject {
    var teslaLinked: Bool { get set }
    var targetArrivalSoc: Int { get set }
    var minChargingSoc: Int { get set }
    var preferSupercharger: Bool { get set }
    var distanceUnit: DistanceUnit { get set }
    /// Phase 5: 提醒阈值（分钟）。0 = 关闭对应提醒。
    var campModeReminderMinutes: Int { get set }
    var sentryReminderMinutes: Int { get set }
    var cabinOverheatReminderMinutes: Int { get set }
    var chargeCompleteReminderEnabled: Bool { get set }
    /// Phase 5.6: charge-limit presets, in SOC percent. Daily =
    /// long-term battery health (60–80% typical); trip = bigger
    /// buffer before a planned departure (80–100%).
    var dailyChargeLimitSoc: Int { get set }
    var tripChargeLimitSoc: Int { get set }
    /// Phase 7 (VCP): 用户是否已经被提示过配对车辆控制密钥。第一次
    /// Tesla OAuth 完成后弹一次引导，之后不再 nag。
    var hasPromptedVCPPairing: Bool { get set }
    /// User-customized rule order. Local override of the server's
    /// canonical order; rules not in the array fall back to server
    /// order at the end. Persisted as a JSON-encoded array of rule IDs.
    var automationRuleOrder: [String] { get set }
    /// Whether the user has dismissed the first-launch welcome banner
    /// on the hub. Set true on first dismiss; banner never re-shows.
    var hasSeenHubWelcome: Bool { get set }
    func reset()
}

public enum DistanceUnit: String {
    case kilometers = "km"
    case miles = "mi"
}

public enum SettingsKey {
    public static let teslaLinked = "tesla_linked"
    public static let targetArrivalSoc = "target_arrival_soc"
    public static let minChargingSoc = "min_charging_soc"
    public static let preferSupercharger = "prefer_supercharger"
    public static let distanceUnit = "distance_unit"
    public static let campModeReminderMinutes = "camp_mode_reminder_minutes"
    public static let sentryReminderMinutes = "sentry_reminder_minutes"
    public static let cabinOverheatReminderMinutes = "cabin_overheat_reminder_minutes"
    public static let chargeCompleteReminderEnabled = "charge_complete_reminder_enabled"
    public static let dailyChargeLimitSoc = "daily_charge_limit_soc"
    public static let tripChargeLimitSoc = "trip_charge_limit_soc"
    public static let hasPromptedVCPPairing = "has_prompted_vcp_pairing"
    public static let automationRuleOrder = "automation_rule_order"
    public static let hasSeenHubWelcome = "has_seen_hub_welcome"
}

public final class UserDefaultsSettingsStore: SettingsStore {
    public static let shared = UserDefaultsSettingsStore()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var teslaLinked: Bool {
        get { defaults.bool(forKey: SettingsKey.teslaLinked) }
        set { defaults.set(newValue, forKey: SettingsKey.teslaLinked) }
    }

    public var targetArrivalSoc: Int {
        get {
            defaults.object(forKey: SettingsKey.targetArrivalSoc) as? Int ?? 20
        }
        set { defaults.set(newValue, forKey: SettingsKey.targetArrivalSoc) }
    }

    public var minChargingSoc: Int {
        get {
            defaults.object(forKey: SettingsKey.minChargingSoc) as? Int ?? 10
        }
        set { defaults.set(newValue, forKey: SettingsKey.minChargingSoc) }
    }

    public var preferSupercharger: Bool {
        get {
            defaults.object(forKey: SettingsKey.preferSupercharger) as? Bool ?? true
        }
        set { defaults.set(newValue, forKey: SettingsKey.preferSupercharger) }
    }

    public var distanceUnit: DistanceUnit {
        get {
            guard let raw = defaults.string(forKey: SettingsKey.distanceUnit),
                  let unit = DistanceUnit(rawValue: raw) else {
                return .kilometers
            }
            return unit
        }
        set { defaults.set(newValue.rawValue, forKey: SettingsKey.distanceUnit) }
    }

    public var campModeReminderMinutes: Int {
        get { defaults.object(forKey: SettingsKey.campModeReminderMinutes) as? Int ?? 120 }
        set { defaults.set(newValue, forKey: SettingsKey.campModeReminderMinutes) }
    }

    public var sentryReminderMinutes: Int {
        get { defaults.object(forKey: SettingsKey.sentryReminderMinutes) as? Int ?? 1440 }
        set { defaults.set(newValue, forKey: SettingsKey.sentryReminderMinutes) }
    }

    public var cabinOverheatReminderMinutes: Int {
        get { defaults.object(forKey: SettingsKey.cabinOverheatReminderMinutes) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: SettingsKey.cabinOverheatReminderMinutes) }
    }

    public var chargeCompleteReminderEnabled: Bool {
        get { defaults.object(forKey: SettingsKey.chargeCompleteReminderEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: SettingsKey.chargeCompleteReminderEnabled) }
    }

    public var dailyChargeLimitSoc: Int {
        get { defaults.object(forKey: SettingsKey.dailyChargeLimitSoc) as? Int ?? 70 }
        set { defaults.set(newValue, forKey: SettingsKey.dailyChargeLimitSoc) }
    }

    public var tripChargeLimitSoc: Int {
        get { defaults.object(forKey: SettingsKey.tripChargeLimitSoc) as? Int ?? 90 }
        set { defaults.set(newValue, forKey: SettingsKey.tripChargeLimitSoc) }
    }

    public var hasPromptedVCPPairing: Bool {
        get { defaults.bool(forKey: SettingsKey.hasPromptedVCPPairing) }
        set { defaults.set(newValue, forKey: SettingsKey.hasPromptedVCPPairing) }
    }

    public var automationRuleOrder: [String] {
        get {
            guard let data = defaults.data(forKey: SettingsKey.automationRuleOrder),
                  let arr = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return arr
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            defaults.set(data, forKey: SettingsKey.automationRuleOrder)
        }
    }

    public var hasSeenHubWelcome: Bool {
        get { defaults.bool(forKey: SettingsKey.hasSeenHubWelcome) }
        set { defaults.set(newValue, forKey: SettingsKey.hasSeenHubWelcome) }
    }

    public func reset() {
        for key in [
            SettingsKey.teslaLinked,
            SettingsKey.targetArrivalSoc,
            SettingsKey.minChargingSoc,
            SettingsKey.preferSupercharger,
            SettingsKey.distanceUnit,
            SettingsKey.campModeReminderMinutes,
            SettingsKey.sentryReminderMinutes,
            SettingsKey.cabinOverheatReminderMinutes,
            SettingsKey.chargeCompleteReminderEnabled,
            SettingsKey.dailyChargeLimitSoc,
            SettingsKey.tripChargeLimitSoc,
            SettingsKey.hasPromptedVCPPairing,
            SettingsKey.automationRuleOrder,
            SettingsKey.hasSeenHubWelcome,
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
