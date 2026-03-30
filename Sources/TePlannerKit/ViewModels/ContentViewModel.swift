import Foundation
import Combine

@MainActor
public class ContentViewModel: ObservableObject {
    @Published public var origin: String = "北京"
    @Published public var destination: String = "上海"
    @Published public var currentSOC: String = "80"
    
    @Published public var routePlan: RoutePlanResponse?
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?
    
    private let apiService: APIServiceProtocol

    public init(apiService: APIServiceProtocol = APIService.shared) {
        self.apiService = apiService
    }

    // Making this function async allows tests to await its completion properly.
    public func planRoute() async {
        isLoading = true
        errorMessage = nil
        routePlan = nil
        statusMessage = "准备规划路线..."

        do {
            statusMessage = "正在解析目的地地址..."
            let destinationLocation = try await geocodeAddressIfNeeded(input: destination)
            
            var originLocation: LocationInput?
            if !origin.trimmingCharacters(in: .whitespaces).isEmpty {
                statusMessage = "正在解析出发地地址..."
                originLocation = try await geocodeAddressIfNeeded(input: origin)
            }
            
            statusMessage = "正在规划路线..."
            let socInput = Int(currentSOC)
            let result = await apiService.planRoute(
                origin: originLocation,
                destination: destinationLocation,
                currentSoc: socInput
            )
            
            isLoading = false
            statusMessage = nil
            switch result {
            case .success(let plan):
                self.routePlan = plan
            case .failure(let error):
                self.errorMessage = "路线规划失败: \(error.localizedDescription)"
            }
        } catch {
            isLoading = false
            statusMessage = nil
            self.errorMessage = error.localizedDescription
        }
    }

    private func geocodeAddressIfNeeded(input: String) async throws -> LocationInput {
        if let coords = parseCoordinates(from: input) {
            return LocationInput(latitude: coords.lat, longitude: coords.lon, address: input)
        }
        
        let result = await apiService.geocode(address: input)
        switch result {
        case .success(let response):
            return LocationInput(latitude: response.latitude, longitude: response.longitude, address: response.formattedAddress ?? response.address)
        case .failure(let error):
            throw error
        }
    }

    private func parseCoordinates(from string: String) -> (lat: Double, lon: Double)? {
        let components = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        return (lat, lon)
    }
}
