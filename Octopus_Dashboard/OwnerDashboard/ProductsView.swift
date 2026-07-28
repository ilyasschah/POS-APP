import SwiftUI

struct ProductsView: View {
    @Bindable var auth: AuthManager
    @State private var vm = ProductsViewModel()
    @State private var searchText = ""
    @State private var editingProduct: ProductDto? = nil

    private var filteredProducts: [ProductDto] {
        guard !searchText.isEmpty else { return vm.products }
        return vm.products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.code ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.products.isEmpty {
                    ProgressView().controlSize(.large)
                } else if let error = vm.errorMessage, vm.products.isEmpty {
                    ContentUnavailableView("Couldn't load products",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    List(filteredProducts) { product in
                        Button {
                            editingProduct = product
                        } label: {
                            productRow(product)
                        }
                        .buttonStyle(.plain)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Products & Prices")
            .searchable(text: $searchText, prompt: "Search name or code")
            .background(.ultraThinMaterial)
            .refreshable { await reload() }
            .onAppear { Task { await reload() } }
            .sheet(item: $editingProduct) { product in
                EditPriceView(product: product) { newPrice, newCost in
                    await vm.updateProduct(product,
                                           price: newPrice,
                                           cost: newCost,
                                           apiBaseUrl: auth.apiBaseUrl,
                                           token: auth.jwtToken ?? "")
                }
            }
        }
    }

    @ViewBuilder
    private func productRow(_ product: ProductDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                if let code = product.code, !code.isEmpty {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(product.price))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.teal)
                Text("Cost \(formatCurrency(product.cost))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func reload() async {
        guard let token = auth.jwtToken else { return }
        await vm.load(apiBaseUrl: auth.apiBaseUrl, token: token)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) DH"
    }
}

// MARK: - Edit Price sheet

struct EditPriceView: View {
    let product: ProductDto
    let onSave: (Double, Double) async -> Bool

    @State private var salePrice: Double
    @State private var costPrice: Double
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(product: ProductDto,
         onSave: @escaping (Double, Double) async -> Bool) {
        self.product = product
        self.onSave = onSave
        _salePrice = State(initialValue: product.price)
        _costPrice = State(initialValue: product.cost)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    LabeledContent("Name", value: product.name)
                    LabeledContent("Code", value: product.code ?? "—")
                }

                Section("Pricing (DH)") {
                    HStack {
                        Text("Sale Price")
                        Spacer()
                        TextField("Sale", value: $salePrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Cost Price")
                        Spacer()
                        TextField("Cost", value: $costPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            isSaving = true
                            let ok = await onSave(salePrice, costPrice)
                            isSaving = false
                            if ok { dismiss() }
                        }
                    } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}
