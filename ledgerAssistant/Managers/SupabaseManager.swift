import Foundation
import Supabase
import UIKit

// MARK: - Supabase Manager
class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Load credentials from Secrets.plist
    private var supabaseURL: URL {
        let urlString = loadSecret(named: "SUPABASE_URL")
        return URL(string: urlString) ?? URL(string: "https://placeholder.supabase.co")!
    }
    
    private var supabaseKey: String {
        return loadSecret(named: "SUPABASE_ANON_KEY")
    }
    
    private lazy var client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    
    private init() {}
    
    private func loadSecret(named key: String) -> String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String else {
            print("Warning: \(key) not found in Secrets.plist")
            return ""
        }
        return value
    }
    
    // MARK: - API Calls
    
    func fetchProfile(userId: UUID) async throws -> ProfileRecord? {
        let profile: ProfileRecord? = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return profile
    }
    
    func fetchAllProfiles() async throws -> [ProfileRecord] {
        let profiles: [ProfileRecord] = try await client
            .from("profiles")
            .select()
            .execute()
            .value
        return profiles
    }
    
    func updateProfile(record: ProfileRecord) async throws {
        try await client
            .from("profiles")
            .upsert(record, onConflict: "id")
            .execute()
    }
    
    func fetchCards(userId: UUID) async throws -> [CreditCardRecord] {
        let cards: [CreditCardRecord] = try await client
            .from("credit_cards")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return cards
    }
    
    func deleteCard(id: UUID) async throws {
        try await client
            .from("credit_cards")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func addCard(card: CreditCardRecord) async throws -> CreditCardRecord? {
        let cards: [CreditCardRecord] = try await client
            .from("credit_cards")
            .insert(card)
            .select()
            .execute()
            .value
        return cards.first
    }
    
    func fetchFamily(userId: UUID) async throws -> [FamilyMemberRecord] {
        let family: [FamilyMemberRecord] = try await client
            .from("family_members")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return family
    }
    
    func deleteFamilyMember(id: UUID) async throws {
        try await client
            .from("family_members")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func addFamilyMember(member: FamilyMemberRecord) async throws -> FamilyMemberRecord? {
        let members: [FamilyMemberRecord] = try await client
            .from("family_members")
            .insert(member)
            .select()
            .execute()
            .value
        return members.first
    }
    
    // MARK: - Dashboard & Financials
    
    func fetchCategories() async throws -> [CategoryRecord] {
        let categories: [CategoryRecord] = try await client
            .from("categories")
            .select()
            .execute()
            .value
        return categories
    }
    
    func fetchAccounts(userId: UUID) async throws -> [AccountRecord] {
        let accounts: [AccountRecord] = try await client
            .from("accounts")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return accounts
    }
    
    func fetchTransactions(userId: UUID, startDate: Date? = nil, endDate: Date? = nil) async throws -> [TransactionRecord] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var query = client
            .from("transactions")
            .select("*, line_items:transaction_line_items!inner(*)")
            .eq("line_items.user_id", value: userId)
        
        if let startDate = startDate {
            let startStr = formatter.string(from: startDate)
            query = query.gte("transaction_date", value: startStr)
        }
        
        if let endDate = endDate {
            let endStr = formatter.string(from: endDate)
            query = query.lt("transaction_date", value: endStr)
        }
        
        let transactions: [TransactionRecord] = try await query
            .execute()
            .value
        
        return transactions
    }
    
    private struct TransactionDateOnly: Codable {
        let transaction_date: String?
    }
    
    func fetchAllTransactionDates(userId: UUID) async throws -> [String] {
        let results: [TransactionDateOnly] = try await client
            .from("transactions")
            .select("transaction_date")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return results.compactMap { $0.transaction_date }
    }
    
    // MARK: - Storage & Transactions
    
    func uploadReceiptImage(image: UIImage, userId: UUID, filename: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let path = "\(userId.uuidString)/\(filename).jpg"
        
        try await client.storage
            .from("receipts")
            .upload(path: path, file: data, options: FileOptions(contentType: "image/jpeg"))
        
        let url = try client.storage
            .from("receipts")
            .getPublicURL(path: path)
        
        return url.absoluteString
    }
    
    func createTransaction(transaction: TransactionRecord, lineItems: [TransactionLineItemRecord]) async throws {
        // 1. Insert Transaction
        let insertedTxs: [TransactionRecord] = try await client
            .from("transactions")
            .insert(transaction)
            .select() // Ensure we get the return value
            .execute()
            .value
        
        guard let txId = insertedTxs.first?.id else {
            throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to insert transaction"])
        }
        
        // 2. Insert Line Items with correct tx ID
        // Note: The conversion of multiple payers to multiple line item records 
        // should happen in the ViewModel/View before calling this, 
        // but let's ensure transaction_id is set here.
        var itemsToInsert = lineItems
        for i in 0..<itemsToInsert.count {
            itemsToInsert[i].transaction_id = txId
        }
        
        try await client
            .from("transaction_line_items")
            .insert(itemsToInsert)
            .execute()
    }
}
