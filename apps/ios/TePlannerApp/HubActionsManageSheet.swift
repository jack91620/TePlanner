import SwiftUI
import TePlannerKit

/// 管理 sheet for Hub Quick Actions. Single entry from the section
/// header "管理" button. Replaces the old inline "+ 新建" entry,
/// which couldn't tell the user which actions were already slotted
/// versus floating in the library and forced create/edit/delete to
/// happen across three separate sheets.
///
/// Sections:
///   1. 槽位 (2×4 grid). Each filled tile has a small "×" badge to
///      clear the slot without deleting the underlying action.
///      Drag a tile to another position to swap. Tap an empty slot
///      to open a picker over the library list.
///   2. 我的动作 (library). System + custom actions, each row
///      tagged "在槽 N" or "未分配". Tap → editor for that action.
///      Custom actions get swipe-to-delete; system actions are
///      uneditable in the destructive sense (UI hides delete).
///   3. 重置为默认 footer button — wipes all user state + re-seeds
///      the four system defaults. Confirm dialog before firing.
///
/// Drag-to-reorder lives here because in the manage sheet the
/// `.draggable` modifier doesn't compete with the Hub tile's
/// long-press menu (that's a different surface). See
/// HubQuickActionsSection's file-header note.
struct HubActionsManageSheet: View {
    @ObservedObject var store: HubActionsStore
    let onDismiss: () -> Void

    @State private var editingAction: HubAction? = nil
    @State private var creatingNew: Bool = false
    @State private var assigningSlotIndex: Int? = nil
    @State private var pendingResetConfirm: Bool = false
    @State private var pendingDeleteAction: HubAction? = nil

    private let slotColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10), count: 4,
    )

    var body: some View {
        NavigationStack {
            Form {
                slotsSection
                libraryHeaderSection
                librarySection
                resetSection
            }
            .navigationTitle("管理快捷操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { onDismiss() }
                        .accessibilityIdentifier("hub_manage_done_button")
                }
            }
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
                    onDone: { creatingNew = false },
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
                        creatingNew = true
                    },
                    onDismiss: { assigningSlotIndex = nil },
                )
            }
            .alert(
                "重置为默认？",
                isPresented: $pendingResetConfirm,
            ) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    Task { await store.resetToDefaults() }
                }
                .accessibilityIdentifier("hub_manage_reset_confirm")
            } message: {
                Text("所有自建动作 + 槽位排列都会被清空，恢复成默认的锁车 / 解锁 / 预热 / 后备箱。")
            }
            .alert(
                pendingDeleteAction.map { "删除「\($0.name)」？" } ?? "",
                isPresented: Binding(
                    get: { pendingDeleteAction != nil },
                    set: { if !$0 { pendingDeleteAction = nil } },
                ),
            ) {
                Button("取消", role: .cancel) { pendingDeleteAction = nil }
                Button("删除", role: .destructive) {
                    let id = pendingDeleteAction?.id
                    pendingDeleteAction = nil
                    if let id { Task { await store.delete(id: id) } }
                }
                .accessibilityIdentifier("hub_manage_delete_confirm")
            } message: {
                Text("此动作会被永久删除，已分配的槽位将清空。")
            }
        }
    }

    // MARK: - Sections

    private var slotsSection: some View {
        Section {
            LazyVGrid(columns: slotColumns, spacing: 10) {
                ForEach(0..<HubSlots.count, id: \.self) { idx in
                    slotCell(idx: idx)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("槽位")
        } footer: {
            Text("拖动 tile 调换位置。点 × 把动作从槽位移走（动作保留在下面的列表里）。点空槽位从列表挑选。")
        }
    }

    @ViewBuilder
    private func slotCell(idx: Int) -> some View {
        if let action = store.slotAction(at: idx) {
            ManageSlotFilled(
                slotIndex: idx,
                action: action,
                onClear: {
                    Task { await store.assignSlot(index: idx, actionId: nil) }
                },
            )
            // SwiftUI's accessibilityIdentifier propagates to every
            // descendant unless we contain the children. Without
            // this, the × button inside reports its parent's
            // hub_manage_slot_N id instead of its own
            // hub_manage_clear_x_N — Maestro can't tap the clear
            // badge. Same bug as the Hub section header earlier.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("hub_manage_slot_\(idx)")
            .draggable(ManageSlotDragPayload(slotIndex: idx)) {
                ManageSlotFilled(slotIndex: idx, action: action, onClear: {})
                    .frame(width: 64, height: 64)
                    .opacity(0.85)
            }
            .dropDestination(for: ManageSlotDragPayload.self) { items, _ in
                guard let src = items.first?.slotIndex, src != idx else {
                    return false
                }
                Task { await store.swapSlots(src, idx) }
                return true
            }
        } else {
            ManageSlotEmpty(onTap: { assigningSlotIndex = idx })
                .accessibilityIdentifier("hub_manage_slot_empty_\(idx)")
                .dropDestination(for: ManageSlotDragPayload.self) { items, _ in
                    guard let src = items.first?.slotIndex, src != idx else {
                        return false
                    }
                    Task { await store.swapSlots(src, idx) }
                    return true
                }
        }
    }

    private var libraryHeaderSection: some View {
        Section {
            Button {
                creatingNew = true
            } label: {
                Label("新建动作", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("hub_manage_new_action")
        } header: {
            Text("我的动作")
        }
    }

    private var librarySection: some View {
        Section {
            ForEach(store.actions) { action in
                libraryRow(action)
            }
        } footer: {
            Text("系统动作不能删除，但可以编辑名字 / 图标 / 颜色。")
        }
    }

    @ViewBuilder
    private func libraryRow(_ action: HubAction) -> some View {
        Button {
            editingAction = action
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.title3)
                    .foregroundStyle(tintColor(action.tint))
                    .frame(width: 36, height: 36)
                    .background(tintColor(action.tint).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.name).foregroundStyle(.primary)
                    Text(slotLabel(for: action))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if action.isSystem {
                    Text("系统")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hub_manage_library_row_\(action.id)")
        .swipeActions(edge: .trailing) {
            if !action.isSystem {
                Button(role: .destructive) {
                    pendingDeleteAction = action
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .accessibilityIdentifier("hub_manage_library_swipe_delete_\(action.id)")
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                pendingResetConfirm = true
            } label: {
                Label("重置为默认", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("hub_manage_reset_button")
        } footer: {
            Text("清空所有自建动作 + 槽位排列，恢复成首次打开时的状态。")
        }
    }

    // MARK: - Helpers

    private func slotLabel(for action: HubAction) -> String {
        if let idx = store.slots.slots.firstIndex(of: action.id) {
            return "在槽 \(idx + 1)"
        }
        return "未分配"
    }

    private func tintColor(_ tint: HubActionTint) -> Color {
        switch tint {
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .gray: return .gray
        }
    }

    private struct SlotIndexBox: Identifiable, Hashable {
        let value: Int
        var id: Int { value }
    }
}

// MARK: - Slot cells

private struct ManageSlotFilled: View {
    let slotIndex: Int
    let action: HubAction
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.title3)
                .foregroundStyle(tintColor)
                .frame(width: 28, height: 28)
            Text(action.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 8)
        .background(tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            // SwiftUI Form Section + LazyVGrid bug: without .borderless
            // (or .plain), tapping ANY Button in a row fires every
            // Button in that row's overlays. With default style,
            // SwiftUI treats the whole row as a single tappable
            // container and routes the tap to every child's action.
            // .borderless makes each Button standalone-hit-tested.
            // Reproduced 2026-05-13 on iOS 26.4 sim — tapping ×
            // on slot 0 fired onClear for slots 0/1/2/3 in one tick.
            .buttonStyle(.borderless)
            .padding(2)
            .accessibilityIdentifier("hub_manage_clear_x_\(slotIndex)")
        }
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

private struct ManageSlotEmpty: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                Text("空")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drag payload

struct ManageSlotDragPayload: Codable, Transferable {
    let slotIndex: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .text)
    }
}
