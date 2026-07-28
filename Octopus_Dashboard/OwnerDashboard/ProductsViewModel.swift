import Foundation
import SwiftUI

@Observable
class ProductsViewModel {
    var products: [ProductDto] = []
    // Starts true so the first render (before .task's closure actually starts
    // running) shows a spinner instead of a flash of "no products".
    var isLoading = true
    var errorMessage: String? = nil

    // Company scope matches the rest of the app.
    var companyId: Int = 25

    // GET /api/Products/GetAll?companyId=25
    func load(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/Products/GetAll?companyId=\(companyId)") else {
            errorMessage = "Invalid Products URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                isLoading = false
                return
            }

            if http.statusCode == 200 {
                do {
                    products = try JSONDecoder().decode([ProductDto].self, from: data)
                } catch {
                    errorMessage = "Failed to parse products: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Server returned error \(http.statusCode)"
            }
        } catch {
            // Switching sidebar tabs cancels the in-flight request for the tab
            // being left; that's not a real failure, so don't surface it as one.
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load products: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // PATCH /api/Products/Update?companyId=25 — updates pricing then reloads the
    // list. companyId is a query param on this endpoint (not part of the body),
    // and every other required field on the product must be echoed back unchanged
    // since Back-End's UpdateProductRequest marks them non-nullable.
    @discardableResult
    func updateProduct(_ product: ProductDto,
                       price: Double,
                       cost: Double,
                       apiBaseUrl: String,
                       token: String) async -> Bool {
        guard let url = URL(string: "\(apiBaseUrl)/Products/Update?companyId=\(companyId)") else {
            errorMessage = "Invalid Update URL"
            return false
        }

        let payload = UpdateProductRequest(
            id: product.id,
            productGroupId: product.productGroupId,
            name: product.name,
            code: product.code,
            plu: product.plu,
            measurementUnit: product.measurementUnit,
            price: price,
            isTaxInclusivePrice: product.isTaxInclusivePrice,
            currencyId: product.currencyId,
            isPriceChangeAllowed: product.isPriceChangeAllowed,
            isService: product.isService,
            isUsingDefaultQuantity: product.isUsingDefaultQuantity,
            isEnabled: product.isEnabled,
            description: product.description,
            cost: cost,
            markup: product.markup,
            color: product.color,
            ageRestriction: product.ageRestriction,
            lastPurchasePrice: product.lastPurchasePrice,
            rank: product.rank
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                errorMessage = "Update failed"
                return false
            }
            // Reload so the list reflects the saved prices.
            await load(apiBaseUrl: apiBaseUrl, token: token)
            return true
        } catch {
            errorMessage = "Update error: \(error.localizedDescription)"
            return false
        }
    }
}
