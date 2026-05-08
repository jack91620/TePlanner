import SwiftUI
import TePlannerKit

/// 自动化规则的只读详情页。Phase 10.4 重写：不再 dump schema 字段
/// （preset_id / dotted entity / trigger type / capability id 等），
/// 而是用一句话 + 卡片把「触发条件 → 满足后做什么」讲清楚。模板里的
/// {duration_human} 占位符在预览时用规则自己的阈值填上。
struct RuleDetailView: View {
    let ruleId: String
    @ObservedObject var rulesStore: AutomationRulesStore
    @ObservedObject var capabilitiesStore: CapabilitiesStore

    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var workingError: String?
    @State private var pendingDuplicate: RuleRecord?
    @Environment(\.dismiss) private var dismiss

    private var record: RuleRecord? {
        rulesStore.rules.first { $0.id == ruleId }
    }

    var body: some View {
        Group {
            if let r = record {
                Form {
                    headerSection(r)
                    triggerSection(r.spec)
                    actionSections(r.spec)
                    if let err = workingError {
                        Section {
                            Text(err).foregroundStyle(.red).font(.caption)
                        }
                    }
                }
                .navigationTitle(r.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent(r) }
                .sheet(isPresented: $showingEditor) {
                    NavigationStack {
                        RuleBuilderView(
                            initial: r,
                            rulesStore: rulesStore,
                            capabilitiesStore: capabilitiesStore
                        )
                    }
                }
                .confirmationDialog("确定删除「\(r.name)」？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
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
                } message: {
                    Text("删除后无法恢复。")
                }
                .sheet(item: $pendingDuplicate) { source in
                    // "复制为新规则" — open the builder pre-filled with
                    // a clone of this rule. Saving creates a separate
                    // user-authored rule; the source stays untouched.
                    NavigationStack {
                        RuleBuilderView(
                            initial: nil,
                            template: cloneForDuplicate(source),
                            rulesStore: rulesStore,
                            capabilitiesStore: capabilitiesStore
                        )
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    /// Build a clone of `source` for "复制为新规则": null id (forces
    /// create on save), null preset_id (clone is user-authored), and
    /// a "副本" suffix on the name. Same trigger + actions otherwise.
    private func cloneForDuplicate(_ source: RuleRecord) -> RuleRecord {
        var nextName = "\(source.name) 副本"
        let existing = Set(rulesStore.rules.map(\.name))
        var i = 2
        while existing.contains(nextName) {
            nextName = "\(source.name) 副本 \(i)"
            i += 1
        }
        return RuleRecord(
            id: "",                  // empty → builder treats as new
            presetId: nil,           // user-authored copy
            name: nextName,
            enabled: source.enabled,
            spec: source.spec,
            version: 1
        )
    }

    @ToolbarContentBuilder
    private func toolbarContent(_ r: RuleRecord) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("编辑", systemImage: "pencil") { showingEditor = true }
                Button("复制为新规则", systemImage: "plus.square.on.square") {
                    pendingDuplicate = r
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

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ r: RuleRecord) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.name).font(.headline)
                    HStack(spacing: 6) {
                        if r.presetId != nil {
                            Text("预设")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        } else {
                            Text("自定义")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                                .foregroundStyle(.green)
                        }
                        Text(r.enabled ? "已启用" : "已停用")
                            .font(.caption)
                            .foregroundStyle(r.enabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func triggerSection(_ spec: RuleSpec) -> some View {
        Section("当") {
            Text(RuleDisplay.triggerSentence(spec))
                .font(.body)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func actionSections(_ spec: RuleSpec) -> some View {
        // state_duration: 优先展示 actions_above（达到阈值时执行），
        // actions_below 作为补充信息靠后展示。
        if case .array(let above) = spec["actions_above"] ?? .null, !above.isEmpty {
            Section("那么") {
                ForEach(0..<above.count, id: \.self) { i in
                    if let dict = above[i].objectValue {
                        actionCard(dict, spec: spec)
                    }
                }
            }
        }
        if case .array(let below) = spec["actions_below"] ?? .null, !below.isEmpty {
            Section {
                ForEach(0..<below.count, id: \.self) { i in
                    if let dict = below[i].objectValue {
                        actionCard(dict, spec: spec, dimmed: true)
                    }
                }
            } header: {
                Text("尚未达到阈值时")
            } footer: {
                Text("条件已成立但未到阈值。仅作为状态指示，不会推送通知。")
                    .font(.caption2)
            }
        }
        // state_transition 用 `actions`
        if case .array(let actions) = spec["actions"] ?? .null, !actions.isEmpty {
            Section("那么") {
                ForEach(0..<actions.count, id: \.self) { i in
                    if let dict = actions[i].objectValue {
                        actionCard(dict, spec: spec)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionCard(
        _ action: [String: JSONValue],
        spec: RuleSpec,
        dimmed: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: severityIcon(action))
                    .foregroundStyle(severityColor(action))
                Text(severityLabel(action))
                    .font(.caption.bold())
                    .foregroundStyle(severityColor(action))
                Spacer()
            }
            Text(action.string("title") ?? "")
                .font(.subheadline.bold())
            Text(RuleDisplay.previewTemplate(action.string("body") ?? "", spec: spec))
                .font(.callout)
                .foregroundStyle(.secondary)
            if let cap = action.string("capability") {
                let label = action.string("primary_action_label") ?? RuleDisplay.capabilityName(cap)
                if cap != "automation.dismiss" {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                        Text("操作按钮：\(label)（\(RuleDisplay.capabilityName(cap))）")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                    .padding(.top, 2)
                } else if action.string("primary_action_label") != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("操作按钮：\(label)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(dimmed ? 0.7 : 1.0)
    }

    private func severityIcon(_ action: [String: JSONValue]) -> String {
        switch action.string("severity") {
        case "critical": return "exclamationmark.triangle.fill"
        case "info":     return "info.circle.fill"
        default:          return "bell.fill"
        }
    }

    private func severityColor(_ action: [String: JSONValue]) -> Color {
        switch action.string("severity") {
        case "critical": return .orange
        case "info":     return .blue
        default:          return .secondary
        }
    }

    private func severityLabel(_ action: [String: JSONValue]) -> String {
        switch action.string("severity") {
        case "critical": return "重要提醒"
        case "info":     return "信息提醒"
        default:          return "通知"
        }
    }
}
