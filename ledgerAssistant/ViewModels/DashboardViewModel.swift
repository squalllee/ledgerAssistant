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
    let categoryName: String // The actual name from DB
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
    var amount: Double
    var proportion: Double
    let change: String?
}

struct PaymentMethodStat: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let type: String // "cash" or "credit_card"
    let billingDay: Int?
    let period: String
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
    @Published var chartSegments: [ChartSegment] = []
    @Published var expenditureChange: String = "0%"
    @Published var selectedCategory: LedgerCategory? = nil
    @Published var selectedImageUrl: String? = nil
    @Published var monthlyLimit: Double = 10000.0
    @Published var years: [Int] = [Calendar.current.component(.year, from: Date())]
    @Published var categoryStats: [CategoryStat] = []
    @Published var paymentMethodStats: [PaymentMethodStat] = []
    @Published var reportType: String = "expense" { // "expense", "income", "billing"
        didSet { 
            if reportType == "billing" {
                chartSegments = []
            } else {
                calculateChartSegments(txs: transactions, categories: allCategories)
            }
        }
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
        
        return transactions.filter { tx in
            let items = tx.transaction_line_items ?? []
            if items.isEmpty {
                return selected == .other
            }
            return items.contains { item in
                self.resolveLedgerCategory(for: item.category_id) == selected
            }
        }
    }
    
    var groupedTransactions: [TransactionGroup] {
        let filtered = transactions 
        
        return filtered.compactMap { tx in
            guard let txId = tx.id else { return nil }
            
            let allItems = tx.transaction_line_items ?? []
            
            // Filter line items based on selected category if any
            let displayItems: [TransactionLineItemRecord]
            if let selected = selectedCategory {
                displayItems = allItems.filter { item in
                    self.resolveLedgerCategory(for: item.category_id) == selected
                }
                
                // If it's the other category and items are empty, the whole transaction is "Other"
                if allItems.isEmpty && selected == .other {
                    return TransactionGroup(
                        id: txId,
                        date: formatDate(tx.transaction_date),
                        subtotal: tx.amount,
                        receiptUrl: tx.receipt_url,
                        lineItems: [], 
                        originalTransaction: tx
                    )
                }
                
                if displayItems.isEmpty { return nil }
            } else {
                displayItems = allItems
            }
            
            let subtotal = displayItems.isEmpty ? tx.amount : displayItems.reduce(0) { $0 + $1.amount }
            
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
        let groupedByDate = Dictionary(grouping: transactions) { formatDate($0.transaction_date) }
        
        return groupedByDate.map { (dateStr, txs) in
            self.createTimelineDateGroup(dateStr: dateStr, txs: txs)
        }.sorted { $0.displayDate > $1.displayDate }
    }

    private func createTimelineDateGroup(dateStr: String, txs: [TransactionRecord]) -> TimelineDateGroup {
        let dailyTotal = txs.reduce(0) { $0 + $1.amount }
        
        let categoryGroups = txs.flatMap { tx in
            self.processTransactionForTimeline(tx)
        }.sorted { 
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
    }

    private func processTransactionForTimeline(_ tx: TransactionRecord) -> [TimelineCategoryGroup] {
        let txIdStr = tx.id?.uuidString ?? UUID().uuidString
        let lineItems = tx.transaction_line_items ?? []
        
        var pMethod: String? = "現金"
        if let cardId = tx.credit_card_id {
            pMethod = self.creditCards.first(where: { $0.id == cardId })?.card_name
        }
        
        if lineItems.isEmpty {
            let txTitle = getTransactionTitle(for: tx)
            return [TimelineCategoryGroup(
                id: "\(txIdStr)-none",
                category: .other,
                categoryName: LedgerCategory.other.rawValue,
                items: [TimelineItem(name: txTitle, amount: tx.amount)],
                total: tx.amount,
                receiptUrls: [tx.receipt_url].compactMap { $0 }.filter { !$0.isEmpty },
                paymentMethod: pMethod,
                payerName: nil
            )]
        }

        // Group items by their resolved LedgerCategory
        let itemsByCat = Dictionary(grouping: lineItems) { item in
            self.resolveLedgerCategory(for: item.category_id)
        }
        
        return itemsByCat.map { (cat, items) in
            // Get the actual display name from the first item's category record
            var actualDbName = cat.rawValue
            if let firstCatId = items.first?.category_id {
                let normalizedId = firstCatId.lowercased()
                if let dbCat = allCategories.first(where: { $0.id?.lowercased() == normalizedId }) {
                    actualDbName = dbCat.name
                }
            }
            
            // Resolve Payer Names
            let payerNames = Set(items.compactMap { $0.payer_name })
            var pName: String? = nil
            if !payerNames.isEmpty {
                pName = payerNames.count > 1 ? "多位" : payerNames.first
            }

            return TimelineCategoryGroup(
                id: "\(txIdStr)-\(cat.rawValue)",
                category: cat,
                categoryName: actualDbName,
                items: items.map { TimelineItem(name: $0.name, amount: $0.amount) },
                total: items.reduce(0) { $0 + $1.amount },
                receiptUrls: [tx.receipt_url].compactMap { $0 }.filter { !$0.isEmpty },
                paymentMethod: pMethod,
                payerName: pName
            )
        }
    }

    private func resolveLedgerCategory(for categoryId: String?) -> LedgerCategory {
        guard let id = categoryId, !id.isEmpty else { return .other }
        
        let normalizedId = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Try to find by ID first
        if let dbCat = allCategories.first(where: { $0.id?.lowercased() == normalizedId }) {
            if let localCat = LedgerCategory(rawValue: dbCat.name) {
                return localCat
            }
            
            // Handle variants of "Other" or name mismatches
            let name = dbCat.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "其他" || name == "其它" {
                return .other
            }
            
            if let localCat = LedgerCategory(rawValue: name) {
                return localCat
            }
        }
        
        // 2. Fallback: If ID is actually the name (migration artifact), match by name
        for cat in LedgerCategory.allCases {
            if normalizedId == cat.rawValue || normalizedId == cat.id {
                return cat
            }
        }
        
        return .other
    }
    
    @Published var allCategories: [CategoryRecord] = []
    
    let months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    
    private var userId: UUID {
        return SupabaseManager.shared.currentUserId ?? UUID()
    }
    
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
            async let fetchedCategories = SupabaseManager.shared.fetchCategories()
            async let fetchedProfile = SupabaseManager.shared.fetchProfile(userId: userId)
            async let fetchedFamily = SupabaseManager.shared.fetchFamily(userId: userId)
            async let fetchedCards = SupabaseManager.shared.fetchCards(userId: userId)
            
            let (txs, prevTxs, cats, profile, family, cards) = try await (fetchedTransactions, fetchedPrevTransactions, fetchedCategories, fetchedProfile, fetchedFamily, fetchedCards)
            
            self.allCategories = cats
            self.familyMembers = family
            self.creditCards = cards
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
            
            // Calculate Payment Method Stats
            calculatePaymentMethodStats(currentMonthTxs: txs, prevMonthTxs: prevTxs, cards: cards)
            
        } catch {
            print("Error fetching dashboard data: \(error)")
        }
    }
    
    private func calculateChartSegments(txs: [TransactionRecord], categories: [CategoryRecord]) {
        let filteredTxs = txs.filter { $0.type == reportType }
        
        // 1. Group and resolved category amounts
        var mappedStats: [LedgerCategory: Double] = [:]
        for cat in LedgerCategory.allCases { mappedStats[cat] = 0 }
        
        for tx in filteredTxs {
            let items = tx.transaction_line_items ?? []
            if items.isEmpty {
                mappedStats[.other, default: 0] += tx.amount
            } else {
                for item in items {
                    let cat = resolveLedgerCategory(for: item.category_id)
                    mappedStats[cat, default: 0] += item.amount
                }
            }
        }
        
        // 2. Create final stats list and calculate proportions
        let totalSum = mappedStats.values.reduce(0, +)
        let denominator = max(1.0, totalSum)
        
        var finalStats: [CategoryStat] = []
        for cat in LedgerCategory.allCases {
            let amt = mappedStats[cat] ?? 0
            finalStats.append(CategoryStat(
                category: cat,
                amount: amt,
                proportion: amt / denominator,
                change: nil
            ))
        }
        
        // 3. Sort and Update
        let sorted = finalStats.sorted { $0.amount > $1.amount }
        self.categoryStats = sorted
        self.chartSegments = sorted.filter { $0.amount > 0 }
            .map { ChartSegment(proportion: $0.proportion, color: $0.category.color) }
    }
    
    private func calculatePaymentMethodStats(currentMonthTxs: [TransactionRecord], prevMonthTxs: [TransactionRecord], cards: [CreditCardRecord]) {
        let calendar = Calendar.current
        var stats: [PaymentMethodStat] = []
        
        // 1. Cash (Natural Month)
        let cashTxs = currentMonthTxs.filter { $0.credit_card_id == nil && $0.type == "expense" }
        let cashTotal = cashTxs.reduce(0) { $0 + $1.amount }
        
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth + 1
        components.day = 1
        if let startDate = calendar.date(from: components),
           let endDate = calendar.date(byAdding: .month, value: 1, to: startDate)?.addingTimeInterval(-1) {
            let periodStr = "\(Self.shortDateFormatter.string(from: startDate)) - \(Self.shortDateFormatter.string(from: endDate))"
            stats.append(PaymentMethodStat(name: "現金", amount: cashTotal, type: "cash", billingDay: nil, period: periodStr))
        }
        
        // 2. Credit Cards (Billing Cycle)
        let allTxs = prevMonthTxs + currentMonthTxs // Covers roughly 60 days
        
        for card in cards {
            // Calculate Period: ends at card.billing_day of selected month
            // If billing day is 10, period is (selectedMonth-1)/11 to selectedMonth/10
            
            var endComponents = DateComponents()
            endComponents.year = selectedYear
            endComponents.month = selectedMonth + 1
            endComponents.day = card.billing_day
            
            if let cycleEndDate = calendar.date(from: endComponents) {
                if let cycleStartDate = calendar.date(byAdding: .month, value: -1, to: cycleEndDate)?.addingTimeInterval(86400) { // +1 day
                    
                    let cardTxs = allTxs.filter { tx in
                        guard tx.credit_card_id == card.id && tx.type == "expense" else { return false }
                        guard let txDateStr = tx.transaction_date else { return false }
                        
                        let txDate: Date?
                        if let d = Self.isoFormatter.date(from: txDateStr) { txDate = d }
                        else if let d = Self.isoFormatterNoFractional.date(from: txDateStr) { txDate = d }
                        else if let d = Self.simpleDateFormatter.date(from: String(txDateStr.prefix(10))) { txDate = d }
                        else { txDate = nil }
                        
                        guard let d = txDate else { return false }
                        // Use a small epsilon or compare components to be safe, but date comparison is usually fine
                        return d >= cycleStartDate && d <= cycleEndDate
                    }
                    
                    let cardTotal = cardTxs.reduce(0) { $0 + $1.amount }
                    let periodStr = "\(Self.shortDateFormatter.string(from: cycleStartDate)) - \(Self.shortDateFormatter.string(from: cycleEndDate))"
                    
                    stats.append(PaymentMethodStat(
                        name: card.card_name,
                        amount: cardTotal,
                        type: "credit_card",
                        billingDay: card.billing_day,
                        period: periodStr
                    ))
                }
            }
        }
        
        self.paymentMethodStats = stats
    }
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    func getCategoryIcon(for transaction: TransactionRecord) -> String {
        // Just use the first line item's category for simplicity
        if let catId = transaction.transaction_line_items?.first?.category_id,
           let cat = allCategories.first(where: { $0.id == catId }),
           let icon = cat.icon {
            return icon
        }
        return "ellipsis.circle.fill"
    }
    
    func getCategoryIconForId(_ categoryId: String?) -> String {
        guard let id = categoryId, !id.isEmpty else { return "ellipsis.circle.fill" }
        let normalizedId = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cat = allCategories.first(where: { $0.id?.lowercased() == normalizedId }), let icon = cat.icon {
            return icon
        }
        return "ellipsis.circle.fill"
    }
    
    func getCategoryColorForId(_ categoryId: String?) -> Color {
        guard let id = categoryId, !id.isEmpty else { return .gray }
        let normalizedId = id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let catRecord = allCategories.first(where: { $0.id?.lowercased() == normalizedId }) {
            let ledgerCat = LedgerCategory(rawValue: catRecord.name) ?? .other
            return ledgerCat.color
        }
        return .gray
    }
    
    func getTransactionTitle(for transaction: TransactionRecord) -> String {
        // 1. Try to get title from the first line item
        if let firstItem = transaction.transaction_line_items?.first, !firstItem.name.isEmpty {
            if (transaction.transaction_line_items?.count ?? 0) > 1 {
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
        return item.payer_name ?? ""
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
            var totalAmount: Double = 0
            
            for tx in transactions {
                guard tx.type == "expense" else { continue }
                let items = tx.transaction_line_items ?? []
                
                if items.isEmpty {
                    if selected == .other {
                        totalAmount += tx.amount
                    }
                } else {
                    for item in items {
                        if self.resolveLedgerCategory(for: item.category_id) == selected {
                            totalAmount += item.amount
                        }
                    }
                }
            }
            
            self.totalExpenditure = formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(Int(totalAmount))"
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
