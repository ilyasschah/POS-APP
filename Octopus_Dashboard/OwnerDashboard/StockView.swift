import SwiftUI

struct StockView: View {
    @Bindable var auth: AuthManager
    @State private var vm = StockViewModel()
    @State private var searchText = ""

    private var filteredItems: [ProductStockDto] {
        guard !searchText.isEmpty else { return vm.stockItems }
        return vm.stockItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.code ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.stockItems.isEmpty {
                    ProgressView().controlSize(.large)
                } else if let error = vm.errorMessage, vm.stockItems.isEmpty {
                    ContentUnavailableView("Couldn't load stock",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    List(filteredItems) { item in
                        stockRow(item)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Stock")
            .searchable(text: $searchText, prompt: "Search name or code")
            .background(.ultraThinMaterial)
            .refreshable { await reload() }
            .onAppear { Task { await reload() } }
        }
    }

    @ViewBuilder
    private func stockRow(_ item: ProductStockDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                if let code = item.code, !code.isEmpty {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if item.byWarehouse.count > 1 {
                    Text(item.byWarehouse
                        .map { "\($0.warehouseName): \(formatQuantity($0.quantity))" }
                        .joined(separator: " · "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if item.isUnassigned {
                Text("Unassigned")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } else {
                Text(formatQuantity(item.totalQuantity))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(item.totalQuantity > 0 ? .teal : .red)
            }
        }
        .padding(.vertical, 4)
    }

    private func reload() async {
        guard let token = auth.jwtToken else { return }
        await vm.load(apiBaseUrl: auth.apiBaseUrl, token: token)
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
