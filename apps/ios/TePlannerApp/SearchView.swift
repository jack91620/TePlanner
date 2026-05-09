import SwiftUI
import TePlannerKit

/// Phase 2 destination search. Mirrors Android `SearchScreen` —
/// keyword text field at top, debounced AMap POI list below. Selecting
/// a result hands the chosen `POIResult` back via `onSelect` and
/// dismisses; the caller (HomeView) decides what to do next (route
/// preview, etc.).
struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var queryFocused: Bool
    private let onSelect: (POIResult) -> Void

    init(service: POISearchService, onSelect: @escaping (POIResult) -> Void) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(service: service))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                Divider()
                content
            }
            .navigationTitle("搜索目的地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { queryFocused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("城市、地址、地标", text: Binding(
                get: { viewModel.query },
                set: { viewModel.updateQuery($0) }
            ))
            .focused($queryFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .onSubmit { viewModel.searchNow() }
            .accessibilityIdentifier("search_field")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            placeholder("输入关键字开始搜索", systemImage: "magnifyingglass")
        case .searching:
            VStack {
                Spacer()
                ProgressView("搜索中…").controlSize(.large)
                Spacer()
            }
        case .results(let items):
            List(Array(items.enumerated()), id: \.element.id) { index, result in
                Button {
                    onSelect(result)
                    dismiss()
                } label: { resultRow(result) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search_result_\(index)")
            }
            .listStyle(.plain)
            .accessibilityIdentifier("search_results_list")
        case .empty:
            placeholder("没有找到匹配结果", systemImage: "questionmark.circle")
        case .error(let message):
            placeholder(message, systemImage: "exclamationmark.triangle")
        }
    }

    private func resultRow(_ result: POIResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name).font(.body)
                if !result.address.isEmpty {
                    Text(result.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let distance = result.distance {
                Text(formatDistance(distance))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func placeholder(_ message: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(message)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}
