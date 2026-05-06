import SwiftUI

public struct ContentView: View {
    @ObservedObject public var viewModel: ContentViewModel

    public init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("行程信息")) {
                    let originTextField = TextField("出发地 (城市、地址或经纬度)", text: $viewModel.origin)
                    
                    #if os(iOS)
                    originTextField
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    #else
                    originTextField
                    #endif

                    let destinationTextField = TextField("目的地 (城市、地址或经纬度)", text: $viewModel.destination)
                    
                    #if os(iOS)
                    destinationTextField
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    #else
                    destinationTextField
                    #endif
                    
                    HStack {
                        Text("当前电量 (SOC)")
                        Slider(value: Binding(
                            get: { Double(viewModel.currentSOC) ?? 80.0 },
                            set: { viewModel.currentSOC = "\(Int($0))" }
                        ), in: 0...100, step: 1)
                        Text("\(viewModel.currentSOC)%")
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            await viewModel.planRoute()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text(viewModel.statusMessage ?? "正在规划...")
                            } else {
                                Image(systemName: "map.fill")
                                Text("规划路线")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }

                if let plan = viewModel.routePlan {
                    Section(header: Text("行程概览")) {
                        NavigationLink(destination: MapView(plan: plan)) {
                            ResultRow(label: "地图路线", value: "点击查看全景")
                        }
                        ResultRow(label: "总距离", value: String(format: "%.1f km", plan.totalDistanceKm))
                        ResultRow(label: "总时间", value: formatDuration(minutes: plan.totalDurationMinutes))
                        ResultRow(label: "驾驶时间", value: formatDuration(minutes: plan.drivingDurationMinutes))
                        ResultRow(label: "充电时间", value: formatDuration(minutes: plan.chargingDurationMinutes))
                    }
                    
                    Section(header: Text("详细行程清单")) {
                        ItineraryView(plan: plan)
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text("错误: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("TePlanner 路线规划")
        }
    }
    
    private func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours) 小时 \(remainingMinutes) 分钟"
        } else {
            return "\(remainingMinutes) 分钟"
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        return ContentView(viewModel: ContentViewModel(apiService: PreviewAPIService()))
    }
}

private final class PreviewAPIService: APIServiceProtocol {
    private func unimplemented<T>() -> Result<T, APIError> { .failure(.invalidURL) }
    func planRoute(origin: LocationInput?, destination: LocationInput, currentSoc: Int?) async -> Result<RoutePlanResponse, APIError> { unimplemented() }
    func geocode(address: String) async -> Result<GeocodeResponse, APIError> { unimplemented() }
    func getTeslaAuthUrl() async -> Result<TeslaAuthUrlResponse, APIError> { unimplemented() }
    func checkTeslaStatus(userId: String) async -> Result<TeslaStatusResponse, APIError> { unimplemented() }
    func unbindTesla(userId: String) async -> Result<BaseResponse, APIError> { unimplemented() }
    func validateToken() async -> Result<AuthValidationResponse, APIError> { unimplemented() }
    func refreshToken(_ refreshToken: String) async -> Result<AuthResponse, APIError> { unimplemented() }
    func getVehicles(userId: String) async -> Result<VehiclesResponse, APIError> { unimplemented() }
    func getVehicleState(vehicleId: String, userId: String) async -> Result<VehicleState, APIError> { unimplemented() }
    func wakeVehicle(vehicleId: String, userId: String) async -> Result<WakeResponse, APIError> { unimplemented() }
    func sendNavigation(vehicleId: String, request: NavigationRequest) async -> Result<BaseResponse, APIError> { unimplemented() }
    func getStationDetail(stationId: String) async -> Result<ChargingStation, APIError> { unimplemented() }
    func getNearbyStations(latitude: Double, longitude: Double, radiusKm: Int, type: String?) async -> Result<[ChargingStation], APIError> { unimplemented() }
}
#endif
