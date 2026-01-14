import SwiftUI
import Combine

struct TransactionGroup: Identifiable {
    let id: UUID
    let date: String
    let subtotal: Double
    let receiptUrl: String?
    let lineItems: [TransactionLineItemRecord]
    let originalTransaction: TransactionRecord? // Store for lookup
}

struct SelectedImage: Identifiable {
    let id = UUID()
    let url: String
}

class DashboardViewModel: ObservableObject {
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date()) {
        didSet { Task { await fetchDashboardData() } }
    }
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date()) - 1 {
        didSet { Task { await fetchDashboardData() } }
    }
    @Published var showingProfile = false
    @Published var userName: String = ""
    @Published var transactions: [TransactionRecord] = []
    @Published var totalExpenditure: String = "$0"
    @Published var totalBalance: String = "$0"
    @Published var monthlyIncome: String = "$0"
    @Published var monthlyExpense: String = "$0"
    @Published var chartSegments: [ChartSegment] = []
    @Published var expenditureChange: String = "0%"
    @Published var selectedCategory: LedgerCategory? = nil
    @Published var selectedImageUrl: String? = nil
    
    // Loaded Resources for lookups
    var familyMembers: [FamilyMemberRecord] = []
    var creditCards: [CreditCardRecord] = []
    
    // Scanner State
    @Published var showingScanner = false
    @Published var scannerSource: UIImagePickerController.SourceType = .camera
    @Published var selectedImage: UIImage? = nil
    @Published var showingRegister = false
    @Published var showingScanOptions = false
    
    // Voice State
    @Published var showingVoiceOverlay = false
    @Published var voiceSource: EntrySource? = nil
    var speechManager = SpeechManager()
    private var speechManagerCancellable: AnyCancellable?
    
    var filteredTransactions: [TransactionRecord] {
        guard let selected = selectedCategory else { return transactions }
        guard let catRecord = categories.first(where: { $0.name == selected.rawValue }) else { return [] }
        
        return transactions.filter { tx in
            tx.line_items?.contains(where: { $0.category_id == catRecord.id }) ?? false
        }
    }
    
    var groupedTransactions: [TransactionGroup] {
        let filtered = transactions // We start with all transactions for the month
        
        return filtered.compactMap { tx in
            guard let txId = tx.id else { return nil }
            
            let allItems = tx.line_items ?? []
            
            // Filter line items based on selected category if any
            let displayItems: [TransactionLineItemRecord]
            if let selected = selectedCategory,
               let catRecord = categories.first(where: { $0.name == selected.rawValue }) {
                displayItems = allItems.filter { $0.category_id == catRecord.id }
            } else {
                displayItems = allItems
            }
            
            // If we have a category filter, and this transaction has no items in that category, skip it
            if selectedCategory != nil && displayItems.isEmpty {
                return nil
            }
            
            let subtotal = displayItems.reduce(0) { $0 + $1.amount }
            
            return TransactionGroup(
                id: txId,
                date: formatDate(tx.transaction_date),
                subtotal: subtotal,
                receiptUrl: tx.receipt_url,
                lineItems: displayItems,
                originalTransaction: tx
            )
        }.sorted(by: { 
            // Better sorting: extract the original transaction record to compare dates if needed, 
            // but for now let's just use the group's date string carefully or better yet, 
            // since one group = one transaction, we can just sort by the original transactions' dates.
            // Actually, let's just use the transaction_date from the original record by including it in the group if needed.
            // For now, sorting by group.id is not useful, let's just make it alphabetical by date string as a fallback.
            $0.date > $1.date 
        })
    }
    
    private var categories: [CategoryRecord] = []
    
    let months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]

    let years: [Int] = Array((Calendar.current.component(.year, from: Date())-2)...(Calendar.current.component(.year, from: Date())+1))
    
    private let userId = UUID(uuidString: "DE571E1C-681C-44A0-A823-45F4B82B3DD5")! 
    
    init() {
        // Forward speechManager's changes
        speechManagerCancellable = speechManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        
        Task {
            await fetchDashboardData()
        }
    }
    
    @MainActor
    func fetchDashboardData() async {
        do {
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = selectedYear
            components.month = selectedMonth + 1
            components.day = 1
            
            guard let startDate = calendar.date(from: components),
                  let endDate = calendar.date(byAdding: .month, value: 1, to: startDate),
                  let prevMonthStartDate = calendar.date(byAdding: .month, value: -1, to: startDate) else { return }
            
            let prevMonthEndDate = startDate
            
            // Fetch Data concurrently
            async let fetchedTransactions = SupabaseManager.shared.fetchTransactions(userId: userId, startDate: startDate, endDate: endDate)
            async let fetchedPrevTransactions = SupabaseManager.shared.fetchTransactions(userId: userId, startDate: prevMonthStartDate, endDate: prevMonthEndDate)
            async let fetchedAccounts = SupabaseManager.shared.fetchAccounts(userId: userId)
            async let fetchedCategories = SupabaseManager.shared.fetchCategories()
            async let fetchedProfile = SupabaseManager.shared.fetchProfile(userId: userId)
            async let fetchedFamily = SupabaseManager.shared.fetchFamily(userId: userId)
            async let fetchedCards = SupabaseManager.shared.fetchCards(userId: userId)
            
            let (txs, prevTxs, accounts, cats, profile, family, cards) = try await (fetchedTransactions, fetchedPrevTransactions, fetchedAccounts, fetchedCategories, fetchedProfile, fetchedFamily, fetchedCards)
            
            self.transactions = txs
            self.categories = cats
            self.familyMembers = family
            self.creditCards = cards
            
            // Formatters
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            
            // Calculate Totals
            let income = txs.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
            let expense = txs.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
            let prevExpense = prevTxs.filter { $0.type == "expense" }.reduce(0) { $0 + $1.amount }
            
            self.userName = profile?.username ?? "使用者"
            
            // New Balance Logic: Remaining Budget = Monthly Limit - Current Month Expenses
            let monthlyBudget = profile?.monthly_limit ?? 10000.0
            let remainingBalance = monthlyBudget - expense
            
            self.monthlyIncome = formatter.string(from: NSNumber(value: income)) ?? "$\(Int(income))"
            self.monthlyExpense = formatter.string(from: NSNumber(value: expense)) ?? "$\(Int(expense))"
            
            // Update totalExpenditure based on selected category if any
            updateDisplayAmount()
            
            self.totalBalance = formatter.string(from: NSNumber(value: remainingBalance)) ?? "$\(Int(remainingBalance))"
            
            // Calculate Expenditure Change
            if prevExpense > 0 {
                let change = ((expense - prevExpense) / prevExpense) * 100
                let sign = change >= 0 ? "+" : ""
                self.expenditureChange = "\(sign)\(Int(change))%"
            } else {
                self.expenditureChange = "0%"
            }
            
            // Calculate Chart Segments
            calculateChartSegments(txs: txs, categories: cats)
            
        } catch {
            print("Error fetching dashboard data: \(error)")
        }
    }
    
    private func calculateChartSegments(txs: [TransactionRecord], categories: [CategoryRecord]) {
        let expenses = txs.filter { $0.type == "expense" }
        let totalExpense = expenses.reduce(0) { $0 + $1.amount }
        
        guard totalExpense > 0 else {
            self.chartSegments = []
            return
        }
        
        // Group amounts by category_id from line items
        var categoryAmounts: [UUID: Double] = [:]
        for tx in expenses {
            for item in tx.line_items ?? [] {
                if let catId = item.category_id {
                    categoryAmounts[catId, default: 0] += item.amount
                }
            }
        }
        
        var segments: [ChartSegment] = []
        for (catId, amount) in categoryAmounts {
            let proportion = amount / totalExpense
            let cat = categories.first { $0.id == catId }
            let colorHex = cat?.color ?? "000000"
            segments.append(ChartSegment(proportion: proportion, color: Color(hex: colorHex)))
        }
        
        // If there's missing category info or remaining amount, add as "Other"
        let coveredProportion = segments.reduce(0) { $0 + $1.proportion }
        if coveredProportion < 0.99 && coveredProportion >= 0 {
             segments.append(ChartSegment(proportion: 1.0 - coveredProportion, color: .gray))
        }
        
        self.chartSegments = segments
    }
    
    func getCategoryIcon(for transaction: TransactionRecord) -> String {
        // Just use the first line item's category for simplicity
        if let catId = transaction.line_items?.first?.category_id,
           let cat = categories.first(where: { $0.id == catId }),
           let icon = cat.icon {
            return icon
        }
        return "ellipsis.circle.fill"
    }
    
    func getCategoryIconForId(_ categoryId: UUID?) -> String {
        guard let id = categoryId else { return "ellipsis.circle.fill" }
        if let cat = categories.first(where: { $0.id == id }), let icon = cat.icon {
            return icon
        }
        return "ellipsis.circle.fill"
    }
    
    func getTransactionTitle(for transaction: TransactionRecord) -> String {
        // 1. Try to get title from the first line item
        if let firstItem = transaction.line_items?.first, !firstItem.name.isEmpty {
            if (transaction.line_items?.count ?? 0) > 1 {
                return "\(firstItem.name) 等..."
            }
            return firstItem.name
        }
        
        // 2. Fallback to transaction note
        if let note = transaction.note, !note.isEmpty {
            return note
        }
        
        // 3. Last fallback
        return "交易"
    }
    
    func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        // Supabase returns ISO8601 usually
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        
        // If ISO8601 with fractional seconds fails, try without
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        
        // If it's already just a date string or unexpected format, try a simple parser
        let simpleFormatter = DateFormatter()
        simpleFormatter.dateFormat = "yyyy-MM-dd"
        if let date = simpleFormatter.date(from: String(dateString.prefix(10))) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy/MM/dd"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    func getPaymentMethodName(for transaction: TransactionRecord) -> String {
        if let cardId = transaction.credit_card_id {
            return creditCards.first(where: { $0.id == cardId })?.card_name ?? "信用卡"
        }
        return "現金"
    }
    
    func getPayerName(for item: TransactionLineItemRecord) -> String {
        // Only check for specific family member assigned
        if let fmId = item.family_member_id {
            if let member = familyMembers.first(where: { $0.id == fmId }) {
                return member.name
            }
        }
        
        // No longer falling back to transaction owner (userName)
        return ""
    }
    
    func selectCategory(_ category: LedgerCategory) {
        if selectedCategory == category {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
        updateDisplayAmount()
    }
    
    private func updateDisplayAmount() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        
        if let selected = selectedCategory {
            // Find category UUID in our categories list
            if let catRecord = categories.first(where: { $0.name == selected.rawValue }) {
                let amount = transactions.filter { tx in
                    tx.type == "expense" && (tx.line_items?.contains(where: { $0.category_id == catRecord.id }) ?? false)
                }.reduce(0) { $0 + $1.amount }
                self.totalExpenditure = formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
            } else {
                self.totalExpenditure = "$0"
            }
        } else {
            self.totalExpenditure = self.monthlyExpense
        }
    }
    
    func startVoiceRecording() {
        speechManager.requestPermissions { [weak self] granted in
            guard let self = self else { return }
            self.showingVoiceOverlay = true
            if granted {
                do {
                    try self.speechManager.startRecording()
                } catch {
                    self.speechManager.error = "啟動失敗: \(error.localizedDescription)"
                }
            } else {
                self.speechManager.error = "請開啟麥克風與語音辨識權限"
            }
        }
    }
    
    func stopVoiceRecording() {
        speechManager.stopRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !self.speechManager.transcribedText.isEmpty {
                self.voiceSource = .voice(self.speechManager.transcribedText)
                self.showingVoiceOverlay = false
                self.showingRegister = true
            } else {
                self.showingVoiceOverlay = false
            }
        }
    }
}
