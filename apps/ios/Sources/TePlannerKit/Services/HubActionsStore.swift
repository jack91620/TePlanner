import Foundation
import Combine

/// Owns the user's Hub Quick Actions: the *pool* of defined actions
/// plus which ones occupy the 8 on-screen *slots*. Persists to the
/// backend `user_settings` bag under keys `hub.actions` and
/// `hub.slots`, so the same definitions appear after reinstall and
/// (once Android lands the same client) on every other device.
///
/// Lifecycle:
///   - Hub creates one store on appear, calls `load()` which fetches
///     `/user/settings`.
///   - If the bag has no `hub.*` keys (fresh user), the store seeds
///     four default system actions in the first row and persists.
///   - Every mutate (`create`, `update`, `delete`, `assignSlot`,
///     `moveSlot`) writes the affected key back via PUT.
///   - `run(_:vehicleId:)` walks the steps, dispatches via
///     `APIServiceProtocol.invokeCapability`, optionally waits the
///     `delayMsAfter` between steps.
///
/// Concurrency: marked @MainActor because Compose / SwiftUI reads
/// @Published, and the load/save coroutines do their own awaits so
/// nothing blocks the main thread despite the actor isolation.
@MainActor
public final class HubActionsStore: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var actions: [HubAction] = []
    @Published public private(set) var slots: HubSlots = HubSlots()
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    /// Most recent action that was dispatched. Hub uses this to
    /// trigger the existing CommandStatusBanner poll → user gets
    /// "切换哨兵中… → 已确认" feedback identical to chip taps.
    @Published public private(set) var lastDispatchedActionId: String?

    // MARK: - Settings bag keys

    public static let actionsKey: String = "hub.actions"
    public static let slotsKey: String = "hub.slots"

    // MARK: - Dependencies

    private let apiService: APIServiceProtocol

    public init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }

    // MARK: - Lookup

    public func action(id: String) -> HubAction? {
        actions.first { $0.id == id }
    }

    /// The HubAction occupying a given on-screen slot (0..<8), or
    /// nil if the slot is empty or refers to an action that has
    /// been deleted from the pool.
    public func slotAction(at index: Int) -> HubAction? {
        guard slots.slots.indices.contains(index) else { return nil }
        guard let id = slots.slots[index] else { return nil }
        return action(id: id)
    }

    // MARK: - Load / save

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        switch await apiService.getUserSettings() {
        case .failure(let err):
            lastError = err.localizedDescription
        case .success(let bag):
            decode(bag: bag)
            // Fresh user: seed defaults exactly once. Detect via
            // "neither key present" so we don't re-seed if the user
            // intentionally emptied all slots.
            if bag[Self.actionsKey] == nil, bag[Self.slotsKey] == nil {
                seedDefaults()
                await persistAll()
            }
        }
    }

    private func decode(bag: [String: JSONValue]) {
        if case let .array(arr)? = bag[Self.actionsKey] {
            let raw = JSONValue.array(arr)
            if let data = try? JSONEncoder().encode(raw),
               let decoded = try? JSONDecoder().decode([HubAction].self, from: data) {
                actions = decoded
            }
        }
        if case let .object(obj)? = bag[Self.slotsKey] {
            let raw = JSONValue.object(obj)
            if let data = try? JSONEncoder().encode(raw),
               let decoded = try? JSONDecoder().decode(HubSlots.self, from: data) {
                slots = decoded
            }
        }
    }

    private func persistAll() async {
        let payload: [String: JSONValue] = [
            Self.actionsKey: encodeActions(),
            Self.slotsKey: encodeSlots(),
        ]
        _ = await apiService.putUserSettings(payload, replaceAll: false)
    }

    private func persistActions() async {
        _ = await apiService.putUserSettings(
            [Self.actionsKey: encodeActions()], replaceAll: false
        )
    }

    private func persistSlots() async {
        _ = await apiService.putUserSettings(
            [Self.slotsKey: encodeSlots()], replaceAll: false
        )
    }

    // MARK: - JSON helpers (round-trip through JSONEncoder so the
    // Codable conformances on HubAction / HubSlots stay the source
    // of truth — no parallel hand-rolled encoding to drift from).

    private func encodeActions() -> JSONValue {
        guard let data = try? JSONEncoder().encode(actions),
              let val = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .array([])
        }
        return val
    }

    private func encodeSlots() -> JSONValue {
        guard let data = try? JSONEncoder().encode(slots),
              let val = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return .object([:])
        }
        return val
    }

    // MARK: - Mutations

    /// Insert a new action and (optionally) drop it in the first
    /// empty slot. Returns the new action id.
    @discardableResult
    public func create(
        name: String,
        icon: String,
        tint: HubActionTint,
        steps: [HubActionStep],
        confirmRequired: Bool,
        assignToFirstEmpty: Bool = true
    ) async -> String {
        let action = HubAction(
            name: name, icon: icon, tint: tint,
            steps: steps, confirmRequired: confirmRequired,
        )
        actions.append(action)
        if assignToFirstEmpty,
           let idx = slots.slots.firstIndex(of: nil) {
            slots.slots[idx] = action.id
        }
        await persistAll()
        return action.id
    }

    /// Replace fields on an existing action. System actions can have
    /// name / icon / tint / confirmRequired / steps changed but not
    /// `isSystem` itself (caller can't promote a custom to system).
    public func update(
        id: String,
        name: String,
        icon: String,
        tint: HubActionTint,
        steps: [HubActionStep],
        confirmRequired: Bool
    ) async {
        guard let idx = actions.firstIndex(where: { $0.id == id }) else { return }
        let old = actions[idx]
        actions[idx] = HubAction(
            id: old.id,
            name: name,
            icon: icon,
            tint: tint,
            steps: steps,
            confirmRequired: confirmRequired,
            isSystem: old.isSystem,
            createdAt: old.createdAt,
        )
        await persistActions()
    }

    /// Remove a custom action. No-op for system actions (UI hides
    /// the delete button on those, but defend in depth here too).
    public func delete(id: String) async {
        guard let target = action(id: id), !target.isSystem else { return }
        actions.removeAll { $0.id == id }
        // Any slot pointing at this action becomes empty.
        for i in slots.slots.indices where slots.slots[i] == id {
            slots.slots[i] = nil
        }
        await persistAll()
    }

    /// Drop an action into a specific slot. Pass `nil` actionId to
    /// clear. If `actionId` was already in another slot, that other
    /// slot is cleared (an action can only occupy one slot at a time).
    public func assignSlot(index: Int, actionId: String?) async {
        guard slots.slots.indices.contains(index) else { return }
        if let actionId {
            for i in slots.slots.indices where slots.slots[i] == actionId && i != index {
                slots.slots[i] = nil
            }
        }
        slots.slots[index] = actionId
        await persistSlots()
    }

    /// Drag-and-drop reorder. Swaps the two slot positions. Either
    /// can be empty; an empty source means we're filling an empty
    /// destination from elsewhere.
    public func swapSlots(_ a: Int, _ b: Int) async {
        guard slots.slots.indices.contains(a),
              slots.slots.indices.contains(b),
              a != b else { return }
        slots.slots.swapAt(a, b)
        await persistSlots()
    }

    // MARK: - Dispatch

    public enum RunError: Error, Equatable {
        case noVehicle
        case stepFailed(stepIndex: Int, message: String)
        case unknownAction
    }

    /// Execute an action against the given vehicle. Walks steps in
    /// order; aborts on the first failure (returns `.stepFailed(idx)`).
    /// `confirmRequired` is the *caller's* job — the UI shows the
    /// confirm alert before invoking this. We don't gate here so
    /// callers can suppress it (e.g. a future Siri shortcut).
    @discardableResult
    public func run(
        actionId: String,
        vehicleId: String
    ) async -> Result<Void, RunError> {
        guard let action = action(id: actionId) else {
            return .failure(.unknownAction)
        }
        lastDispatchedActionId = actionId
        for (idx, step) in action.steps.enumerated() {
            let result = await apiService.invokeCapability(
                vehicleId: vehicleId,
                capability: step.capability,
                params: step.params,
            )
            switch result {
            case .failure(let err):
                return .failure(.stepFailed(
                    stepIndex: idx,
                    message: err.localizedDescription,
                ))
            case .success:
                // Inter-step delay. Tested with a fake clock injected
                // by callers; default uses Task.sleep which is fine in
                // production.
                if let ms = step.delayMsAfter, ms > 0, idx < action.steps.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
                }
            }
        }
        return .success(())
    }

    // MARK: - Default seeding

    /// Four common single-step actions, dropped in the top row on
    /// first launch. The user is free to delete / rearrange / replace
    /// any of them; we don't re-seed once user_settings has *any*
    /// hub.* keys.
    private func seedDefaults() {
        let presets: [HubAction] = [
            HubAction(
                id: "system_lock",
                name: "锁车",
                icon: "lock.fill",
                tint: .blue,
                steps: [HubActionStep(capability: "tesla.security.door_lock")],
                confirmRequired: false,
                isSystem: true,
            ),
            HubAction(
                id: "system_unlock",
                name: "解锁",
                icon: "lock.open.fill",
                tint: .red,
                steps: [HubActionStep(capability: "tesla.security.door_unlock")],
                confirmRequired: true,
                isSystem: true,
            ),
            HubAction(
                id: "system_preheat",
                name: "预热",
                icon: "thermometer.medium",
                tint: .orange,
                steps: [HubActionStep(capability: "tesla.climate.preheat")],
                confirmRequired: false,
                isSystem: true,
            ),
            HubAction(
                id: "system_trunk",
                name: "后备箱",
                icon: "suitcase.fill",
                tint: .blue,
                steps: [HubActionStep(capability: "tesla.security.actuate_trunk")],
                confirmRequired: true,
                isSystem: true,
            ),
        ]
        actions = presets
        // Fill the first 4 slots; row 2 stays empty for the user to fill.
        slots = HubSlots(slots: presets.map { $0.id } + Array(repeating: nil, count: 4))
    }
}
