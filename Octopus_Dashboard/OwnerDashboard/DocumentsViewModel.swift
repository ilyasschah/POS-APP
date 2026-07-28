import Foundation
import SwiftUI

@Observable
class DocumentsViewModel {
    var documents: [DocumentDto] = []
    var isLoading = false
    var errorMessage: String? = nil

    var companyId: Int = 25

    // GET /api/Document/GetAll?companyId=25
    func load(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/Document/GetAll?companyId=\(companyId)") else {
            errorMessage = "Invalid Documents URL"
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
                    documents = try JSONDecoder().decode([DocumentDto].self, from: data)
                } catch {
                    errorMessage = "Failed to parse documents: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Server returned error \(http.statusCode)"
            }
        } catch {
            errorMessage = "Failed to load documents: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
