import Foundation
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var origin: String = "39.9042,116.4074" // Default to Beijing for testing
    @Published var destination: String = "31.2304,121.4737" // Default to Shanghai for testing
    @Published var currentSOC: String = "80"
    
    @Published var routePlan: RoutePlanResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func planRoute() {
        isLoading = true
        errorMessage = nil
        routePlan = nil

        // Basic parsing for "lat,lon" format.
        // In a real app, we'd use a geocoder.
        let originCoords = parseCoordinates(from: origin)
        let destinationCoords = parseCoordinates(from: destination)
        
        guard let destCoords = destinationCoords else {
            errorMessage = "无效的目的地坐标。请输入 '纬度,经度' 格式。"
            isLoading = false
            return
        }

        let originInput = originCoords != nil ? LocationInput(latitude: originCoords!.lat, longitude: originCoords!.lon, address: nil) : nil
        let destinationInput = LocationInput(latitude: destCoords.lat, longitude: destCoords.lon, address: nil)
        let socInput = Int(currentSOC)
        
        Task {
            let result = await APIService.planRoute(
                origin: originInput,
                destination: destinationInput,
                currentSoc: socInput
            )
            
            isLoading = false
            switch result {
            case .success(let plan):
                self.routePlan = plan
            case .failure(let error):
                self.errorMessage = "路线规划失败: \(error.localizedDescription)"
            }
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
