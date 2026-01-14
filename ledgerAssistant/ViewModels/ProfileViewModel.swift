import SwiftUI
import Combine

class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Account Info
    @Published var name: String = ""
    @Published var birthday: Date = Date()
    @Published var phone: String = ""
    
    // Credit Cards
    @Published var cards: [CreditCardRecord] = []
    @Published var newCardName = ""
    @Published var newCardDay = 1
    
    // Family Members
    @Published var family: [FamilyMemberRecord] = []
    @Published var newFamilyName = ""
    
    // Limits
    @Published var monthlyLimit: Double = 10000
    
    // Hardcoded UserID for demonstration
    private let userId = UUID(uuidString: "DE571E1C-681C-44A0-A823-45F4B82B3DD5")!
    
    func loadData() {
        isLoading = true
        Task {
            do {
                if let profile = try await SupabaseManager.shared.fetchProfile(userId: userId) {
                    await MainActor.run {
                        self.name = profile.username ?? ""
                        self.phone = profile.phone ?? ""
                        self.monthlyLimit = profile.monthly_limit ?? 10000
                        
                        if let bDay = profile.birthday {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd"
                            self.birthday = formatter.date(from: bDay) ?? Date()
                        }
                    }
                }
                
                let cards = try await SupabaseManager.shared.fetchCards(userId: userId)
                let family = try await SupabaseManager.shared.fetchFamily(userId: userId)
                
                await MainActor.run {
                    self.cards = cards
                    self.family = family
                    self.isLoading = false
                }
            } catch {
                print("Error loading data: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func saveProfile(completion: @escaping () -> Void) {
        isLoading = true
        Task {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let birthdayString = formatter.string(from: birthday)
            
            let record = ProfileRecord(
                id: userId,
                username: name,
                avatar_url: nil,
                updated_at: nil,
                birthday: birthdayString,
                phone: phone,
                monthly_limit: monthlyLimit
            )
            
            do {
                try await SupabaseManager.shared.updateProfile(record: record)
                await MainActor.run {
                    self.isLoading = false
                    completion()
                }
            } catch {
                print("Error saving profile: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func addNewCard() {
        guard !newCardName.isEmpty else { return }
        let newCard = CreditCardRecord(user_id: userId, card_name: newCardName, billing_day: newCardDay)
        
        Task {
            do {
                if let savedCard = try await SupabaseManager.shared.addCard(card: newCard) {
                    await MainActor.run {
                        self.cards.append(savedCard)
                        self.newCardName = ""
                        print("Successfully added card: \(savedCard.card_name)")
                    }
                }
            } catch {
                print("Error adding card: \(error)")
                await MainActor.run {
                    self.errorMessage = "新增信用卡失敗: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func removeCard(id: UUID) {
        Task {
            do {
                try await SupabaseManager.shared.deleteCard(id: id)
                await MainActor.run {
                    self.cards.removeAll { $0.id == id }
                }
            } catch {
                print("Error deleting card: \(error)")
                await MainActor.run {
                    self.errorMessage = "刪除信用卡失敗: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func addNewFamilyMember() {
        guard !newFamilyName.isEmpty else { return }
        let newMember = FamilyMemberRecord(user_id: userId, name: newFamilyName)
        
        Task {
            do {
                if let savedMember = try await SupabaseManager.shared.addFamilyMember(member: newMember) {
                    await MainActor.run {
                        self.family.append(savedMember)
                        self.newFamilyName = ""
                        print("Successfully added family member: \(savedMember.name)")
                    }
                }
            } catch {
                print("Error adding family: \(error)")
                await MainActor.run {
                    self.errorMessage = "新增家庭成員失敗: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func removeFamilyMember(id: UUID) {
        Task {
            do {
                try await SupabaseManager.shared.deleteFamilyMember(id: id)
                await MainActor.run {
                    self.family.removeAll { $0.id == id }
                }
            } catch {
                print("Error deleting family member: \(error)")
                await MainActor.run {
                    self.errorMessage = "刪除家庭成員失敗: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
}
