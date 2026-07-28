import Foundation

// MARK: - Product Model
// Mirrors Back-End/Web-POS.Api/Models/ProductDto.cs — ASP.NET Core's default
// System.Text.Json camelCases property names, so "Price"/"Cost" become
// "price"/"cost" on the wire (there is no "salePrice"/"costPrice").
struct ProductDto: Codable, Identifiable {
    let id: Int
    var productGroupId: Int?
    var name: String
    var code: String?
    var plu: Int?
    var measurementUnit: String?
    var price: Double
    var isTaxInclusivePrice: Bool
    var currencyId: Int?
    var isPriceChangeAllowed: Bool
    var isService: Bool
    var isUsingDefaultQuantity: Bool
    var isEnabled: Bool
    var description: String?
    var cost: Double
    var markup: Double?
    var color: String
    var ageRestriction: Int?
    var lastPurchasePrice: Double?
    var rank: Int?
}

// PATCH /api/Products/Update body — matches Back-End's UpdateProductRequest.
// Several fields are `required` (non-nullable) server-side, so an edit that only
// changes price/cost must still round-trip every other field from the fetched
// ProductDto or the request fails FluentValidation/model binding.
struct UpdateProductRequest: Codable {
    let id: Int
    var productGroupId: Int?
    let name: String
    var code: String?
    var plu: Int?
    var measurementUnit: String?
    let price: Double
    let isTaxInclusivePrice: Bool
    var currencyId: Int?
    let isPriceChangeAllowed: Bool
    let isService: Bool
    let isUsingDefaultQuantity: Bool
    let isEnabled: Bool
    var description: String?
    let cost: Double
    var markup: Double?
    let color: String
    var ageRestriction: Int?
    var lastPurchasePrice: Double?
    var rank: Int?
}

// MARK: - User Model
// Mirrors Back-End/Web-POS.Api/Models/UserDto.cs. There is no "role" string or
// "isBlocked" bool server-side — role is derived from accessLevel (0 = Admin,
// anything else = Cashier; see TokenService.CreateJwt) and status from isEnabled.
struct UserDto: Codable, Identifiable {
    let id: Int
    var firstName: String?
    var lastName: String?
    var username: String?
    var accessLevel: Int
    var isEnabled: Bool
    var email: String?

    var displayName: String {
        if let username, !username.isEmpty { return username }
        let full = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return full.isEmpty ? (email ?? "Unknown") : full
    }

    var roleName: String { accessLevel == 0 ? "Admin" : "Cashier" }
}

// PATCH /api/Users/AdminResetPassword body — Back-End's AdminResetPasswordRequest
// requires a real new password; there is no server-generated "blind reset".
struct AdminResetPasswordRequest: Codable {
    let userId: Int
    let newPassword: String
}

// MARK: - Document Model
// Mirrors Back-End/Web-POS.Api/Models/DocumentDto.cs — the totals field is
// "total", not "totalAmount", and documentTypeName is returned directly so the
// client doesn't need to guess type IDs.
struct DocumentDto: Codable, Identifiable {
    let id: Int
    let number: String?
    let dateCreated: String?
    let total: Double?
    let documentTypeId: Int?
    let documentTypeName: String?
    let customerName: String?
}

// GET /api/DocumentItems/GetByDocumentId response row — mirrors
// Back-End/Web-POS.Api/Models/DocumentItemDto.cs.
struct DocumentItemDto: Codable, Identifiable {
    let id: Int
    let productName: String?
    let productCode: String?
    let quantity: Double
    let price: Double
    let discount: Double
    let total: Double
}

// MARK: - Stock Model
// GET /api/Stocks/GetAllStocks response row — one per (product, warehouse)
// pair. Mirrors Back-End/Web-POS.Api/Models/StockDto.cs.
struct StockDto: Codable, Identifiable {
    let id: Int
    var quantity: Double?
    var warehouseId: Int
    var warehouseName: String?
    var productId: Int
}
