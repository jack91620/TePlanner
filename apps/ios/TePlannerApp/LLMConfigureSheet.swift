import SwiftUI
import TePlannerKit

/// Chat-ish sheet for natural-language automation / quick-action
/// config. User types a sentence, server calls an LLM and returns
/// a previewable spec. User confirms → we route to the existing
/// save endpoint.
///
/// Single-turn for v1 — each "发送" wipes the previous result and
/// returns a new one. Multi-turn (refine the result by typing more)
/// can layer on later if user research shows it's needed.
struct LLMConfigureSheet: View {
    enum Target {
        case auto, automation, quickAction
        var wireValue: String {
            switch self {
            case .auto: return "auto"
            case .automation: return "automation"
            case .quickAction: return "quick_action"
            }
        }
        var inputPlaceholder: String {
            switch self {
            case .auto:
                return "比如：下班 18:00 提前 20 分钟开空调"
            case .automation:
                return "描述一个自动化规则……"
            case .quickAction:
                return "描述一个一键按钮……"
            }
        }
    }

    let target: Target
    let apiService: APIServiceProtocol
    let onSavedAutomation: (LLMConfigureResponse) -> Void
    let onSavedQuickAction: (LLMConfigureResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @State private var loading: Bool = false
    @State private var response: LLMConfigureResponse? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        hint
                        if let response { resultCard(response) }
                        if let errorMessage { errorBanner(errorMessage) }
                    }
                    .padding(16)
                }
                Divider()
                inputBar
            }
            .navigationTitle("智能配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private var hint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("用一句话描述", systemImage: "sparkles")
                .font(.headline)
            Text("我会把它翻译成自动化规则或一键操作。看一下预览，确认后再保存。")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let example = exampleHint {
                Text("例：\(example)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("llm_configure_hint")
    }

    private var exampleHint: String? {
        switch target {
        case .auto: return "下班 18:30 提前 20 分钟开空调"
        case .automation: return "充电完成时提醒我"
        case .quickAction: return "一键关空调"
        }
    }

    @ViewBuilder
    private func resultCard(_ r: LLMConfigureResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconForIntent(r.intent))
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text(titleForIntent(r.intent))
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text(r.summary)
                .font(.body)
                .accessibilityIdentifier("llm_result_summary")

            if r.intent == .askClarification, let q = r.clarification {
                Text(q)
                    .font(.callout)
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8))
            }

            if let errs = r.validationErrors, !errs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("无法保存", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    ForEach(errs, id: \.self) { e in
                        Text("• \(e)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("换一种说法再试。")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color.red.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
            } else if r.isReadyToSave {
                Button {
                    confirmSave(r)
                } label: {
                    Label("确认创建", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("llm_confirm_save")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
            Text(msg)
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.orange)
        .background(Color.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(target.inputPlaceholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("llm_input_field")
            Button {
                Task { await send() }
            } label: {
                if loading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.regular)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
            }
            .disabled(loading || input.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("llm_send")
        }
        .padding(12)
    }

    // MARK: - Actions

    private func send() async {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        loading = true
        defer { loading = false }
        response = nil
        errorMessage = nil
        let req = LLMConfigureRequest(message: trimmed, target: target.wireValue)
        switch await apiService.configureViaLLM(req) {
        case .success(let r):
            response = r
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    private func confirmSave(_ r: LLMConfigureResponse) {
        switch r.intent {
        case .createAutomation:
            onSavedAutomation(r)
        case .createQuickAction:
            onSavedQuickAction(r)
        case .askClarification:
            break  // not save-able
        }
        dismiss()
    }

    // MARK: - Helpers

    private func iconForIntent(_ i: LLMConfigureResponse.Intent) -> String {
        switch i {
        case .createAutomation: return "bell.badge.fill"
        case .createQuickAction: return "bolt.fill"
        case .askClarification: return "questionmark.bubble.fill"
        }
    }

    private func titleForIntent(_ i: LLMConfigureResponse.Intent) -> String {
        switch i {
        case .createAutomation: return "建议的自动化规则"
        case .createQuickAction: return "建议的快捷操作"
        case .askClarification: return "需要补充信息"
        }
    }
}
