import SwiftUI
import TePlannerKit

/// Curated SF Symbol picker for quick-action tiles. Driven by
/// `HubActionIconLibrary.groups` (32 icons in 6 sections). Selection
/// is two-way bound; tapping a symbol updates the parent's `icon`
/// state and the sheet closes via `onDismiss`.
struct HubIconPickerSheet: View {
    @Binding var selectedIcon: String
    let onDismiss: () -> Void

    private let cellGrid = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(HubActionIconLibrary.groups, id: \.label) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: cellGrid, spacing: 12) {
                                ForEach(group.icons, id: \.self) { icon in
                                    cell(icon: icon)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { onDismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(icon: String) -> some View {
        let isSelected = icon == selectedIcon
        Button {
            selectedIcon = icon
            onDismiss()
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: 48, height: 48)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 10)
                )
        }
        .accessibilityIdentifier("hub_icon_picker_\(icon)")
    }
}
