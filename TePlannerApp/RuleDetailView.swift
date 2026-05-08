import SwiftUI
import TePlannerKit

/// Read-only summary of a rule's spec, with toolbar buttons to Edit
/// (push the builder pre-filled) or Delete (only for non-preset rules).
struct RuleDetailView: View {
    let ruleId: String
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var workingError: String?
    @Environment(\.dismiss) private var dismiss

    private var record: RuleRecord? {
        rulesStore.rules.first { $0.id == ruleId }
    }

    var body: some View {
        Group {
            if let r = record {
                Form {
                    Section {
                        LabeledContent("名称", value: r.name)
                        LabeledContent("启用", value: r.enabled ? "是" : "否")
                        if let presetId = r.presetId {
                            LabeledContent("来自预设", value: presetId)
                        }
                    }
                    triggerSection(r.spec)
                    actionSection(r.spec)
                    if let err = workingError {
                        Section {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                    }
                }
                .navigationTitle(r.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("编辑", systemImage: "pencil") {
                                showingEditor = true
                            }
                            if r.presetId == nil {
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    showingDeleteConfirm = true
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    NavigationStack {
                        RuleBuilderView(
                            initial: r,
                            rulesStore: rulesStore,
                            capabilitiesStore: capabilitiesStore
                        )
                    }
                }
                .confirmationDialog("确定删除？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        Task {
                            let ok = await rulesStore.delete(id: r.id)
                            if ok {
                                dismiss()
                            } else {
                                workingError = rulesStore.lastError
                            }
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func triggerSection(_ spec: RuleSpec) -> some View {
        if let trigger = spec["trigger"]?.objectValue {
            Section("触发条件") {
                LabeledContent("类型", value: trigger.string("type") ?? "?")
                if let entity = trigger.string("entity") {
                    LabeledContent("观察项", value: entity)
                }
                if let equals = trigger["equals"] {
                    LabeledContent("值", value: describe(equals))
                }
                if let mins = trigger.int("for_minutes") {
                    LabeledContent("持续时间", value: formatDuration(mins))
                }
                if let target = trigger.string("to") {
                    LabeledContent("目标值", value: target)
                }
            }
        }
    }

    @ViewBuilder
    private func actionSection(_ spec: RuleSpec) -> some View {
        // state_duration: actions_above (and optional actions_below)
        // state_transition: actions
        if case .array(let above) = spec["actions_above"] ?? .null, !above.isEmpty {
            Section("动作（达到阈值）") {
                ForEach(0..<above.count, id: \.self) { i in
                    if let dict = above[i].objectValue {
                        actionRow(dict)
                    }
                }
            }
        }
        if case .array(let below) = spec["actions_below"] ?? .null, !below.isEmpty {
            Section("动作（未达阈值）") {
                ForEach(0..<below.count, id: \.self) { i in
                    if let dict = below[i].objectValue {
                        actionRow(dict)
                    }
                }
            }
        }
        if case .array(let actions) = spec["actions"] ?? .null, !actions.isEmpty {
            Section("动作") {
                ForEach(0..<actions.count, id: \.self) { i in
                    if let dict = actions[i].objectValue {
                        actionRow(dict)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ action: [String: JSONValue]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.string("title") ?? "")
                .font(.subheadline.bold())
            Text(action.string("body") ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let cap = action.string("capability"), cap != "automation.dismiss" {
                Text("调用：\(cap)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func describe(_ value: JSONValue) -> String {
        switch value {
        case .string(let s): return s
        case .int(let i): return "\(i)"
        case .double(let d): return "\(d)"
        case .bool(let b): return b ? "是" : "否"
        case .null: return "(空)"
        default: return "?"
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分钟"
    }
}
