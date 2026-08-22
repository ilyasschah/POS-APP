import Foundation
import SwiftUI

/// Read-only feed for the POS Sessions screen.
///
/// Three GETs and nothing else:
///   GET /api/PosSession/History?companyId=25&take=50    → the list
///   GET /api/PosSession/Summary?companyId=25&sessionId= → one session's figures
///   GET /api/Users/GetAllUsers?companyId=25             → ids to cashier names
///
/// The summary is fetched PER ROW, lazily, as the row scrolls into view.
/// /History carries no takings and no order count, and firing 50 summary
/// requests up front to fill four visible rows would hammer the API for
/// nothing — each summary is several queries server-side.
@Observable
class PosSessionsViewModel {
    var sessions: [PosSessionDto] = []

    /// sessionId → its computed figures. Populated lazily, cached until refresh.
    var summaries: [Int: PosSessionSummaryDto] = [:]

    /// userId → display name, so "opened by 7" can read "opened by Sarah".
    var userNames: [Int: String] = [:]

    // Starts true so the first render (before .task actually starts running)
    // shows a spinner rather than a flash of "no sessions".
    var isLoading = true
    var errorMessage: String? = nil

    var companyId: Int = 25

    private var summariesInFlight: Set<Int> = []

    // MARK: - Loading

    /// - Parameter take: how deep into the history to read. The API defaults to
    ///   50; the screen lets the user widen it.
    func load(apiBaseUrl: String, token: String, take: Int) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(apiBaseUrl)/PosSession/History?companyId=\(companyId)&take=\(take)") else {
            errorMessage = "Invalid POS Sessions URL"
            isLoading = false
            return
        }

        do {
            sessions = try await get([PosSessionDto].self, from: url, token: token)
        } catch let error as PosApiError {
            errorMessage = error.message
        } catch {
            // Switching sidebar tabs cancels the in-flight request for the tab
            // being left; that is not a real failure, so do not surface it.
            if (error as? URLError)?.code != .cancelled {
                errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            }
        }

        isLoading = false
        await loadUserNames(apiBaseUrl: apiBaseUrl, token: token)
    }

    /// Manual refresh: drop the cached figures so live sessions re-read, then
    /// reload the list.
    func refresh(apiBaseUrl: String, token: String, take: Int) async {
        summaries.removeAll()
        await load(apiBaseUrl: apiBaseUrl, token: token, take: take)
    }

    /// One session's computed figures. A no-op when already cached, unless
    /// `force` — a live session keeps moving, so the detail screen can insist.
    func loadSummary(for sessionId: Int, apiBaseUrl: String, token: String, force: Bool = false) async {
        if !force && summaries[sessionId] != nil { return }
        if summariesInFlight.contains(sessionId) { return }

        guard let url = URL(string: "\(apiBaseUrl)/PosSession/Summary?companyId=\(companyId)&sessionId=\(sessionId)") else {
            return
        }

        summariesInFlight.insert(sessionId)
        defer { summariesInFlight.remove(sessionId) }

        do {
            summaries[sessionId] = try await get(PosSessionSummaryDto.self, from: url, token: token)
        } catch {
            // A row that cannot fetch its takings still renders — it just shows
            // a dash. This must never become a screen-level failure.
        }
    }

    /// Cashier names are decoration: a failure here leaves rows reading
    /// "User #7", which is still true, so it never sets errorMessage.
    private func loadUserNames(apiBaseUrl: String, token: String) async {
        guard userNames.isEmpty else { return }
        guard let url = URL(string: "\(apiBaseUrl)/Users/GetAllUsers?companyId=\(companyId)") else { return }

        do {
            let users = try await get([UserDto].self, from: url, token: token)
            var map: [Int: String] = [:]
            for user in users { map[user.id] = user.displayName }
            userNames = map
        } catch {
        }
    }

    // MARK: - Derived

    var liveSessions: [PosSessionDto] { sessions.filter { $0.isLive } }

    var flaggedCount: Int { sessions.filter { $0.needsAttention }.count }

    /// Sum of every recorded cash difference — the shop's net drawer variance
    /// over the loaded window. Positive is over, negative is short.
    var netCashDifference: Double {
        sessions.compactMap { $0.cashDifference }.reduce(0, +)
    }

    var registerNames: [String] {
        Array(Set(sessions.map { $0.registerName })).sorted()
    }

    func userLabel(_ id: Int?) -> String {
        guard let id else { return "—" }
        return userNames[id] ?? "User #\(id)"
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ type: T.Type, from url: URL, token: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PosApiError(message: "Invalid response from server")
        }

        guard (200..<300).contains(http.statusCode) else {
            // Business failures come back as a 400 carrying the reason as the
            // body; showing it beats "Server returned error 400".
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r "))
            if let body, !body.isEmpty, body.count < 300 {
                throw PosApiError(message: body)
            }
            throw PosApiError(message: "Server returned error \(http.statusCode)")
        }

        do {
            return try PosApi.decoder().decode(T.self, from: data)
        } catch {
            throw PosApiError(message: "Could not read the response: \(error.localizedDescription)")
        }
    }
}
