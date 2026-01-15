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
                            Text(viewModel.greeting)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                            Text(viewModel.userName.isEmpty ? "使用者" : viewModel.userName.uppercased())
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                                .italic()
                        }
                    }
                    
                    Spacer()
                    
                    // Weather UI
                    Button(action: {
                        viewModel.refreshWeather()
                    }) {
                        HStack(spacing: 8) {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(viewModel.currentTime)
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.black)
                                
                                Text(viewModel.temperature)
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(.black)
                            }
                            
                            Image(systemName: viewModel.weatherIcon)
                                .font(.system(size: 24))
                                .foregroundColor(MangaTheme.yellow)
                                .comicBorder(width: 2, cornerRadius: 8)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .comicBorder(width: 2, cornerRadius: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
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
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.vertical, 8)
                                    }
                                }
                                .padding(.horizontal, 12)
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
                                            Text("\(viewModel.months[index])")
                                                .font(.system(size: 18, weight: .black))
                                                .tracking(viewModel.selectedMonth == index ? 4 : 1)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 4)
                                                .background(viewModel.selectedMonth == index ? Color.black : Color.white)
                                                .foregroundColor(viewModel.selectedMonth == index ? .white : .black)
                                                .rotationEffect(.degrees(viewModel.selectedMonth == index ? -10 : 0))
                                                .comicBorder(width: 2, cornerRadius: 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.vertical, 10)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                            
                            DonutChart(amount: viewModel.totalExpenditure, segments: viewModel.chartSegments, changeLabel: viewModel.expenditureChange)
                                .padding(.top, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(LedgerCategory.allCases) { category in
                                        categoryLegend(category: category)
                                    }
                                }
                                .padding(.horizontal, 12)
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
                                        .foregroundColor(.black)
                                        .padding(4)
                                        .background(Color.clear)
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
                            
                            HStack(spacing: 16) {
                                balanceMiniCard(title: "本月收入", amount: viewModel.monthlyIncome, icon: "dollarsign.circle")
                                balanceMiniCard(title: "本月支出", amount: viewModel.monthlyExpense, icon: "cart")
                            }
                        }
                        .padding(.horizontal, 12)
                        
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
                            
                            }
                            
                            VStack(spacing: 24) {
                                if viewModel.timelineGroups.isEmpty {
                                    Text("本月查無交易資料")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding()
                                } else {
                                    MangaTimelineView(
                                        dateGroups: viewModel.timelineGroups,
                                        onReceiptTap: { url in
                                            viewModel.selectedImageUrl = url
                                        }
                                    )
                                    .padding(12)
                                    .background(Color.white)
                                    .comicBorder(width: 3, cornerRadius: 20)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 120)
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
                    tabButton(icon: "chart.pie.fill") {
                        viewModel.showingReports = true
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.startVoiceRecording()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                Text("語音")
                                    .font(.system(size: 14, weight: .black))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(MangaTheme.yellow)
                            .comicBorder(width: 3, cornerRadius: 15)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            viewModel.showingScanOptions = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "viewfinder")
                                Text("掃描")
                                    .font(.system(size: 14, weight: .black))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .comicBorder(width: 3, cornerRadius: 15)
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
                    
                    tabButton(icon: "gearshape.fill") {
                        viewModel.showingProfile = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.9))
                        DotPattern(opacity: 0.1, spacing: 4)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                )
                .comicBorder(width: 3, cornerRadius: 30)
                .padding(.horizontal, 12)
                .padding(.bottom, 34) // Adjust for home indicator
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
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
        .fullScreenCover(isPresented: $viewModel.showingReports) {
            ReportsView(viewModel: viewModel)
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
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func balanceMiniCard(title: String, amount: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.black)
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
