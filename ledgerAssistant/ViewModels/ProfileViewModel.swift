import SwiftUI
import Combine

class ProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage: String?
    
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
    
    // User ID from SupabaseManager
    private var userId: UUID {
        return SupabaseManager.shared.currentUserId ?? UUID()
    }
    
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
                    self.successMessage = "儲存成功！"
                    self.showSuccess = true
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
                    self.errorMessage = "刪除失敗：此卡已有交易紀錄，無法刪除。"
                    self.showError = true
                }
            }
        }
    }

    func updateCard(card: CreditCardRecord) {
        Task {
            do {
                try await SupabaseManager.shared.updateCard(card: card)
                await MainActor.run {
                    if let index = self.cards.firstIndex(where: { $0.id == card.id }) {
                        self.cards[index] = card
                    }
                }
            } catch {
                print("Error updating card: \(error)")
                await MainActor.run {
                    self.errorMessage = "更新信用卡失敗: \(error.localizedDescription)"
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
                    self.errorMessage = "刪除失敗：該成員已有交易，無法刪除。"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }

    func updateFamilyMember(member: FamilyMemberRecord) {
        Task {
            do {
                try await SupabaseManager.shared.updateFamilyMember(member: member)
                await MainActor.run {
                    if let index = self.family.firstIndex(where: { $0.id == member.id }) {
                        self.family[index] = member
                    }
                }
            } catch {
                print("Error updating family member: \(error)")
                await MainActor.run {
                    self.errorMessage = "更新家庭成員失敗: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    func toggleDefaultMember(id: UUID) {
        isLoading = true
        Task {
            do {
                // Determine new state: only one can be default
                var updatedFamily = family
                for i in 0..<updatedFamily.count {
                    if updatedFamily[i].id == id {
                        // Toggle this one
                        let currentState = updatedFamily[i].is_default ?? false
                        updatedFamily[i].is_default = !currentState
                    } else {
                        // Others must be false if the toggled one became true
                    }
                }
                
                // If we just set one to true, others must be false
                let memberToggled = updatedFamily.first(where: { $0.id == id })
                if memberToggled?.is_default == true {
                    for i in 0..<updatedFamily.count {
                        if updatedFamily[i].id != id {
                            updatedFamily[i].is_default = false
                        }
                    }
                }
                
                // Save all changes to database
                for member in updatedFamily {
                    try await SupabaseManager.shared.updateFamilyMember(member: member)
                }
                
                await MainActor.run {
                    self.family = updatedFamily
                    self.isLoading = false
                }
            } catch {
                print("Error updating default member: \(error)")
                await MainActor.run {
                    self.errorMessage = "更新預設成員失敗: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
}
