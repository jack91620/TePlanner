import Foundation

public struct TeslaAuthUrlResponse: Codable {
    public let url: String
    public let state: String
    public let userId: Int?

    public enum CodingKeys: String, CodingKey {
        case url, state
        case userId = "user_id"
    }
}

public struct TeslaStatusResponse: Codable {
    public let linked: Bool
    public let expired: Bool
    public let vehicleCount: Int

    public init(linked: Bool, expired: Bool = false, vehicleCount: Int = 0) {
        self.linked = linked
        self.expired = expired
        self.vehicleCount = vehicleCount
    }

    public enum CodingKeys: String, CodingKey {
        case linked, expired
        case vehicleCount = "vehicle_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        linked = try c.decode(Bool.self, forKey: .linked)
        expired = try c.decodeIfPresent(Bool.self, forKey: .expired) ?? false
        vehicleCount = try c.decodeIfPresent(Int.self, forKey: .vehicleCount) ?? 0
    }
}

public struct AuthValidationResponse: Codable {
    public let valid: Bool
    public let userId: String?
    public let hasTeslaLinked: Bool

    public init(valid: Bool, userId: String?, hasTeslaLinked: Bool = false) {
        self.valid = valid
        self.userId = userId
        self.hasTeslaLinked = hasTeslaLinked
    }

    public enum CodingKeys: String, CodingKey {
        case valid
        case userId = "user_id"
        case hasTeslaLinked = "has_tesla_linked"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        valid = try c.decode(Bool.self, forKey: .valid)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        hasTeslaLinked = try c.decodeIfPresent(Bool.self, forKey: .hasTeslaLinked) ?? false
    }
}

public struct AuthResponse: Codable {
    public let token: String
    public let refreshToken: String?
    public let userId: String
    public let expiresIn: Int64?

    public enum CodingKeys: String, CodingKey {
        case token
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case expiresIn = "expires_in"
    }
}

public struct RefreshTokenRequest: Codable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }

    public enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
