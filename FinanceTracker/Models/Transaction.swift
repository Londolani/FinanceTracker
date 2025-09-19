import Foundation

struct Transaction: Identifiable, Codable, Hashable {
    let id: String
    let accountId: String
    var type: String?
    var transactionType: String?
    var status: String?
    var description: String
    var amount: Double
    var currency: String?
    var postingDate: String?
    var valueDate: String?
    var transactionDate: String?
    var actionDate: String?
    var category: String?
    var cardNumber: String?
    var runningBalance: Double?
    var postedOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id = "uuid"
        case accountId
        case type
        case transactionType
        case status
        case description
        case amount
        case currency
        case postingDate
        case valueDate
        case transactionDate
        case actionDate
        case category
        case cardNumber
        case runningBalance
        case postedOrder
    }

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }
}
