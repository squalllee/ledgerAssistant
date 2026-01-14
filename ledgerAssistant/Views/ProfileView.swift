import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "f0f0f0").ignoresSafeArea()
                DotPattern().opacity(0.1)
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("設定頁面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarAction
                }
            }
            .alert("發生錯誤", isPresented: $viewModel.showError) {
                Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
            } message: {
                Text(viewModel.errorMessage ?? "未知錯誤")
            }
            .preferredColorScheme(.light)
            .onAppear {
                viewModel.loadData()
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("讀取中...")
                .font(.system(size: 14, weight: .bold))
                .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                accountSection
                cardSection
                familySection
                limitSection
            }
            .padding(24)
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        ProfileSection(title: "帳號資訊") {
            VStack(spacing: 12) {
                MangaTextField(label: "姓名", text: $viewModel.name)
                DatePicker("生日", selection: $viewModel.birthday, displayedComponents: .date)
                    .font(.system(size: 14, weight: .bold))
                    .padding(8)
                    .background(Color.white)
                    .comicBorder(width: 2)
                MangaTextField(label: "電話", text: $viewModel.phone)
            }
        }
    }
    
    @ViewBuilder
    private var cardSection: some View {
        ProfileSection(title: "信用卡設定") {
            VStack(spacing: 12) {
                ForEach(viewModel.cards) { card in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(card.card_name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                            Text("出帳日: \(card.billing_day)")
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Button(action: {
                            if let id = card.id { viewModel.removeCard(id: id) }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(8)
                    .background(MangaTheme.yellow.opacity(0.3))
                    .comicBorder(width: 2)
                }
                
                HStack {
                    TextField("卡名", text: $viewModel.newCardName)
                    TextField("日", value: $viewModel.newCardDay, format: .number)
                        .frame(width: 40)
                    Button("新增") {
                        viewModel.addNewCard()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.system(size: 12, weight: .black))
                    .padding(8)
                    .background(MangaTheme.yellow)
                    .comicBorder(width: 2)
                }
            }
        }
    }
    
    @ViewBuilder
    private var familySection: some View {
        ProfileSection(title: "家庭成員") {
            VStack(spacing: 12) {
                ForEach(viewModel.family) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.name)
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .bold))
                            if member.is_default == true {
                                Text("預設記帳人")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(MangaTheme.pink)
                            }
                        }
                        Spacer()
                        
                        Button(action: {
                            if let id = member.id { viewModel.toggleDefaultMember(id: id) }
                        }) {
                            Image(systemName: (member.is_default ?? false) ? "star.fill" : "star")
                                .foregroundColor((member.is_default ?? false) ? .orange : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 8)
                        
                        Button(action: {
                            if let id = member.id { viewModel.removeFamilyMember(id: id) }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.white)
                    .comicBorder(width: 2)
                }
                
                HStack {
                    TextField("姓名", text: $viewModel.newFamilyName)
                    Button("新增") {
                        viewModel.addNewFamilyMember()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.system(size: 12, weight: .black))
                    .padding(8)
                    .background(MangaTheme.yellow)
                    .comicBorder(width: 2)
                }
            }
        }
    }
    
    @ViewBuilder
    private var limitSection: some View {
        ProfileSection(title: "支出上限") {
            VStack {
                Text("每月預算: $\(Int(viewModel.monthlyLimit))")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.black)
                Slider(value: $viewModel.monthlyLimit, in: 0...100000, step: 1000)
                    .tint(MangaTheme.black)
            }
        }
        .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private var toolbarAction: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            Button("完成") { 
                viewModel.saveProfile {
                    dismiss()
                }
            }
            .font(.system(size: 14, weight: .black))
            .buttonStyle(PlainButtonStyle())
        }
    }
}
