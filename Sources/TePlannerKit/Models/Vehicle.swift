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
    /// Phase 5.6: current charge-limit SOC percent (50..100). Drives
    /// the iOS "智能充电限额建议" card — only surface a suggestion when
    /// this differs from the user's daily / pre-trip preference.
    public let chargeLimitSoc: Int?
    // Slice A — closure / lock state. Match backend VehicleStateSnapshot.
    public let locked: Bool?
    public let shiftState: String?
    public let doorOpen: Bool?
    public let windowOpen: Bool?
    public let frunkOpen: Bool?
    public let trunkOpen: Bool?

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
        cabinOverheatProtectionOn: Bool? = nil,
        chargeLimitSoc: Int? = nil,
        locked: Bool? = nil,
        shiftState: String? = nil,
        doorOpen: Bool? = nil,
        windowOpen: Bool? = nil,
        frunkOpen: Bool? = nil,
        trunkOpen: Bool? = nil
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
        self.chargeLimitSoc = chargeLimitSoc
        self.locked = locked
        self.shiftState = shiftState
        self.doorOpen = doorOpen
        self.windowOpen = windowOpen
        self.frunkOpen = frunkOpen
        self.trunkOpen = trunkOpen
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
        case chargeLimitSoc = "charge_limit_soc"
        case locked
        case shiftState = "shift_state"
        case doorOpen = "door_open"
        case windowOpen = "window_open"
        case frunkOpen = "frunk_open"
        case trunkOpen = "trunk_open"
    }

    /// Whether the vehicle is currently in 露营模式 (camp mode).
    public var isCampModeOn: Bool { climateKeeperMode == 3 }

    /// Treats null shift_state as parked (matches backend behavior —
    /// car-asleep returns null for drive_state.shift_state).
    public var isParked: Bool {
        guard let s = shiftState else { return true }
        return s == "P"
    }

    /// Virtual entities — the rule layer reads these instead of
    /// (locked / door_open) raw so it filters out "I'm sitting in
    /// the car with the door open" automatically.
    public var parkedUnlocked: Bool { isParked && (locked == false) }
    public var parkedWithDoorOpen: Bool { isParked && (doorOpen == true) }
    public var parkedWithWindowOpen: Bool { isParked && (windowOpen == true) }
    public var parkedWithFrunkOpen: Bool { isParked && (frunkOpen == true) }
    public var parkedWithTrunkOpen: Bool { isParked && (trunkOpen == true) }
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
