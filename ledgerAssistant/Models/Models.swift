import Foundation

// MARK: - Models
struct ProfileRecord: Codable {
    var id: UUID
    var username: String?
    var avatar_url: String?
    var updated_at: String?
    var birthday: String? // Store as "YYYY-MM-DD"
    var phone: String?
    var monthly_limit: Double?
}

struct CategoryRecord: Codable, Identifiable {
    var id: UUID?
    var name: String
    var icon: String?
    var color: String?
}

struct AccountRecord: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID
    var name: String
    var balance: Double
}

struct CreditCardRecord: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID?
    var card_name: String
    var billing_day: Int
}

struct FamilyMemberRecord: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID?
    var name: String
    var is_default: Bool?
}

// MARK: - Transaction Models
struct TransactionRecord: Codable, Identifiable {
    var id: UUID?
    var user_id: UUID? // Added for RLS
    var account_id: UUID?
    var credit_card_id: UUID?
    var type: String // "income" or "expense"
    var amount: Double // Total amount
    var note: String?
    var transaction_date: String? // "YYYY-MM-DD" or ISO8601
    var receipt_url: String?
    
    // Virtual property for line items (decoded from join)
    var line_items: [TransactionLineItemRecord]?
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, account_id, credit_card_id, type, amount, note, transaction_date, receipt_url, line_items
    }
    
    // Custom encoding to skip line_items during insert/upsert
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(user_id, forKey: .user_id)
        try container.encodeIfPresent(account_id, forKey: .account_id)
        try container.encodeIfPresent(credit_card_id, forKey: .credit_card_id)
        try container.encode(type, forKey: .type)
        try container.encode(amount, forKey: .amount)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(transaction_date, forKey: .transaction_date)
        try container.encodeIfPresent(receipt_url, forKey: .receipt_url)
        // We SKIP encoding line_items because it's not a real column in the transactions table
    }
}

struct TransactionLineItemRecord: Codable, Identifiable {
    var id: UUID?
    var transaction_id: UUID
    var user_id: UUID? // The transaction owner
    var payer_name: String? // Added to preserve name even if member is deleted
    var name: String
    var amount: Double
    var quantity: Int
    var category_id: UUID?
    var title: String?
}


