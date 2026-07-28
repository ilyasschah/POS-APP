import Foundation

// MARK: - Product Model
struct ProductDto: Codable, Identifiable {
    let id: Int
    var name: String?
    var code: String?
    var salePrice: Double?
    var costPrice: Double?
    var isTaxInclusive: Bool?
    var productGroupId: Int?
}

// Update Command Payload matching C# UpdateProductCommand
struct UpdateProductRequest: Codable {
    let id: Int
    let name: String
    let code: String
    let salePrice: Double
    let costPrice: Double
    let companyId: Int
}

// MARK: - User Model
struct UserDto: Codable, Identifiable {
    let id: Int
    var userName: String?
    var email: String?
    var role: String?
    var isBlocked: Bool?
}

// MARK: - Document Model
struct DocumentDto: Codable, Identifiable {
    let id: Int
    let number: String?
    let dateCreated: String?
    let totalAmount: Double?
    let documentTypeId: Int?
    let customerName: String?
}
