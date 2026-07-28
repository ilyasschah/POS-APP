import SwiftUI

struct DocumentsView: View {
    @Bindable var auth: AuthManager
    @State private var vm = DocumentsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.documents.isEmpty {
                    ProgressView().controlSize(.large)
                } else if let error = vm.errorMessage, vm.documents.isEmpty {
                    ContentUnavailableView("Couldn't load documents",
                                           systemImage: "exclamationmark.triangle",
                                           description: Text(error))
                } else {
                    List(vm.documents) { document in
                        NavigationLink {
                            DocumentDetailView(auth: auth, document: document)
                        } label: {
                            documentRow(document)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Documents")
            .background(.ultraThinMaterial)
            .refreshable { await reload() }
            .onAppear { Task { await reload() } }
        }
    }

    @ViewBuilder
    private func documentRow(_ document: DocumentDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.number ?? "No number")
                    .font(.headline)
                Text(document.customerName ?? "Unknown customer")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatDate(document.dateCreated))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(document.total ?? 0))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.teal)
        }
        .padding(.vertical, 4)
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

    private func formatDate(_ raw: String?) -> String {
        guard let raw else { return "—" }
        // Try ISO8601 first, then fall back to the raw string's date portion.
        if let date = ISO8601DateFormatter().date(from: raw) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        return String(raw.prefix(10))
    }
}

// MARK: - Document detail

struct DocumentDetailView: View {
    @Bindable var auth: AuthManager
    let document: DocumentDto

    @State private var itemsVm = DocumentItemsViewModel()

    var body: some View {
        List {
            Section("Document") {
                LabeledContent("Number", value: document.number ?? "—")
                LabeledContent("Type", value: document.documentTypeName ?? typeFallback(document.documentTypeId))
                LabeledContent("Date", value: formatDate(document.dateCreated))
                LabeledContent("Customer", value: document.customerName ?? "—")
            }

            Section("Totals") {
                LabeledContent("Total") {
                    Text(formatCurrency(document.total ?? 0))
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                }
            }

            Section("Line Items") {
                if itemsVm.isLoading && itemsVm.items.isEmpty {
                    ProgressView()
                } else if let error = itemsVm.errorMessage, itemsVm.items.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if itemsVm.items.isEmpty {
                    Text("No line items for this document.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(itemsVm.items) { item in
                        lineItemRow(item)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle(document.number ?? "Document")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                guard let token = auth.jwtToken else { return }
                await itemsVm.load(documentId: document.id, apiBaseUrl: auth.apiBaseUrl, token: token)
            }
        }
    }

    @ViewBuilder
    private func lineItemRow(_ item: DocumentItemDto) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName ?? "Unknown product")
                    .font(.subheadline)
                Text("\(formatQuantity(item.quantity)) × \(formatCurrency(item.price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatCurrency(item.total))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }

    private func typeFallback(_ id: Int?) -> String {
        id.map { "Type \($0)" } ?? "—"
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(value)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) DH"
    }

    private func formatDate(_ raw: String?) -> String {
        guard let raw else { return "—" }
        if let date = ISO8601DateFormatter().date(from: raw) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        return String(raw.prefix(10))
    }
}
