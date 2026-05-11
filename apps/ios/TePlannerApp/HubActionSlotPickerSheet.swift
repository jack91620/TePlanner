import SwiftUI
import TePlannerKit

/// Bottom sheet shown when the user taps an empty quick-action slot.
/// Two paths:
///   - pick an existing action from the pool → fill the slot
///   - "+ 新建动作" → close this sheet and open the editor (handled
///     by the parent via `onCreateNew`)
struct HubActionSlotPickerSheet: View {
    @ObservedObject var store: HubActionsStore
    let slotIndex: Int
    let onPick: (String?) -> Void
    let onCreateNew: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onCreateNew()
                    } label: {
                        Label("新建动作", systemImage: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .accessibilityIdentifier("hub_action_picker_create")
                }
                Section("从已有动作中选") {
                    if store.actions.isEmpty {
                        Text("还没有任何动作")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(store.actions) { action in
                            Button {
                                onPick(action.id)
                            } label: {
                                actionRow(action)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hub_action_picker_\(action.id)")
                        }
                    }
                }
            }
            .navigationTitle("选择动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { onDismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ action: HubAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon)
                .foregroundStyle(tintColor(action.tint))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.name).foregroundStyle(.primary)
                Text(stepSummary(action))
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if action.isSystem {
                Text("系统")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepSummary(_ action: HubAction) -> String {
        if action.steps.count == 1 {
            return RuleDisplay.capabilityName(action.steps[0].capability)
        }
        return "\(action.steps.count) 步"
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
}
