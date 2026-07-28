import Foundation
import SwiftUI

@Observable
class DocumentsViewModel {
    var documents: [DocumentDto] = []
    // Starts true so the first render (before .task's closure actually starts
    // running) shows a spinner instead of a flash of "no documents".
    var isLoading = true
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
            // Switching sidebar tabs cancels the in-flight request for the tab
            // being left; that's not a real failure, so don't surface it as one.
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load documents: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }
}

// Line items for a single document's detail screen.
// GET /api/DocumentItems/GetByDocumentId?documentId={id}&companyId=25
@Observable
class DocumentItemsViewModel {
    var items: [DocumentItemDto] = []
    var isLoading = true
    var errorMessage: String? = nil

    var companyId: Int = 25

    func load(documentId: Int, apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/DocumentItems/GetByDocumentId?documentId=\(documentId)&companyId=\(companyId)") else {
            errorMessage = "Invalid Document Items URL"
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
                    items = try JSONDecoder().decode([DocumentItemDto].self, from: data)
                } catch {
                    errorMessage = "Failed to parse line items: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Server returned error \(http.statusCode)"
            }
        } catch {
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load line items: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }
}
