import SwiftUI
import TePlannerKit

/// Sheet for redeeming a share code into the user's library.
/// Three states: input → preview → done. Errors surface inline
/// with an actionable message (expired vs not found vs version-
/// too-old) instead of a generic toast.
struct ImportShareSheet: View {
    @ObservedObject var hubStore: HubActionsStore
    @ObservedObject var rulesStore: AutomationRulesStore
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var codeInput: String = ""
    @State private var phase: Phase = .input
    @State private var fetched: ShareDetailResponse? = nil
    @State private var importing: Bool = false
    @State private var errorMessage: String? = nil

    enum Phase: Equatable {
        case input
        case preview
        case imported(name: String, type: ShareType)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .input: inputView
                case .preview: previewView
                case .imported(let name, let type): importedView(name: name, type: type)
                }
            }
            .navigationTitle("导入分享码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { onDismiss() }
                }
            }
        }
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(spacing: 18) {
            Text("输入好友给你的 6 位分享码")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            TextField("ABCD-EF", text: $codeInput)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 18)
                .padding(.horizontal, 24)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .accessibilityIdentifier("import_share_code_field")
            if let msg = errorMessage {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("import_share_error")
            }
            Button {
                Task { await lookup() }
            } label: {
                if importing {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    Text("继续").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(codeInput.replacingOccurrences(of: "-", with: "").count < 6 || importing)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("import_share_continue_button")
            Spacer()
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewView: some View {
        if let share = fetched {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: share.shareType == .action ? "square.grid.2x2.fill" : "bell.fill")
                            .foregroundStyle(.tint)
                        Text(share.shareType == .action ? "快捷操作" : "自动化")
                            .font(.headline)
                        Spacer()
                    }
                    Divider()
                    switch share.shareType {
                    case .action:
                        actionPreview(payload: share.payload)
                    case .rule:
                        rulePreview(payload: share.payload)
                    }
                    Spacer(minLength: 20)
                    Button {
                        Task { await importNow(share: share) }
                    } label: {
                        if importing {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        } else {
                            Text("加到我的列表").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("import_share_confirm_button")
                    if let msg = errorMessage {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("import_share_preview_error")
                    }
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func actionPreview(payload: [String: JSONValue]) -> some View {
        if let decoded = decodeAction(payload) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: SemanticIcon.symbol(for: decoded.icon))
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 48, height: 48)
                        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading) {
                        Text(decoded.name).font(.title3.weight(.semibold))
                        Text("\(decoded.steps.count) 步").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(decoded.steps.enumerated()), id: \.offset) { idx, step in
                    HStack {
                        Text("\(idx + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(RuleDisplay.capabilityName(step.capability))
                        if let delay = step.delayMsAfter, delay > 0 {
                            Text("→ 等 \(delay / 1000) 秒")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if decoded.confirmRequired {
                    Label("执行前需要确认", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .accessibilityIdentifier("import_share_preview_action")
        } else {
            Text("分享内容无法解析").foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func rulePreview(payload: [String: JSONValue]) -> some View {
        if let decoded = decodeRule(payload) {
            VStack(alignment: .leading, spacing: 8) {
                Text(decoded.name).font(.title3.weight(.semibold))
                // Be honest about the post-import state, not the
                // sharer's state. Imported rules ALWAYS land disabled
                // (safety — receiver reviews spec before flipping on).
                // Showing "默认开启" because the sharer had it on would
                // confuse the receiver into expecting immediate fire.
                Label("导入后默认关闭，需手动开启", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("Spec 字段：\(decoded.spec.keys.sorted().joined(separator: ", "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("import_share_preview_rule")
        } else {
            Text("分享内容无法解析").foregroundStyle(.red)
        }
    }

    // MARK: - Imported

    private func importedView(name: String, type: ShareType) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("已导入「\(name)」")
                .font(.title3.weight(.semibold))
            Text(type == .action ? "已加到快捷操作动作库（未分配槽位）。" : "已加到自动化列表（默认关闭，按需开启）。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
            Spacer()
            Button("完成") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .accessibilityIdentifier("import_share_close_button")
        }
    }

    // MARK: - Networking

    private func lookup() async {
        errorMessage = nil
        importing = true
        defer { importing = false }
        let normalized = codeInput
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        let result = await APIService.shared.lookupShare(code: normalized)
        switch result {
        case .success(let detail):
            fetched = detail
            phase = .preview
        case .failure(let err):
            errorMessage = friendly(err)
        }
    }

    private func importNow(share: ShareDetailResponse) async {
        errorMessage = nil
        importing = true
        defer { importing = false }

        switch share.shareType {
        case .action:
            guard let decoded = decodeAction(share.payload) else {
                errorMessage = "分享内容损坏，无法导入"
                return
            }
            let action = decoded.toHubAction()
            await hubStore.importAction(action)
            phase = .imported(name: decoded.name, type: .action)
        case .rule:
            guard let decoded = decodeRule(share.payload) else {
                errorMessage = "分享内容损坏，无法导入"
                return
            }
            // Imported rules start disabled — user reviews the spec on
            // the automation detail page before flipping them on.
            let created = await rulesStore.create(
                name: decoded.name,
                enabled: false,
                spec: decoded.spec,
            )
            if created != nil {
                phase = .imported(name: decoded.name, type: .rule)
            } else {
                errorMessage = "保存失败，请稍后重试"
            }
        }
    }

    // MARK: - Decoding helpers

    private func decodeAction(_ payload: [String: JSONValue]) -> SharedActionPayload? {
        do {
            let data = try JSONEncoder().encode(payload)
            return try JSONDecoder().decode(SharedActionPayload.self, from: data)
        } catch {
            Log.app.error("share import: action payload decode error \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func decodeRule(_ payload: [String: JSONValue]) -> SharedRulePayload? {
        do {
            let data = try JSONEncoder().encode(payload)
            return try JSONDecoder().decode(SharedRulePayload.self, from: data)
        } catch {
            Log.app.error("share import: rule payload decode error \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func friendly(_ err: APIError) -> String {
        if case .serverError(let code, let message) = err {
            switch code {
            case 404: return "分享码不存在，请检查后重试"
            case 410: return "分享码已过期或被分享者撤销"
            case 412:
                // Server includes the required version in the body.
                return message.contains("version") ? "需要更新 App 才能导入这个分享码" : "无法导入"
            default: return "服务器返回 \(code)"
            }
        }
        return err.errorDescription ?? "网络错误"
    }
}
