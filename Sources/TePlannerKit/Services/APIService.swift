import Foundation

// The real implementation of our API service that makes network calls.
public class APIService: APIServiceProtocol {
    
    // Use a shared singleton instance for the app to use.
    public static let shared = APIService()
    
    private let baseURL = "http://127.0.0.1:8000/api/v1"
    
    // Make the initializer private to enforce the singleton pattern.
    private init() {}

    public func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/routes/plan") else {
            return .failure(.invalidURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = RoutePlanRequest(
            origin: origin,
            destination: destination,
            vehicleId: nil, // Not handled yet
            currentSoc: currentSoc
        )

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(requestBody)
        } catch {
            return .failure(.decodingError(error))
        }

        return await performRequest(urlRequest: urlRequest)
    }
    
    public func geocode(address: String) async -> Result<GeocodeResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/routes/geocode") else {
            return .failure(.invalidURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeocodeRequest(address: address)
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(requestBody)
        } catch {
            return .failure(.decodingError(error))
        }
        
        return await performRequest(urlRequest: urlRequest)
    }

    // Generic helper function to perform network requests and decode JSON
    private func performRequest<T: Decodable>(urlRequest: URLRequest) async -> Result<T, APIError> {
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                return .failure(.serverError(statusCode: httpResponse.statusCode, message: errorMessage))
            }

            do {
                let decoder = JSONDecoder()
                let decodedObject = try decoder.decode(T.self, from: data)
                return .success(decodedObject)
            } catch {
                return .failure(.decodingError(error))
            }
        } catch {
            return .failure(.requestFailed(error))
        }
    }
}
