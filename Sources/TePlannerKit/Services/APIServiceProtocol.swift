import Foundation

// Define the custom error enum at a location accessible to both the protocol and its implementers.
public enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)
}

// A protocol that defines the capabilities of our API service.
// This allows for dependency injection, so we can use a real service in the app
// and a mock service in our tests.
public protocol APIServiceProtocol {
    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError>
    func geocode(address: String) async -> Result<GeocodeResponse, APIError>
}
