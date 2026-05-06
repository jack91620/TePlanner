import Foundation

public struct VehiclesResponse: Codable {
    public let count: Int
    public let vehicles: [Vehicle]
}

public struct Vehicle: Codable, Identifiable, Equatable {
    public let id: String
    public let vehicleId: Int64?
    public let vin: String?
    public let displayName: String?
    public let model: String?
    public let state: String
    public let inService: Bool
    public let isPrimary: Bool
    public let color: String?
    public let accessType: String?

    public init(
        id: String,
        vehicleId: Int64? = nil,
        vin: String? = nil,
        displayName: String? = nil,
        model: String? = nil,
        state: String = "offline",
        inService: Bool = false,
        isPrimary: Bool = false,
        color: String? = nil,
        accessType: String? = nil
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.vin = vin
        self.displayName = displayName
        self.model = model
        self.state = state
        self.inService = inService
        self.isPrimary = isPrimary
        self.color = color
        self.accessType = accessType
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case vin
        case displayName = "display_name"
        case model
        case state
        case inService = "in_service"
        case isPrimary = "is_primary"
        case color
        case accessType = "access_type"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        vehicleId = try c.decodeIfPresent(Int64.self, forKey: .vehicleId)
        vin = try c.decodeIfPresent(String.self, forKey: .vin)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? "offline"
        inService = try c.decodeIfPresent(Bool.self, forKey: .inService) ?? false
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
        color = try c.decodeIfPresent(String.self, forKey: .color)
        accessType = try c.decodeIfPresent(String.self, forKey: .accessType)
    }
}

public struct VehicleState: Codable, Equatable {
    public let vehicleId: String?
    public let displayName: String?
    public let state: String?
    public let batteryLevel: Int?
    public let batteryRange: Double?
    public let usableBatteryLevel: Int?
    public let chargingState: String?
    public let latitude: Double?
    public let longitude: Double?
    public let heading: Int?
    public let speed: Int?
    public let odometer: Double?
    public let insideTemp: Double?
    public let outsideTemp: Double?
    /// 0 = off / 1 = keep / 2 = dog / 3 = camp.
    public let climateKeeperMode: Int?
    public let isClimateOn: Bool?
    public let sentryModeOn: Bool?
    public let cabinOverheatProtectionOn: Bool?

    public init(
        vehicleId: String? = nil,
        displayName: String? = nil,
        state: String? = nil,
        batteryLevel: Int? = nil,
        batteryRange: Double? = nil,
        usableBatteryLevel: Int? = nil,
        chargingState: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        heading: Int? = nil,
        speed: Int? = nil,
        odometer: Double? = nil,
        insideTemp: Double? = nil,
        outsideTemp: Double? = nil,
        climateKeeperMode: Int? = nil,
        isClimateOn: Bool? = nil,
        sentryModeOn: Bool? = nil,
        cabinOverheatProtectionOn: Bool? = nil
    ) {
        self.vehicleId = vehicleId
        self.displayName = displayName
        self.state = state
        self.batteryLevel = batteryLevel
        self.batteryRange = batteryRange
        self.usableBatteryLevel = usableBatteryLevel
        self.chargingState = chargingState
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.speed = speed
        self.odometer = odometer
        self.insideTemp = insideTemp
        self.outsideTemp = outsideTemp
        self.climateKeeperMode = climateKeeperMode
        self.isClimateOn = isClimateOn
        self.sentryModeOn = sentryModeOn
        self.cabinOverheatProtectionOn = cabinOverheatProtectionOn
    }

    public enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case displayName = "display_name"
        case state
        case batteryLevel = "battery_level"
        case batteryRange = "battery_range_km"
        case usableBatteryLevel = "usable_battery_level"
        case chargingState = "charging_state"
        case latitude, longitude, heading, speed
        case odometer = "odometer_km"
        case insideTemp = "inside_temp"
        case outsideTemp = "outside_temp"
        case climateKeeperMode = "climate_keeper_mode"
        case isClimateOn = "is_climate_on"
        case sentryModeOn = "sentry_mode_on"
        case cabinOverheatProtectionOn = "cabin_overheat_protection_on"
    }

    /// Whether the vehicle is currently in 露营模式 (camp mode).
    public var isCampModeOn: Bool { climateKeeperMode == 3 }
}

public struct WakeResponse: Codable {
    public let vehicleId: String?
    public let state: String?
    public let message: String?

    public var success: Bool {
        guard let s = state else { return false }
        return s != "offline" && s != "unknown"
    }

    public enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case state, message
    }
}

public struct NavigationLocation: Codable {
    public let latitude: Double
    public let longitude: Double
    public let name: String?

    public init(latitude: Double, longitude: Double, name: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }
}

public struct NavigationRequest: Codable {
    public let latitude: Double
    public let longitude: Double
    public let name: String?
    public let waypoints: [NavigationLocation]?

    public init(latitude: Double, longitude: Double, name: String? = nil, waypoints: [NavigationLocation]? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.waypoints = waypoints
    }
}

public struct BaseResponse: Codable {
    public let success: Bool
    public let message: String?
}
