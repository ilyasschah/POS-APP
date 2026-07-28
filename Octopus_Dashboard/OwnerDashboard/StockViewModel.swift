import Foundation
import SwiftUI

// One row per product for the Stock tab. Combines every product (from
// Products/GetAll) with its stock records (from Stocks/GetAllStocks) so a
// product with no stock record still shows up as "Unassigned" instead of
// being silently dropped — matching the "All Products vs Stock" rule.
struct ProductStockDto: Identifiable {
    let productId: Int
    let name: String
    let code: String?
    let totalQuantity: Double
    let byWarehouse: [(warehouseName: String, quantity: Double)]

    var id: Int { productId }
    var isUnassigned: Bool { byWarehouse.isEmpty }
}

@Observable
class StockViewModel {
    var stockItems: [ProductStockDto] = []
    var isLoading = true
    var errorMessage: String? = nil

    var companyId: Int = 25

    func load(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let productsUrl = URL(string: "\(apiBaseUrl)/Products/GetAll?companyId=\(companyId)"),
              let stocksUrl = URL(string: "\(apiBaseUrl)/Stocks/GetAllStocks?companyId=\(companyId)") else {
            errorMessage = "Invalid Stock URL"
            isLoading = false
            return
        }

        do {
            let products = try await fetch([ProductDto].self, url: productsUrl, token: token)
            let stocks = try await fetch([StockDto].self, url: stocksUrl, token: token)

            let stocksByProduct = Dictionary(grouping: stocks, by: \.productId)
            stockItems = products.map { product in
                let records = stocksByProduct[product.id] ?? []
                let byWarehouse = records.map {
                    (warehouseName: $0.warehouseName ?? "Warehouse \($0.warehouseId)", quantity: $0.quantity ?? 0)
                }
                let total = byWarehouse.reduce(0) { $0 + $1.quantity }
                return ProductStockDto(productId: product.id, name: product.name, code: product.code,
                                       totalQuantity: total, byWarehouse: byWarehouse)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            // Switching sidebar tabs cancels the in-flight request for the tab
            // being left; that's not a real failure, so don't surface it as one.
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load stock: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    private func fetch<T: Decodable>(_ type: T.Type, url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
