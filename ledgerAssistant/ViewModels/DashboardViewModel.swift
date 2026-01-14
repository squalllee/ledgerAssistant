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

struct TimelineItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
}

struct TimelineCategoryGroup: Identifiable {
    let id: String // Use stable combination ID
    let category: LedgerCategory
    let items: [TimelineItem]
    let total: Double
    let receiptUrls: [String]
    let paymentMethod: String?
    let payerName: String?
}

struct TimelineDateGroup: Identifiable {
    var id: String { displayDate }
    let displayDate: String
    let dailyTotal: Double
    let categoryGroups: [TimelineCategoryGroup]
}

struct SelectedImage: Identifiable {
    var id: String { url }
    let url: String
}

struct CategoryStat: Identifiable {
    let id: UUID = UUID()
    let category: LedgerCategory
    let amount: Double
    let proportion: Double
    let change: String?
}

class DashboardViewModel: ObservableObject {
    @Published var selectedYear: Int = Calendar.current.component(.year, from: Date()) {
        didSet { Task { await fetchDashboardData() } }
    }
    @Published var selectedMonth: Int = Calendar.current.component(.month, from: Date()) - 1 {
        didSet { Task { await fetchDashboardData() } }
    }
    @Published var showingProfile = false
    @Published var showingReports = false
    @Published var userName: String = ""
    @Published var transactions: [TransactionRecord] = []
    @Published var totalExpenditure: String = "$0"
    @Published var totalBalance: String = "$0"
    @Published var monthlyIncome: String = "$0"
    @Published var monthlyExpense: String = "$0"
    @Published var accounts: [AccountRecord] = []
    @Published var chartSegments: [ChartSegment] = []
    @Published var expenditureChange: String = "0%"
    @Published var selectedCategory: LedgerCategory? = nil
    @Published var selectedImageUrl: String? = nil
    @Published var monthlyLimit: Double = 10000.0
    @Published var years: [Int] = [Calendar.current.component(.year, from: Date())]
    @Published var categoryStats: [CategoryStat] = []
    @Published var reportType: String = "expense" {
        didSet { calculateChartSegments(txs: transactions, categories: categories) }
    }
    
    @Published var weatherIcon: String = "sun.max.fill"
    @Published var temperature: String = "--°C"
    @Published var currentTime: String = ""
    
    private var timer: Timer?
    
    private var weatherManager = WeatherManager.shared
    private var weatherCancellable: AnyCancellable?
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早安!"
        case 11..<14: return "午安!"
        case 14..<18: return "下午好!"
        case 18..<24: return "晚安!"
        default: return "凌晨好!"
        }
    }
    
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
            $0.date > $1.date 
        })
    }
    
    var timelineGroups: [TimelineDateGroup] {
        let allTxs = transactions
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        
        // Group by date string
        let groupedByDate = Dictionary(grouping: allTxs) { formatDate($0.transaction_date) }
        
        return groupedByDate.map { (dateStr, txs) in
            // Calculate daily total
            let dailyTotal = txs.reduce(0) { $0 + $1.amount }
            
            // Generate category groups for each transaction separately
            let categoryGroups = txs.flatMap { tx -> [TimelineCategoryGroup] in
                let itemsByCat = Dictionary(grouping: tx.line_items ?? []) { item in
                    categories.first(where: { $0.id == item.category_id })?.name ?? ""
                }
                
                return itemsByCat.map { (catName, items) in
                    let cat = LedgerCategory(rawValue: catName) ?? .other
                    let txIdStr = tx.id?.uuidString ?? UUID().uuidString
                    
                    // Resolve Payment Method Name
                    var pMethod: String? = "現金"
                    if let cardId = tx.credit_card_id {
                        pMethod = self.creditCards.first(where: { $0.id == cardId })?.card_name
                    } else if let accId = tx.account_id {
                        pMethod = self.accounts.first(where: { $0.id == accId })?.name
                    }
                    
                    // Resolve Payer Names
                    let payerIds = Set(items.compactMap { $0.family_member_id })
                    var pName: String? = nil
                    if !payerIds.isEmpty {
                        let names = payerIds.compactMap { pid in
                            self.familyMembers.first(where: { $0.id == pid })?.name
                        }
                        if names.count > 1 {
                            pName = "多位"
                        } else {
                            pName = names.first
                        }
                    }

                    return TimelineCategoryGroup(
                        id: "\(txIdStr)-\(catName)",
                        category: cat,
                        items: items.map { TimelineItem(name: $0.name, amount: $0.amount) },
                        total: items.reduce(0) { $0 + $1.amount },
                        receiptUrls: [tx.receipt_url].compactMap { $0 }.filter { !$0.isEmpty },
                        paymentMethod: pMethod,
                        payerName: pName
                    )
                }
            }.sorted { 
                // Grouping by category name first, then by amount
                if $0.category == $1.category {
                    return $0.total > $1.total
                }
                return $0.category.rawValue < $1.category.rawValue
            }
            
            return TimelineDateGroup(
                displayDate: dateStr,
                dailyTotal: dailyTotal,
                categoryGroups: categoryGroups
            )
        }.sorted { $0.displayDate > $1.displayDate }
    }
    
    private var categories: [CategoryRecord] = []
    
    let months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    
    private let userId = UUID(uuidString: "DE571E1C-681C-44A0-A823-45F4B82B3DD5")! 
    
    init() {
        // Forward speechManager's changes
        speechManagerCancellable = speechManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        
        weatherCancellable = Publishers.CombineLatest(weatherManager.$weatherIcon, weatherManager.$temperature)
            .sink { [weak self] icon, temp in
                self?.weatherIcon = icon
                self?.temperature = temp
            }
        
        startTimer()
        
        weatherManager.requestLocation()
        
        Task {
            await fetchYearRange()
            await fetchDashboardData()
        }
    }
    
    private func startTimer() {
        updateTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
    }
    
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        currentTime = formatter.string(from: Date())
    }
    
    @MainActor
    private func fetchYearRange() async {
        do {
            let dateStrings = try await SupabaseManager.shared.fetchAllTransactionDates(userId: userId)
            print("Fetched \(dateStrings.count) transaction dates for year range")
            
            let txYears = dateStrings.compactMap { dateStr -> Int? in
                if let date = Self.isoFormatter.date(from: dateStr) {
                    return Calendar.current.component(.year, from: date)
                }
                if let date = Self.isoFormatterNoFractional.date(from: dateStr) {
                    return Calendar.current.component(.year, from: date)
                }
                if let date = Self.simpleDateFormatter.date(from: String(dateStr.prefix(10))) {
                    return Calendar.current.component(.year, from: date)
                }
                print("Failed to parse year from: \(dateStr)")
                return nil
            }
            
            print("Found years in transactions: \(Set(txYears))")
            
            let currentYear = Calendar.current.component(.year, from: Date())
            var uniqueYears = Set(txYears)
            uniqueYears.insert(currentYear)
            
            self.years = Array(uniqueYears).sorted()
            print("Final year range: \(self.years)")
        } catch {
            print("Error fetching year range: \(error)")
        }
    }
    
    func nextMonth() {
        if selectedMonth == 11 {
            selectedMonth = 0
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
    }
    
    func prevMonth() {
        if selectedMonth == 0 {
            selectedMonth = 11
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
    }
    
    @MainActor
    func fetchDashboardData() async {
        // Only request location in init or manual refresh to avoid loops
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
            
            self.categories = cats
            self.familyMembers = family
            self.creditCards = cards
            self.accounts = accounts
            self.transactions = txs // Set transactions LAST
            
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
            self.monthlyLimit = monthlyBudget
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
        let filteredTxs = txs.filter { $0.type == reportType }
        let totalAmount = filteredTxs.reduce(0) { $0 + $1.amount }
        
        // Use monthlyLimit for proportions if it's expense, otherwise just use totalAmount
        let denominator = reportType == "expense" ? max(1.0, monthlyLimit) : max(1.0, totalAmount)
        
        // Group amounts by category_id from line items
        var categoryAmounts: [UUID: Double] = [:]
        for tx in filteredTxs {
            for item in tx.line_items ?? [] {
                if let catId = item.category_id {
                    categoryAmounts[catId, default: 0] += item.amount
                } else {
                    // Group unknown categories under "Other" if possible
                    let otherCatId = categories.first(where: { $0.name == LedgerCategory.other.rawValue })?.id
                    if let oid = otherCatId {
                        categoryAmounts[oid, default: 0] += item.amount
                    }
                }
            }
        }
        
        // Calculate Category Stats first
        var stats: [CategoryStat] = []
        for cat in LedgerCategory.allCases {
            let catRecord = categories.first { $0.name == cat.rawValue }
            let amount = categoryAmounts[catRecord?.id ?? UUID()] ?? 0
            let proportion = amount / max(1.0, denominator)
            stats.append(CategoryStat(category: cat, amount: amount, proportion: proportion, change: nil))
        }
        
        // Sort by amount descending
        let sortedStats = stats.sorted { $0.amount > $1.amount }
        self.categoryStats = sortedStats
        
        // Generate Chart Segments from the sorted stats to ensure color consistency
        var segments: [ChartSegment] = []
        for stat in sortedStats {
            if stat.amount > 0 {
                // Ensure we use the color defined in LedgerCategory
                segments.append(ChartSegment(proportion: stat.proportion, color: stat.category.color))
            }
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
    
    func getCategoryColorForId(_ categoryId: UUID?) -> Color {
        guard let id = categoryId else { return .gray }
        if let catRecord = categories.first(where: { $0.id == id }) {
            let ledgerCat = LedgerCategory(rawValue: catRecord.name) ?? .other
            return ledgerCat.color
        }
        return .gray
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
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    
    private static let simpleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
        if let date = Self.isoFormatter.date(from: dateString) {
            return Self.displayDateFormatter.string(from: date)
        }
        
        if let date = Self.isoFormatterNoFractional.date(from: dateString) {
            return Self.displayDateFormatter.string(from: date)
        }
        
        if let date = Self.simpleDateFormatter.date(from: String(dateString.prefix(10))) {
            return Self.displayDateFormatter.string(from: date)
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
    
    func refreshWeather() {
        weatherManager.requestLocation()
    }
}
