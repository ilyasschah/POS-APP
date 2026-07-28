import Foundation
import SwiftUI

@Observable
class UsersViewModel {
    var users: [UserDto] = []
    // Starts true so the first render (before .task's closure actually starts
    // running) shows a spinner instead of a flash of "no users".
    var isLoading = true
    var errorMessage: String? = nil

    var companyId: Int = 25

    // GET /api/Users/GetAllUsers?companyId=25
    // Note: the controller action is named GetAllUsers, not GetAll.
    func load(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/Users/GetAllUsers?companyId=\(companyId)") else {
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
            // Switching sidebar tabs cancels the in-flight request for the tab
            // being left; that's not a real failure, so don't surface it as one.
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load users: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    // PATCH /api/Users/AdminResetPassword?companyId=25 — companyId is a query
    // param, and the backend requires a real new password (there is no
    // server-generated "blind reset"). Requires a Bearer token with the
    // "Admin" role claim (ManagerOnly policy).
    func resetPassword(for user: UserDto, newPassword: String, apiBaseUrl: String, token: String) async -> Bool {
        guard let url = URL(string: "\(apiBaseUrl)/Users/AdminResetPassword?companyId=\(companyId)") else {
            errorMessage = "Invalid reset URL"
            return false
        }

        let payload = AdminResetPasswordRequest(userId: user.id, newPassword: newPassword)

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
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
