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
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
