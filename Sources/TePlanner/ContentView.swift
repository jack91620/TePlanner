import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("行程信息")) {
                    TextField("出发地 (纬度,经度)", text: $viewModel.origin)
                    TextField("目的地 (纬度,经度)", text: $viewModel.destination)
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
                        viewModel.planRoute()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                                Text("正在规划...")
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
                    Section(header: Text("规划结果")) {
                        // NavigationLink to show the map view
                        NavigationLink(destination: MapView(plan: plan)) {
                            ResultRow(label: "地图路线", value: "点击查看")
                        }
                        ResultRow(label: "总距离", value: String(format: "%.1f km", plan.totalDistanceKm))
                        ResultRow(label: "总时间", value: formatDuration(minutes: plan.totalDurationMinutes))
                        ResultRow(label: "驾驶时间", value: formatDuration(minutes: plan.drivingDurationMinutes))
                        ResultRow(label: "充电时间", value: formatDuration(minutes: plan.chargingDurationMinutes))
                        ResultRow(label: "充电次数", value: "\(plan.numChargingStops) 次")
                        ResultRow(label: "到达时电量", value: "\(plan.arrivalSoc)%")
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


#Preview {
    ContentView()
}
