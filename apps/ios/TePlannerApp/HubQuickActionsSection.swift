import SwiftUI
import TePlannerKit

/// 2×4 grid of quick action tiles on the Hub. Each tile is either:
///   - filled (assigned to a HubAction): icon + name + tap-to-run
///   - empty: dashed + plus icon, tap to assign / create
///
/// Long-press on a filled tile opens the editor. Drag-to-reorder is
/// supported on filled tiles (empty slots stay where they are
/// visually; the swap is between two slot indices).
///
/// Confirm-required actions show a small "?" badge in the corner so
/// the user knows the tap will surface a dialog before dispatch.
struct HubQuickActionsSection: View {
    @ObservedObject var store: HubActionsStore
    /// Vehicle id to dispatch against. nil when no Tesla vehicle is
    /// bound yet — tiles render disabled so the user can still see
    /// the layout but can't accidentally fire commands at nothing.
    let vehicleId: String?
    /// Used to converge VCP command feedback through the same
    /// CommandStatusBanner the chip-row / battery-page use, so a tap
    /// on a quick action shows "切换 X 中… → 已确认" identical to
    /// other dispatch surfaces.
    let commandStatusStore: CommandStatusStore?

    @State private var editingAction: HubAction? = nil
    @State private var creatingNew: Bool = false
    @State private var assigningSlotIndex: Int? = nil
    @State private var pendingConfirm: HubAction? = nil
    @State private var runErrorMessage: String? = nil

    /// Tracked so the editor can find which slot to fill when the
    /// user creates a new action from a "+" tap. nil = the user is
    /// editing an existing action, not creating from a slot.
    @State private var createSlotIndex: Int? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        // The outer container can't carry an accessibilityIdentifier
        // because SwiftUI propagates that to every descendant view,
        // overwriting child identifiers like "hub_quick_actions_manage"
        // on the inner button — e2e 16 caught this when Maestro saw
        // the manage button's id reported as "hub_quick_actions_section"
        // and couldn't match. Use `.accessibilityElement(children: .contain)`
        // to keep child IDs intact while still allowing the section as
        // a queryable anchor.
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("快捷操作")
                    .font(.headline)
                    .accessibilityIdentifier("hub_quick_actions_section")
                Spacer()
                Button {
                    creatingNew = true
                } label: {
                    Label("管理", systemImage: "square.grid.2x2")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("hub_quick_actions_manage")
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<HubSlots.count, id: \.self) { index in
                    slotTile(index: index)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(item: $editingAction) { action in
            HubActionEditorSheet(
                store: store,
                editing: action,
                onDone: { editingAction = nil },
            )
        }
        .sheet(isPresented: $creatingNew) {
            HubActionEditorSheet(
                store: store,
                editing: nil,
                slotToFill: createSlotIndex,
                onDone: {
                    creatingNew = false
                    createSlotIndex = nil
                },
            )
        }
        .sheet(item: Binding(
            get: { assigningSlotIndex.map { SlotIndexBox(value: $0) } },
            set: { assigningSlotIndex = $0?.value },
        )) { box in
            HubActionSlotPickerSheet(
                store: store,
                slotIndex: box.value,
                onPick: { actionId in
                    Task { await store.assignSlot(index: box.value, actionId: actionId) }
                    assigningSlotIndex = nil
                },
                onCreateNew: {
                    assigningSlotIndex = nil
                    createSlotIndex = box.value
                    creatingNew = true
                },
                onDismiss: { assigningSlotIndex = nil },
            )
        }
        .alert(
            pendingConfirm.map { "执行「\($0.name)」？" } ?? "",
            isPresented: Binding(
                get: { pendingConfirm != nil },
                set: { if !$0 { pendingConfirm = nil } },
            )
        ) {
            Button("取消", role: .cancel) { pendingConfirm = nil }
            Button("确认", role: .destructive) {
                let action = pendingConfirm
                pendingConfirm = nil
                if let action { Task { await runAction(action, skipConfirm: true) } }
            }
        } message: {
            if let action = pendingConfirm {
                Text("将执行 \(action.steps.count) 步操作。")
            }
        }
        .alert(
            "执行失败",
            isPresented: Binding(
                get: { runErrorMessage != nil },
                set: { if !$0 { runErrorMessage = nil } },
            )
        ) {
            Button("好") { runErrorMessage = nil }
        } message: {
            Text(runErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func slotTile(index: Int) -> some View {
        if let action = store.slotAction(at: index) {
            FilledTile(
                action: action,
                disabled: vehicleId == nil,
                onTap: {
                    Task { await runAction(action, skipConfirm: false) }
                },
                onLongPress: { editingAction = action },
            )
            .accessibilityIdentifier("hub_quick_action_slot_\(index)")
        } else {
            EmptyTile(onTap: { assigningSlotIndex = index })
                .accessibilityIdentifier("hub_quick_action_empty_\(index)")
        }
    }

    private func runAction(_ action: HubAction, skipConfirm: Bool) async {
        if action.confirmRequired && !skipConfirm {
            pendingConfirm = action
            return
        }
        guard let vid = vehicleId else { return }
        let result = await store.run(actionId: action.id, vehicleId: vid)
        // Kick the same converge poll the chip / battery pages use
        // so the user sees "切换 X 中… → 已确认" feedback in the
        // existing CommandStatusBanner. Best-effort: no-op if the
        // store isn't wired (tests, previews).
        if case .success = result, let cs = commandStatusStore {
            Task { await cs.pollUntilSettled() }
        }
        if case .failure(let err) = result {
            switch err {
            case .stepFailed(let idx, let msg):
                runErrorMessage = "第 \(idx + 1) 步失败：\(msg)"
            case .noVehicle:
                runErrorMessage = "未找到绑定车辆"
            case .unknownAction:
                runErrorMessage = "动作已删除"
            }
        }
    }

    /// SwiftUI's `.sheet(item:)` needs an Identifiable; wrap the
    /// slot index so we can drive the assignment sheet from a
    /// simple Int? state.
    private struct SlotIndexBox: Identifiable, Hashable {
        let value: Int
        var id: Int { value }
    }
}

// MARK: - Tiles

private struct FilledTile: View {
    let action: HubAction
    let disabled: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        // We can't use a SwiftUI Button here: Button consumes taps
        // and ignores .onLongPressGesture added later, which means
        // a long-press fires the tap action instead of opening the
        // editor (caught by Maestro 09 test — 长按 锁车 actually
        // sent a lock VCP command). A bare VStack with both
        // gestures wired explicitly disambiguates: tap completes
        // on quick release, long-press fires after ~500ms even
        // if the finger is still down.
        VStack(spacing: 6) {
            Image(systemName: action.icon)
                .font(.title3)
                .foregroundStyle(tintColor)
                .frame(width: 32, height: 32)
            Text(action.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 10)
        .background(
            tintColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(alignment: .topTrailing) {
            if action.confirmRequired {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(tintColor)
                    .padding(4)
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .opacity(disabled ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: 20,
            perform: {
                if !disabled { onLongPress() }
            },
            onPressingChanged: { pressing in
                isPressed = pressing
            }
        )
        .simultaneousGesture(
            // Short tap path. The 0.5s `minimumDuration: 0`
            // long-press here is the SwiftUI idiom for catching
            // tap-up reliably without colliding with the
            // long-press handler above (which uses 0.5s).
            TapGesture().onEnded {
                if !disabled { onTap() }
            }
        )
    }

    private var tintColor: Color {
        switch action.tint {
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .gray: return .gray
        }
    }
}

private struct EmptyTile: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, height: 32)
                Text("添加").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 10)
            .background(
                Color.secondary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(PressableTileButtonStyle())
    }
}

/// Lightweight press feedback for the tile. Keep separate from the
/// existing `PressableCardButtonStyle` because tiles want a tighter
/// scale (entry cards are big; tiles are small).
private struct PressableTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

