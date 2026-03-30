import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)
}

class APIService {
    
    // For now, we assume the backend is running locally on the default FastAPI port.
    private static let baseURL = "http://127.0.0.1:8000/api/v1"

    static func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> {
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

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to decode an error message from the server
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                return .failure(.serverError(statusCode: httpResponse.statusCode, message: errorMessage))
            }

            do {
                let decoder = JSONDecoder()
                let routeResponse = try decoder.decode(RoutePlanResponse.self, from: data)
                return .success(routeResponse)
            } catch {
                return .failure(.decodingError(error))
            }
        } catch {
            return .failure(.requestFailed(error))
        }
    }
}
