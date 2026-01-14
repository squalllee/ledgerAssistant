import SwiftUI

// MARK: - Main View

struct MangaStyleDashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "f0f0f0").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: -2) {
                            Text("早安!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                            Text(viewModel.userName.isEmpty ? "使用者" : viewModel.userName.uppercased())
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                                .italic()
                        }
                    }
                    
                    Spacer()
                    
                    ZStack(alignment: .topTrailing) {
                        Button(action: {}) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                                .frame(width: 48, height: 48)
                                .background(Color.white)
                                .comicBorder(width: 4, cornerRadius: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .comicBorder(width: 2, cornerRadius: 8)
                            .offset(x: 4, y: -4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color.white)
                .border(width: 4, edges: [.bottom], color: .black)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        VStack(spacing: 0) {
                            // Year Selector
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.years, id: \.self) { year in
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                viewModel.selectedYear = year
                                            }
                                        }) {
                                            Text("\(String(year))年")
                                                .font(.system(size: 16, weight: .black))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                                .background(viewModel.selectedYear == year ? Color.black : Color.white)
                                                .foregroundColor(viewModel.selectedYear == year ? .white : .black)
                                                .comicBorder(width: 2, cornerRadius: 4)
                                                .comicShadow(offset: viewModel.selectedYear == year ? 2 : 0)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.vertical, 8)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            // Month Selector
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<12, id: \.self) { index in
                                        Button(action: {
                                            withAnimation(.spring()) {
                                                viewModel.selectedMonth = index
                                            }
                                        }) {
                                            Text("\(viewModel.months[index])支出")
                                                .font(.system(size: 18, weight: .black))
                                                .tracking(viewModel.selectedMonth == index ? 4 : 1)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                                .background(viewModel.selectedMonth == index ? Color.black : Color.white)
                                                .foregroundColor(viewModel.selectedMonth == index ? .white : .black)
                                                .rotationEffect(.degrees(viewModel.selectedMonth == index ? -10 : 0))
                                                .comicBorder(width: 2, cornerRadius: 4)
                                                .comicShadow(offset: viewModel.selectedMonth == index ? 2 : 0)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.vertical, 10)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            DonutChart(amount: viewModel.totalExpenditure, segments: viewModel.chartSegments, changeLabel: viewModel.expenditureChange)
                                .padding(.top, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(LedgerCategory.allCases) { category in
                                        categoryLegend(category: category)
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.top, 10)
                        }
                        .padding(.vertical, 20)
                        
                        // Balance Cards
                        VStack(spacing: 16) {
                            // Total Balance
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("總餘額")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.bottom, 2)
                                        .border(width: 2, edges: [.bottom], color: .black)
                                    Spacer()
                                    Image(systemName: "creditcard.fill")
                                        .padding(4)
                                        .background(Color.white)
                                        .comicBorder(width: 2, cornerRadius: 20)
                                }
                                
                                Text(viewModel.totalBalance)
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundColor(.black)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                    Text("+2.5%")
                                }
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black)
                                .foregroundColor(.white)
                            }
                            .padding(20)
                            .background(MangaTheme.yellow)
                            .comicBorder(width: 4, cornerRadius: 12)
                            .comicShadow(offset: 6)
                            
                            HStack(spacing: 16) {
                                balanceMiniCard(title: "本月收入", amount: viewModel.monthlyIncome, icon: "arrow.down")
                                balanceMiniCard(title: "本月支出", amount: viewModel.monthlyExpense, icon: "arrow.up")
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("近期交易")
                                    .font(.system(size: 18, weight: .black))
                                    .padding(.horizontal, 8)
                                    .background(MangaTheme.yellow)
                                    .comicBorder(width: 2)
                                    .rotationEffect(.degrees(-6))
                                
                                Spacer()
                                
//                                Button(action: {
//                                    viewModel.startVoiceRecording()
//                                }) {
//                                    VStack(spacing: 4) {
//                                        Image(systemName: "mic.fill")
//                                            .font(.system(size: 20))
//                                        Text("語音")
//                                            .font(.system(size: 10, weight: .bold))
//                                    }
//                                    .foregroundColor(.black)
//                                    .frame(width: 60, height: 60)
//                                    .background(Color.white)
//                                    .comicBorder(width: 2, cornerRadius: 30)
//                                    .comicShadow(offset: 2)
//                                }
//                                .buttonStyle(PlainButtonStyle())
//                                
//                                Button("查看全部") {}
//                                    .font(.system(size: 14, weight: .bold))
//                                    .underline()
//                                    .foregroundColor(.black)
//                                    .buttonStyle(PlainButtonStyle())
                            }
                            
                            VStack(spacing: 24) {
                                ForEach(viewModel.groupedTransactions) { group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        // Transaction Group Header (Date & ID reference)
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Text(group.date)
                                                        .font(.system(size: 14, weight: .black))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.black)
                                                        .foregroundColor(.white)
                                                        .comicBorder(width: 2)
                                                    
                                                    // Payment Method Label
                                                    if let tx = group.originalTransaction {
                                                        Text(viewModel.getPaymentMethodName(for: tx))
                                                            .font(.system(size: 10, weight: .black))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(MangaTheme.yellow)
                                                            .comicBorder(width: 2, cornerRadius: 4)
                                                    }
                                                }
                                                
                                                Text("ID: \(group.id.uuidString.prefix(8))...")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.gray)
                                                    .padding(.leading, 4)
                                            }
                                            
                                            Spacer()
                                            
                                            // Receipt Thumbnail if available
                                            if let receiptUrl = group.receiptUrl, !receiptUrl.isEmpty {
                                                Button(action: {
                                                    viewModel.selectedImageUrl = receiptUrl
                                                }) {
                                                    ZStack {
                                                        AsyncImage(url: URL(string: receiptUrl)) { image in
                                                            image.resizable().aspectRatio(contentMode: .fill)
                                                        } placeholder: {
                                                            Color.gray.opacity(0.1)
                                                        }
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                        .comicBorder(width: 2, cornerRadius: 6)
                                                        
                                                        Image(systemName: "magnifyingglass")
                                                            .font(.system(size: 12, weight: .black))
                                                            .foregroundColor(.white)
                                                            .padding(4)
                                                            .background(Color.black.opacity(0.6))
                                                            .clipShape(Circle())
                                                    }
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            
                                            Text("小計: $\(Int(group.subtotal))")
                                                .font(.system(size: 14, weight: .black))
                                                .foregroundColor(.black)
                                                .italic()
                                        }
                                        .padding(.horizontal, 4)
                                        
                                        // Line Items in this transaction
                                        VStack(spacing: 12) {
                                            ForEach(group.lineItems) { item in
                                                let payerName = viewModel.getPayerName(for: item)
                                                TransactionItem(
                                                    icon: viewModel.getCategoryIconForId(item.category_id),
                                                    title: item.name + (payerName.isEmpty ? "" : " (\(payerName))"),
                                                    subtitle: "", // No redundant date needed inside group
                                                    amount: "-$\(Int(item.amount))"
                                                )
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .comicBorder(width: 2, cornerRadius: 12)
                                    .comicShadow(offset: 4)
                                }
                                
                                if viewModel.groupedTransactions.isEmpty {
                                    Text("本月查無交易資料")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
                .background(
                    ZStack {
                        Color.white
                        DotPattern()
                    }
                )
                .refreshable {
                    await viewModel.fetchDashboardData()
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchDashboardData()
                }
            }
            .fullScreenCover(item: Binding(
                get: { viewModel.selectedImageUrl.map { SelectedImage(url: $0) } },
                set: { viewModel.selectedImageUrl = $0?.url }
            )) { selection in
                ReceiptZoomView(imageUrl: selection.url)
            }
            
            // Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    tabButton(icon: "house.fill")
                    tabButton(icon: "chart.pie.fill")
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            viewModel.startVoiceRecording()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                Text("語音")
                                    .font(.system(size: 12, weight: .black))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 48)
                            .background(MangaTheme.yellow)
                            .comicBorder(width: 3, cornerRadius: 8)
                            .comicShadow(offset: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            viewModel.showingScanOptions = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "viewfinder")
                                Text("掃描")
                                    .font(.system(size: 12, weight: .black))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 48)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .comicBorder(width: 3, cornerRadius: 8)
                            .comicShadow(offset: 2, color: .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .confirmationDialog("選擇收據來源", isPresented: $viewModel.showingScanOptions, titleVisibility: .visible) {
                            Button("相機") {
                                viewModel.scannerSource = .camera
                                viewModel.showingScanner = true
                            }
                            Button("相簿") {
                                viewModel.scannerSource = .photoLibrary
                                viewModel.showingScanner = true
                            }
                            Button("取消", role: .cancel) {}
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    tabButton(icon: "person.fill") {
                        viewModel.showingProfile = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .comicBorder(width: 4, cornerRadius: 25)
                .comicShadow(offset: 6)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.light)
        .edgesIgnoringSafeArea(.bottom)
        .overlay {
            if viewModel.showingVoiceOverlay {
                voiceRecordingOverlay
            }
        }
        .sheet(isPresented: $viewModel.showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $viewModel.showingScanner) {
            ImagePicker(sourceType: viewModel.scannerSource) { image in
                if let img = image {
                    viewModel.selectedImage = img
                    viewModel.showingRegister = true
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingRegister, onDismiss: {
            viewModel.selectedImage = nil
            viewModel.voiceSource = nil
            Task {
                await viewModel.fetchDashboardData()
            }
        }) {
            if let img = viewModel.selectedImage {
                RegisterView(source: .scan(img))
            } else if case .voice(let text) = viewModel.voiceSource {
                RegisterView(source: .voice(text))
            }
        }
    }
    
    private var voiceRecordingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("正在聽您說話...")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(MangaTheme.yellow)
                    .italic()
                
                // Pulsing Animation Circle
                Button(action: {
                    if !viewModel.speechManager.isRecording {
                        viewModel.startVoiceRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(MangaTheme.yellow, lineWidth: 4)
                            .frame(width: 100, height: 100)
                            .scaleEffect(viewModel.speechManager.isRecording ? 1.2 : 1.0)
                            .opacity(viewModel.speechManager.isRecording ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.speechManager.isRecording)
                        
                        Image(systemName: viewModel.speechManager.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let error = viewModel.speechManager.error {
                    Text(error)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white)
                        .comicBorder(width: 2, cornerRadius: 10)
                } else {
                    Text(viewModel.speechManager.transcribedText.isEmpty ? "請說出品項與金額..." : viewModel.speechManager.transcribedText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: 300)
                        .background(Color.black)
                        .comicBorder(width: 2, cornerRadius: 10, color: .white)
                }
                
                Button(action: {
                    viewModel.stopVoiceRecording()
                }) {
                    Text("完成")
                        .font(.system(size: 18, weight: .black))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(MangaTheme.yellow)
                        .foregroundColor(.black)
                        .comicBorder(width: 3, cornerRadius: 25)
                        .comicShadow(offset: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func categoryLegend(category: LedgerCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category
        
        return Button(action: {
            withAnimation(.spring()) {
                viewModel.selectCategory(category)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? MangaTheme.yellow : Color.white)
            .foregroundColor(.black)
            .comicBorder(width: 2, cornerRadius: 8)
//            .comicShadow(offset: isSelected ? 4 : 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func balanceMiniCard(title: String, amount: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .padding(4)
                    .background(icon == "arrow.down" ? Color.black : Color.white)
                    .foregroundColor(icon == "arrow.down" ? .white : .black)
                    .comicBorder(width: 2, cornerRadius: 20)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
            }
            Text(amount)
                .font(.system(size: 18, weight: .black))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 4, cornerRadius: 12)
//        .comicShadow(offset: 4)
   
    }
    
    private func tabButton(icon: String, action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1))
                .comicBorder(width: 2, cornerRadius: 24)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    MangaStyleDashboardView()
}

