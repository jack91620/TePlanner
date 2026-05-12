import SwiftUI
import TePlannerKit

/// Modal shown after a share is minted. Displays the 6-char code in
/// a large monospace block, with the iOS system share sheet for
/// sending the code over any installed channel (WeChat, SMS,
/// AirDrop). The expiry date is reminded so the user doesn't share
/// stale codes.
struct ShareCodeSheet: View {
    let code: String
    let expiresAt: Date
    let onDismiss: () -> Void

    @State private var showingShareSheet: Bool = false

    private var formattedCode: String {
        // Insert a dash for readability: ABCDEF → ABCD-EF.
        guard code.count == 6 else { return code }
        let i = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<i])-\(code[i...])"
    }

    private var shareMessage: String {
        let expiry = Self.dateFormatter.string(from: expiresAt)
        return "Tautomation 分享码: \(formattedCode)\n打开 App → 导入分享码，\(expiry) 前有效。"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text(formattedCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("share_code_text")
                Text("有效期至 \(Self.dateFormatter.string(from: expiresAt))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("发送给好友", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("share_code_send_button")

                    Button {
                        UIPasteboard.general.string = formattedCode
                    } label: {
                        Label("复制分享码", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("share_code_copy_button")
                }
                .padding(.horizontal, 24)
                Spacer()
                Text("好友需要在自己的 App 里点 \"导入分享码\" 才能加到他们的列表。\n这个码不绑定车辆 —— 只是把动作 / 自动化的定义传过去。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .navigationTitle("分享成功")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { onDismiss() }
                        .accessibilityIdentifier("share_code_done_button")
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                SystemShareSheet(items: [shareMessage])
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hans_CN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// Thin UIViewControllerRepresentable wrapper around UIActivityViewController
/// — SwiftUI's ShareLink requires iOS 16+; we already target 17 but
/// having a typed wrapper here means the share copy can include
/// multiple lines and stays uniform with the future Android share
/// surface (which also passes a multi-line plain text string).
struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
