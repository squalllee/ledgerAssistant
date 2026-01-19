import SwiftUI

enum EntrySource {
    case scan(UIImage)
    case voice(String)
}

struct UIItem: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var category_id: String?
    var selectedPayers: Set<UUID> 
}

struct UISourceGroup: Identifiable {
    let id = UUID()
    var items: [UIItem]
    var image: UIImage?   // For photo groups
    var voiceText: String? // For voice groups
}

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    let source: EntrySource
    @State private var sourceGroups: [UISourceGroup] = []
    @State private var isParsing = true
    @State private var categories: [CategoryRecord] = []
    @State private var familyMembers: [FamilyMemberRecord] = []
    @State private var creditCards: [CreditCardRecord] = []
    @State private var selectedPaymentMethod: String = "CASH" // "CASH" or card ID
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @State private var transactionType: String = "expense" // "expense" or "income"
    
    // New Additive State
    @StateObject private var speechManager = SpeechManager()
    @State private var showingAddVoiceOverlay = false
    @State private var showingAddScanOptions = false
    @State private var showingAddScanner = false
    @State private var addScannerSource: UIImagePickerController.SourceType = .camera
    @State private var isAppending = false
    
    private var userId: UUID {
        return SupabaseManager.shared.currentUserId ?? UUID()
    }
    
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
                                // Transaction Type Picker
                                HStack(spacing: 0) {
                                    Button(action: { transactionType = "expense" }) {
                                        Text("支出")
                                            .font(.system(size: 16, weight: .black))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(transactionType == "expense" ? Color.black : Color.white)
                                            .foregroundColor(transactionType == "expense" ? .white : .black)
                                    }
                                    
                                    Button(action: { transactionType = "income" }) {
                                        Text("收入")
                                            .font(.system(size: 16, weight: .black))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(transactionType == "income" ? MangaTheme.yellow : Color.white)
                                            .foregroundColor(.black)
                                    }
                                }
                                .comicBorder(width: 3, cornerRadius: 15)
                                .padding(.top)

                                // Payment Method Section
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "creditcard.circle.fill")
                                            .foregroundColor(.black)
                                        Text("付款方式")
                                            .font(.system(size: 16, weight: .black))
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            paymentButton(title: "現金", id: "CASH", icon: "banknote")
                                            
                                            ForEach(creditCards) { card in
                                                paymentButton(title: card.card_name, id: card.id?.uuidString ?? "", icon: "creditcard")
                                            }
                                        }
                                        .padding(.horizontal, 2)
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.vertical, 8)

                                // Groups Section
                                ForEach($sourceGroups) { $group in
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Group Header (Source Preview)
                                        if let img = group.image {
                                            Image(uiImage: img)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 120)
                                                .comicBorder(width: 2, cornerRadius: 8)
                                        } else if let text = group.voiceText {
                                            HStack {
                                                Image(systemName: "quote.opening")
                                                Text("\"\(text)\"")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .italic()
                                            }
                                            .padding(10)
                                            .background(MangaTheme.yellow.opacity(0.1))
                                            .comicBorder(width: 1, cornerRadius: 8)
                                        } else {
                                            Text("手動/初始品項")
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundColor(.gray)
                                        }

                                        // Items in this group
                                        ForEach($group.items) { $item in
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
                                                        Text("選擇類別").tag(nil as String?)
                                                        ForEach(categories) { cat in
                                                            Text(cat.name).tag(cat.id as String?)
                                                        }
                                                    }
                                                    .pickerStyle(MenuPickerStyle())
                                                    .padding(.horizontal, 8)
                                                    .background(Color.white)
                                                    .comicBorder(width: 2, cornerRadius: 8)
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        group.items.removeAll(where: { $0.id == item.id })
                                                        // If group empty, maybe remove group? 
                                                        // Let's keep it for now unless user deletes manually
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
                                        }
                                    }
                                    .padding(.bottom, 10)
                                }
                                
                                // Additive Items section
                                if !isParsing {
                                    VStack(spacing: 16) {
                                        HStack(spacing: 12) {
                                            Button(action: { 
                                                startAddVoice()
                                            }) {
                                                HStack {
                                                    Image(systemName: "mic.fill")
                                                    Text("語音增加")
                                                }
                                                .font(.system(size: 14, weight: .bold))
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(MangaTheme.yellow)
                                                .comicBorder(width: 2, cornerRadius: 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Button(action: { 
                                                showingAddScanOptions = true
                                            }) {
                                                HStack {
                                                    Image(systemName: "viewfinder")
                                                    Text("照片增加")
                                                }
                                                .font(.system(size: 14, weight: .bold))
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(Color.black)
                                                .foregroundColor(.white)
                                                .comicBorder(width: 2, cornerRadius: 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        
                                        Button(action: {
                                            let defaultId = familyMembers.first(where: { $0.is_default == true })?.id ?? familyMembers.first?.id
                                            let newItem = UIItem(name: "", amount: 0, category_id: nil, selectedPayers: defaultId != nil ? [defaultId!] : [])
                                            
                                            // Add to a "Manual" group or the first group
                                            if let idx = sourceGroups.firstIndex(where: { $0.image == nil && $0.voiceText == nil }) {
                                                sourceGroups[idx].items.append(newItem)
                                            } else {
                                                sourceGroups.insert(UISourceGroup(items: [newItem], image: nil, voiceText: nil), at: 0)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(.gray)
                                                Text("手動新增")
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 120)
                        }
                    }
                }
                
                if isSaving || isAppending {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white)
                        Text(isSaving ? "儲存中..." : "AI 解析中...")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .black))
                    }
                }
                
                if showingAddVoiceOverlay {
                    addVoiceOverlay
                }
            }
            .navigationTitle("確認帳務")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddScanner) {
                ImagePicker(sourceType: addScannerSource) { image in
                    if let img = image {
                        appendPhoto(img)
                    }
                }
            }
            .confirmationDialog("增加收據照片", isPresented: $showingAddScanOptions, titleVisibility: .visible) {
                Button("相機") {
                    addScannerSource = .camera
                    showingAddScanner = true
                }
                Button("相簿") {
                    addScannerSource = .photoLibrary
                    showingAddScanner = true
                }
                Button("取消", role: .cancel) {}
            }
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
                    let defaultPayerId = family.first(where: { $0.is_default == true })?.id ?? family.first?.id
                    
                    let groupItems = itemsExt.map { ext in
                        let catId = cats.first(where: { $0.name == ext.category })?.id
                        return UIItem(
                            name: ext.name,
                            amount: ext.amount,
                            category_id: catId,
                            selectedPayers: defaultPayerId != nil ? [defaultPayerId!] : []
                        )
                    }
                    
                    let initialGroup: UISourceGroup
                    switch source {
                    case .scan(let img):
                        initialGroup = UISourceGroup(items: groupItems, image: img, voiceText: nil)
                    case .voice(let text):
                        initialGroup = UISourceGroup(items: groupItems, image: nil, voiceText: text)
                    }
                    
                    self.sourceGroups = [initialGroup]
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
                for group in sourceGroups {
                    guard !group.items.isEmpty else { continue }
                    
                    // 1. Upload Image if available for THIS group
                    var url: String? = nil
                    if let img = group.image {
                        url = try await SupabaseManager.shared.uploadReceiptImage(image: img, userId: userId, filename: "\(group.id.uuidString).jpg")
                    }
                    
                    // 2. Prepare Transaction Record for THIS group
                    let totalAmount = group.items.reduce(0) { $0 + $1.amount }
                    var transaction = TransactionRecord(
                        user_id: userId,
                        type: transactionType,
                        amount: totalAmount,
                        note: group.voiceText, // Use voice text as note if available
                        transaction_date: ISO8601DateFormatter().string(from: Date()),
                        receipt_url: url
                    )
                    
                    if selectedPaymentMethod != "CASH" {
                        transaction.credit_card_id = UUID(uuidString: selectedPaymentMethod)
                    }
                    
                    // 3. Prepare Split Line Items for THIS group
                    var dbLineItems: [TransactionLineItemRecord] = []
                    for item in group.items {
                        let splitCount = Double(item.selectedPayers.count)
                        let splitAmount = item.amount / max(1, splitCount)
                        
                        for payerId in item.selectedPayers {
                            let memberName = familyMembers.first(where: { $0.id == payerId })?.name
                            let lineItem = TransactionLineItemRecord(
                                transaction_id: UUID(), // Will be set by manager
                                user_id: userId,
                                payer_name: memberName,
                                name: "\(item.name)\(item.selectedPayers.count > 1 ? " (分)" : "")", 
                                amount: splitAmount,
                                quantity: 1,
                                category_id: item.category_id,
                                title: item.name
                            )
                            dbLineItems.append(lineItem)
                        }
                    }
                    
                    // 4. Save THIS group as a separate transaction
                    try await SupabaseManager.shared.createTransaction(transaction: transaction, lineItems: dbLineItems)
                }
                
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
    
    // MARK: - Additive Logic
    
    private func startAddVoice() {
        speechManager.requestPermissions { granted in
            if granted {
                showingAddVoiceOverlay = true
                do {
                    try speechManager.startRecording()
                } catch {
                    speechManager.error = "啟動失敗: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func finishAddVoice() {
        let text = speechManager.transcribedText
        speechManager.stopRecording()
        showingAddVoiceOverlay = false
        
        if !text.isEmpty {
            isAppending = true
            Task {
                do {
                    let extracted = try await AIService.shared.analyzeVoiceText(text: text)
                    await MainActor.run {
                        let newItems = appendExtracted(extracted)
                        let newGroup = UISourceGroup(items: newItems, image: nil, voiceText: text)
                        self.sourceGroups.append(newGroup)
                        isAppending = false
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "增加失敗: \(error.localizedDescription)"
                        isAppending = false
                    }
                }
            }
        }
    }
    
    private func appendPhoto(_ image: UIImage) {
        isAppending = true
        Task {
            do {
                let extracted = try await AIService.shared.analyzeReceipt(image: image)
                    await MainActor.run {
                        let newItems = appendExtracted(extracted)
                        let newGroup = UISourceGroup(items: newItems, image: image, voiceText: nil)
                        self.sourceGroups.append(newGroup)
                        isAppending = false
                    }
            } catch {
                await MainActor.run {
                    errorMessage = "圖片解析失敗: \(error.localizedDescription)"
                    isAppending = false
                }
            }
        }
    }
    
    private func appendExtracted(_ extracted: [ExtractedItem]) -> [UIItem] {
        let defaultPayerId = familyMembers.first(where: { $0.is_default == true })?.id ?? familyMembers.first?.id
        return extracted.map { ext in
            let catId = categories.first(where: { $0.name == ext.category })?.id
            return UIItem(
                name: ext.name,
                amount: ext.amount,
                category_id: catId,
                selectedPayers: defaultPayerId != nil ? [defaultPayerId!] : []
            )
        }
    }
    
    private var addVoiceOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("正在聽您說話...")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(MangaTheme.yellow)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .scaleEffect(speechManager.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: speechManager.isRecording)
                
                Text(speechManager.transcribedText.isEmpty ? "請說出品項與金額..." : speechManager.transcribedText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: finishAddVoice) {
                    Text("增加")
                        .font(.system(size: 18, weight: .black))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(MangaTheme.yellow)
                        .foregroundColor(.black)
                        .comicBorder(width: 3, cornerRadius: 25)
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
