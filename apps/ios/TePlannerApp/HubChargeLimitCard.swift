import SwiftUI
import TePlannerKit

/// Hub-level "调高/调低充电限额到 N%" suggestion card.
///
/// Phase D.5 — backend is the suggestion authority. The card calls
/// `POST /vehicles/{vid}/suggest-charge-limit` with the user's daily /
/// trip preferences (still in iOS settings until D.6) and the current
/// limit; the server reads the user's ScheduledDeparture (Phase A.3
/// store) to decide whether to recommend the trip target. iOS just
/// renders whatever shape the server returns and dispatches `应用` via
/// the existing `setChargeLimit` capability.
struct HubChargeLimitCard: View {
    let currentLimit: Int?
    let vehicleId: String?
    let apiService: APIServiceProtocol
    /// Optional shared store. When provided, dispatching the limit
    /// kicks off the converge poll so the CommandStatusBanner flips
    /// "正在调整…" → "已调整" → cleared. Without it the dispatch
    /// still works (HTTP-level success); banner just won't update
    /// until the next vehicleState change in HubView. Optional so
    /// previews / tests don't have to wire a full store.
    let commandStatusStore: CommandStatusStore?
    /// Called once after a successful `setChargeLimit` so HubView can
    /// refresh `viewModel` and pull the new `charge_limit_soc` back.
    let onApplied: () -> Void
    /// Surfaces error text to HubView's existing `alertActionError`
    /// alert plumbing.
    let onError: (String) -> Void

    @State private var suggestion: SuggestChargeLimitResponse?
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle, sending, sent, failed(String)
    }

    var body: some View {
        Group {
            if let suggestion, !suggestion.alreadyMatches,
               let current = suggestion.currentPercent {
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
                .padding(.vertical, Tokens.spacingMdPlus)
                .padding(.horizontal, Tokens.spacingLg)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .accessibilityIdentifier("hub_charge_limit_card")
            }
        }
        .task(id: cardKey) { await refreshSuggestion() }
    }

    /// Re-runs the .task when any input that affects the suggestion
    /// changes (current limit or vehicle binding). The user's daily/
    /// trip prefs and any saved departure live server-side, so refresh
    /// also fires whenever HubView calls .task on app foreground.
    private var cardKey: String {
        "\(currentLimit ?? -1)|\(vehicleId ?? "nil")"
    }

    private func refreshSuggestion() async {
        guard let vehicleId, !vehicleId.isEmpty else { return }
        let settings = UserDefaultsSettingsStore.shared
        let request = SuggestChargeLimitRequest(
            currentLimit: currentLimit,
            dailyLimitSoc: settings.dailyChargeLimitSoc,
            tripLimitSoc: settings.tripChargeLimitSoc,
        )
        let result = await apiService.suggestChargeLimit(
            vehicleId: vehicleId, request: request,
        )
        switch result {
        case .success(let response):
            suggestion = response
        case .failure(let err):
            Log.api.error("charge-limit suggestion failed: \(err.localizedDescription, privacy: .public)")
            // Keep the prior suggestion (if any) on error — beats
            // hiding the card on every flaky network blip.
        }
    }

    @ViewBuilder
    private func applyButton(target: Int) -> some View {
        switch status {
        case .idle:
            Button("应用") { apply(percent: target) }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, Tokens.spacingMdPlus)
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

    private func title(for suggestion: SuggestChargeLimitResponse) -> String {
        switch suggestion.reason {
        case "daily":
            return "调低充电限额到 \(suggestion.recommendedPercent)%"
        case "upcoming_departure":
            return "调高充电限额到 \(suggestion.recommendedPercent)%"
        default:
            return "建议充电限额 \(suggestion.recommendedPercent)%"
        }
    }

    private func subtitle(for suggestion: SuggestChargeLimitResponse, current: Int) -> String {
        switch suggestion.reason {
        case "daily":
            return "当前 \(current)% · 长期日常使用更友好"
        case "upcoming_departure":
            if let h = suggestion.hoursAway, h > 0 {
                return "当前 \(current)% · 还有 \(h) 小时出发"
            }
            return "当前 \(current)% · 即将出行"
        default:
            return "当前 \(current)%"
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
                // Defensive (B2): if set_charge_limit ever gains an
                // expected_state on the backend, this dispatch will
                // start writing CommandPending rows. Trigger the
                // converge poll preemptively so we don't hit the
                // banner-stuck regression. No-op when capability
                // remains observable-state-less (queue is empty).
                if let store = commandStatusStore {
                    Task { await store.pollUntilSettled() }
                }
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
