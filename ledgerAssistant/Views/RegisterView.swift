import SwiftUI

enum EntrySource {
    case scan(UIImage)
    case voice(String)
}

struct UIItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var category_id: UUID?
    var selectedPayers: Set<UUID> // Set of payer IDs (FamilyMemberRecord.user_id or main userId)
}

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    let source: EntrySource
    @State private var items: [UIItem] = []
    @State private var isParsing = true
    @State private var categories: [CategoryRecord] = []
    @State private var familyMembers: [FamilyMemberRecord] = []
    @State private var creditCards: [CreditCardRecord] = []
    @State private var selectedPaymentMethod: String = "CASH" // "CASH" or card ID
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    
    private let userId = UUID(uuidString: "DE571E1C-681C-44A0-A823-45F4B82B3DD5")!
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                DotPattern()
                
                VStack(spacing: 0) {
                    if isParsing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.black)
                            Text("AI 解析中...")
                                .font(.system(size: 18, weight: .black))
                                .italic()
                        }
                        .frame(maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 16, weight: .bold))
                                .multilineTextAlignment(.center)
                            Button("重試") {
                                analyze()
                            }
                            .padding()
                            .background(MangaTheme.yellow)
                            .comicBorder(width: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 24) {
                                // Receipt Preview
                                switch source {
                                case .scan(let img):
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .comicBorder(width: 4)
                                        .padding(.top)
                                case .voice(let text):
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "quote.opening")
                                                .foregroundColor(.black)
                                            Text("語音內容")
                                                .font(.system(size: 14, weight: .black))
                                        }
                                        Text("\"\(text)\"")
                                            .font(.system(size: 18, weight: .bold))
                                            .italic()
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(MangaTheme.yellow.opacity(0.1))
                                            .comicBorder(width: 2, cornerRadius: 10)
                                    }
                                    .padding(.top)
                                }
                                
                                // Payment Method section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("支付方式")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundColor(.black)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            paymentButton(title: "現金", id: "CASH", icon: "banknote")
                                            ForEach(creditCards) { card in
                                                paymentButton(title: card.card_name, id: card.id?.uuidString ?? "", icon: "creditcard")
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .comicBorder(width: 2, cornerRadius: 12)
                                
                                // Items section
                                ForEach($items) { $item in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            TextField("品名", text: $item.name)
                                                .font(.system(size: 16, weight: .bold))
                                            Spacer()
                                            TextField("金額", value: $item.amount, format: .number)
                                                .font(.system(size: 18, weight: .black))
                                                .frame(width: 100)
                                                .multilineTextAlignment(.trailing)
                                        }
                                        
                                        HStack {
                                            Picker("類別", selection: $item.category_id) {
                                                Text("選擇類別").tag(nil as UUID?)
                                                ForEach(categories) { cat in
                                                    Text(cat.name).tag(cat.id as UUID?)
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .padding(.horizontal, 8)
                                            .background(Color.white)
                                            .comicBorder(width: 2, cornerRadius: 8)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                items.removeAll(where: { $0.id == item.id })
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                                    .padding(8)
                                                    .background(Color.white)
                                                    .comicBorder(width: 2, cornerRadius: 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        
                                        Divider()
                                        
                                        // Payer Selection
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("分攤對象")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.gray)
                                            
                                            FlowLayout(spacing: 8) {
                                                ForEach(familyMembers) { member in
                                                    payerChip(name: member.name, id: member.id ?? UUID(), isSelected: item.selectedPayers.contains(member.id ?? UUID())) {
                                                        togglePayer(for: $item, payerId: member.id ?? UUID())
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .comicBorder(width: 2, cornerRadius: 12)
                                    .comicShadow(offset: 2)
                                }
                                
                                Button(action: {
                                    items.append(UIItem(name: "", amount: 0, category_id: nil, selectedPayers: [userId]))
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.black)
                                        Text("新增品項")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .comicBorder(width: 2, cornerRadius: 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 120) // Give space for the bottom bar if any
                        }
                    }
                }
                
                if isSaving {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white)
                        Text("儲存中...")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .black))
                    }
                }
            }
            .navigationTitle("確認帳務")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .buttonStyle(PlainButtonStyle())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isParsing && errorMessage == nil {
                        Button("儲存") {
                            saveTransaction()
                        }
                        .disabled(isSaving)
                        .font(.system(size: 16, weight: .black))
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            analyze()
        }
    }
    
    // MARK: - Components
    
    private func paymentButton(title: String, id: String, icon: String) -> some View {
        let isSelected = selectedPaymentMethod == id
        return Button(action: { selectedPaymentMethod = id }) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? MangaTheme.yellow : Color.white)
            .foregroundColor(.black)
            .comicBorder(width: 2, cornerRadius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func payerChip(name: String, id: UUID, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color.white)
                .foregroundColor(isSelected ? .white : .black)
                .comicBorder(width: 2, cornerRadius: 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Logic
    
    private func togglePayer(for item: Binding<UIItem>, payerId: UUID) {
        if item.selectedPayers.wrappedValue.contains(payerId) {
            // Don't allow 0 payers
            if item.selectedPayers.wrappedValue.count > 1 {
                item.selectedPayers.wrappedValue.remove(payerId)
            }
        } else {
            item.selectedPayers.wrappedValue.insert(payerId)
        }
    }
    
    private func analyze() {
        isParsing = true
        errorMessage = nil
        
        Task {
            do {
                async let fetchedCats = SupabaseManager.shared.fetchCategories()
                async let fetchedFamily = SupabaseManager.shared.fetchFamily(userId: userId)
                async let fetchedCards = SupabaseManager.shared.fetchCards(userId: userId)
                
                let extracted: [ExtractedItem]
                switch source {
                case .scan(let img):
                    extracted = try await AIService.shared.analyzeReceipt(image: img)
                case .voice(let text):
                    extracted = try await AIService.shared.analyzeVoiceText(text: text)
                }
                
                let (cats, family, cards, itemsExt) = try await (fetchedCats, fetchedFamily, fetchedCards, extracted)
                
                await MainActor.run {
                    self.categories = cats
                    self.familyMembers = family
                    self.creditCards = cards
                    let defaultPayerId = family.first?.id
                    self.items = itemsExt.map { ext in
                        let catId = cats.first(where: { $0.name == ext.category })?.id
                        return UIItem(
                            name: ext.name,
                            amount: ext.amount,
                            category_id: catId,
                            selectedPayers: defaultPayerId != nil ? [defaultPayerId!] : []
                        )
                    }
                    self.isParsing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "解析失敗: \(error.localizedDescription)"
                    self.isParsing = false
                }
            }
        }
    }
    
    private func saveTransaction() {
        isSaving = true
        Task {
            do {
                // 1. Upload Image if available
                var url: String? = nil
                if case .scan(let img) = source {
                    url = try await SupabaseManager.shared.uploadReceiptImage(image: img, userId: userId, filename: UUID().uuidString)
                }
                
                // 2. Prepare Transaction Record
                let totalAmount = items.reduce(0) { $0 + $1.amount }
                var transaction = TransactionRecord(
                    user_id: userId,
                    type: "expense",
                    amount: totalAmount,
                    note: nil,
                    transaction_date: ISO8601DateFormatter().string(from: Date()),
                    receipt_url: url
                )
                
                if selectedPaymentMethod != "CASH" {
                    transaction.credit_card_id = UUID(uuidString: selectedPaymentMethod)
                }
                
                // 3. Prepare Split Line Items
                var dbLineItems: [TransactionLineItemRecord] = []
                for item in items {
                    let splitCount = Double(item.selectedPayers.count)
                    let splitAmount = item.amount / max(1, splitCount)
                    
                    for payerId in item.selectedPayers {
                        var lineItem = TransactionLineItemRecord(
                            transaction_id: UUID(), // Will be set by manager
                            user_id: userId,
                            name: "\(item.name)\(item.selectedPayers.count > 1 ? " (分)" : "")", 
                            amount: splitAmount,
                            quantity: 1,
                            category_id: item.category_id,
                            title: item.name
                        )
                        
                        // All selectable payers are now family members
                        lineItem.family_member_id = payerId
                        
                        dbLineItems.append(lineItem)
                    }
                }
                
                // 4. Save to database
                try await SupabaseManager.shared.createTransaction(transaction: transaction, lineItems: dbLineItems)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    self.errorMessage = "儲存失敗: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Simple FlowLayout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.points[index].x, y: bounds.minY + result.points[index].y), proposal: .unspecified)
        }
    }
    
    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var points: [CGPoint] = []
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), points)
    }
}
