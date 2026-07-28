import SwiftUI

struct DocumentsView: View {
    @Bindable var auth: AuthManager
    @State private var vm = DocumentsViewModel()

    @AppStorage("currencySymbol", store: UserDefaults(suiteName: "group.com.futur3.ownerapp"))
    private var currencySymbol = "DH"

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
                            DocumentDetailView(document: document, currencySymbol: currencySymbol)
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
            .task { await reload() }
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
            Text(formatCurrency(document.totalAmount ?? 0))
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
        return "\(formatted) \(currencySymbol)"
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
    let document: DocumentDto
    let currencySymbol: String

    var body: some View {
        List {
            Section("Document") {
                LabeledContent("Number", value: document.number ?? "—")
                LabeledContent("Type", value: documentTypeName(document.documentTypeId))
                LabeledContent("Date", value: formatDate(document.dateCreated))
                LabeledContent("Customer", value: document.customerName ?? "—")
            }

            Section("Totals") {
                LabeledContent("Total") {
                    Text(formatCurrency(document.totalAmount ?? 0))
                        .fontWeight(.semibold)
                        .foregroundColor(.teal)
                }
            }

            Section("Line Items") {
                // The GetAll payload (DocumentDto) does not include line items.
                // Wire this up once a document-detail endpoint / line-item model exists.
                Text("Itemized line details are not included in the list response yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .navigationTitle(document.number ?? "Document")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func documentTypeName(_ id: Int?) -> String {
        switch id {
        case 1: return "Invoice"
        case 2: return "Receipt"
        default: return id.map { "Type \($0)" } ?? "—"
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) \(currencySymbol)"
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
