import Foundation

// Define the custom error enum at a location accessible to both the protocol and its implementers.
public enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的URL地址"
        case .requestFailed(let error): return "网络请求失败: \(error.localizedDescription)"
        case .invalidResponse: return "服务器返回无效数据"
        case .decodingError(let error): return "解析服务器数据失败: \(error.localizedDescription)"
        case .serverError(let statusCode, let message): return "服务器错误 (\(statusCode)): \(message)"
        }
    }
}

// A protocol that defines the capabilities of our API service.
// This allows for dependency injection, so we can use a real service in the app
// and a mock service in our tests.
public protocol APIServiceProtocol {
    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError>
    func geocode(address: String) async -> Result<GeocodeResponse, APIError>
}
