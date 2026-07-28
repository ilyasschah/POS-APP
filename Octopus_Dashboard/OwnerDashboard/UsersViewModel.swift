import Foundation
import SwiftUI

@Observable
class UsersViewModel {
    var users: [UserDto] = []
    var isLoading = false
    var errorMessage: String? = nil

    var companyId: Int = 25

    // GET /api/Users/GetAll?companyId=25
    func load(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/Users/GetAll?companyId=\(companyId)") else {
            errorMessage = "Invalid Users URL"
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
                    users = try JSONDecoder().decode([UserDto].self, from: data)
                } catch {
                    errorMessage = "Failed to parse users: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Server returned error \(http.statusCode)"
            }
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // POST /api/Users/AdminResetPassword
    func resetPassword(for user: UserDto, apiBaseUrl: String, token: String) async -> Bool {
        guard let url = URL(string: "\(apiBaseUrl)/Users/AdminResetPassword") else {
            errorMessage = "Invalid reset URL"
            return false
        }

        let payload: [String: Any?] = [
            "userId": user.id,
            "email": user.email,
            "companyId": companyId
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                errorMessage = "Reset failed"
                return false
            }
            return true
        } catch {
            errorMessage = "Reset error: \(error.localizedDescription)"
            return false
        }
    }
}
