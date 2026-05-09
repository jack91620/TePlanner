import SwiftUI
import TePlannerKit

/// Hub-level "调高/调低充电限额到 N%" suggestion card.
///
/// Visible only when `ChargeLimitSuggester` decides the current
/// limit doesn't match the user's daily / pre-trip preference.
/// Tapping 应用 fires `tesla.charging.set_limit` via APIService and
/// reflects sending / sent / failed states inline so the user sees
/// the round-trip without leaving the hub.
///
/// Extracted from HubView's god-view body — all the related state
/// (status enum, copy helpers, dispatch + retry-after delay) ships
/// in this one file. HubView just hands it the inputs and does
/// nothing else.
struct HubChargeLimitCard: View {
    let currentLimit: Int?
    let scheduledDeparture: ScheduledDeparture?
    let vehicleId: String?
    let apiService: APIServiceProtocol
    /// Called once after a successful `setChargeLimit` so HubView can
    /// refresh `viewModel` and pull the new `charge_limit_soc` back.
    let onApplied: () -> Void
    /// Surfaces error text to HubView's existing `alertActionError`
    /// alert plumbing.
    let onError: (String) -> Void

    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle, sending, sent, failed(String)
    }

    var body: some View {
        let suggestion = ChargeLimitSuggester.suggest(
            currentLimit: currentLimit,
            settings: UserDefaultsSettingsStore.shared,
            upcomingDeparture: scheduledDeparture,
            now: Date(),
        )
        if !suggestion.alreadyMatches, let current = suggestion.currentPercent {
            HStack(spacing: 14) {
                Image(systemName: "battery.100.bolt")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: suggestion))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle(for: suggestion, current: current))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                applyButton(target: suggestion.recommendedPercent)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .accessibilityIdentifier("hub_charge_limit_card")
        }
    }

    @ViewBuilder
    private func applyButton(target: Int) -> some View {
        switch status {
        case .idle:
            Button("应用") { apply(percent: target) }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("hub_charge_limit_apply")
        case .sending:
            ProgressView().controlSize(.small)
        case .sent:
            Label("已应用", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.green)
        case .failed:
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
        }
    }

    private func title(for suggestion: ChargeLimitSuggestion) -> String {
        switch suggestion.reason {
        case .daily:
            return "调低充电限额到 \(suggestion.recommendedPercent)%"
        case .upcomingDeparture:
            return "调高充电限额到 \(suggestion.recommendedPercent)%"
        }
    }

    private func subtitle(for suggestion: ChargeLimitSuggestion, current: Int) -> String {
        switch suggestion.reason {
        case .daily:
            return "当前 \(current)% · 长期日常使用更友好"
        case .upcomingDeparture(let hours):
            if hours == 0 { return "当前 \(current)% · 即将出行" }
            return "当前 \(current)% · 还有 \(hours) 小时出发"
        }
    }

    private func apply(percent: Int) {
        guard let vehicleId else { return }
        guard status != .sending else { return }
        status = .sending
        Task {
            let result = await apiService.setChargeLimit(vehicleId: vehicleId, percent: percent)
            switch result {
            case .success:
                status = .sent
                Log.vehicle.notice("charge-limit set to \(percent, privacy: .public)%")
                onApplied()
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                if case .sent = status { status = .idle }
            case .failure(let err):
                let msg = err.localizedDescription
                status = .failed(msg)
                Log.vehicle.error("charge-limit failed: \(msg, privacy: .public)")
                onError(msg)
                try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
                if case .failed = status { status = .idle }
            }
        }
    }
}
