import Foundation

struct DashboardDataDto: Codable {
    let totalSales: Double?
    let monthlySales: [MonthlySalesDto]?
    let hourlySales: [HourlySalesDto]?
    let topProducts: [TopProductDto]?
    let topProductGroups: [TopProductGroupDto]?
    let topCustomers: [TopCustomerDto]?
}

struct MonthlySalesDto: Codable, Identifiable {
    var id: String { "\(year ?? 0)-\(month ?? 0)" }
    let month: Int?
    let year: Int?
    let total: Double?
    
    // Convenience helper to convert month number 7 into "JUL"
    var monthLabel: String {
        guard let month = month, month >= 1 && month <= 12 else { return "\(month ?? 0)" }
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1].uppercased()
    }
}

struct HourlySalesDto: Codable, Identifiable {
    var id: Int { hour ?? Int.random(in: 0...1000) }
    let hour: Int?
    let total: Double?
    
    var hourLabel: String {
        guard let h = hour else { return "" }
        return "\(h)h"
    }
}

struct TopProductDto: Codable, Identifiable {
    var id: String { productName ?? UUID().uuidString }
    let productName: String?
    let quantity: Double?
    let total: Double?
}

struct TopProductGroupDto: Codable, Identifiable {
    var id: String { groupName ?? UUID().uuidString }
    let groupName: String?
    let total: Double?
}

struct TopCustomerDto: Codable, Identifiable {
    var id: String { customerName ?? UUID().uuidString }
    let customerName: String?
    let total: Double?
}
