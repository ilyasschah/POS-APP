import Foundation
import SwiftUI
import WidgetKit
@Observable
class DashboardManager {
    var data: DashboardDataDto? = nil
    var isLoading = false
    var errorMessage: String? = nil
    
    // Default filters
    var companyId: Int = 25
    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    
    func fetchDashboardData(apiBaseUrl: String, token: String) async {
        isLoading = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        // Pin locale/calendar so the API always receives Gregorian, ASCII-digit
        // dates (e.g. "2026-07-26") regardless of the device's regional settings.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"

        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)
        
        guard let url = URL(string: "\(apiBaseUrl)/Dashboard/GetDashboardData?companyId=\(companyId)&startDate=\(startStr)&endDate=\(endStr)") else {
            errorMessage = "Invalid Dashboard URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // THIS IS WHAT SOLVES THE 401 UNAUTHORIZED ERROR
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode == 200 {
                            let decoder = JSONDecoder()
                            
                do {
                    let decoded = try decoder.decode(DashboardDataDto.self, from: responseData)
                    self.data = decoded
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.futur3.ownerapp"){
                        sharedDefaults.set(decoded.totalSales ?? 0.0, forKey: "lastTotalSales")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                            } catch {
                                print("Decoding error: \(error)")
                                errorMessage = "JSON parsing error: \(error.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Server returned error \(httpResponse.statusCode)"
                        }
        } catch {
            errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// Key helper for custom decoding strategy
struct CustomKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int?
    init?(intValue: Int) { return nil }
}
