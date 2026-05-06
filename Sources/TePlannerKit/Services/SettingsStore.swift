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

    public func reset() {
        for key in [
            SettingsKey.teslaLinked,
            SettingsKey.targetArrivalSoc,
            SettingsKey.minChargingSoc,
            SettingsKey.preferSupercharger,
            SettingsKey.distanceUnit
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
