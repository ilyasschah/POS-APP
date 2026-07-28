import Foundation
import SwiftUI

@Observable
class ProductsViewModel {
    var products: [ProductDto] = []
    var isLoading = false
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
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // PUT /api/Products/Update — updates pricing then reloads the list.
    @discardableResult
    func updateProduct(_ product: ProductDto,
                       salePrice: Double,
                       costPrice: Double,
                       apiBaseUrl: String,
                       token: String) async -> Bool {
        guard let url = URL(string: "\(apiBaseUrl)/Products/Update") else {
            errorMessage = "Invalid Update URL"
            return false
        }

        let payload = UpdateProductRequest(
            id: product.id,
            name: product.name ?? "",
            code: product.code ?? "",
            salePrice: salePrice,
            costPrice: costPrice,
            companyId: companyId
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
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
