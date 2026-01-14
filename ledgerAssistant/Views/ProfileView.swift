import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "f0f0f0").ignoresSafeArea()
                DotPattern().opacity(0.1)
                
                VStack(spacing: 24) {
                    ScrollView {
                        VStack(spacing: 16) {
                            SettingMenuLink(title: "帳號設定", icon: "person.crop.circle.fill", color: .blue) {
                                AccountSettingsView(viewModel: viewModel)
                            }
                            
                            SettingMenuLink(title: "信用卡設定", icon: "creditcard.fill", color: .orange) {
                                CreditCardSettingsView(viewModel: viewModel)
                            }
                            
                            SettingMenuLink(title: "家庭成員設定", icon: "person.2.fill", color: .green) {
                                FamilySettingsView(viewModel: viewModel)
                            }
                            
                            SettingMenuLink(title: "支出上限設定", icon: "gauge.with.needle", color: .red) {
                                BudgetSettingsView(viewModel: viewModel)
                            }
                        }
                        .padding(24)
                    }
                    
                    Spacer()
                    
                    // Version Info
                    VStack(spacing: 4) {
                        Text("Ledger Assistant")
                            .font(.system(size: 12, weight: .black))
                        Text("Version 1.2.0 (Build 20260114)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") { dismiss() }
                        .font(.system(size: 14, weight: .black))
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .onAppear {
                viewModel.loadData()
            }
        }
    }
}

// MARK: - Menu Component
struct SettingMenuLink<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.1))
                    .comicBorder(width: 2, cornerRadius: 10)
                
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .comicBorder(width: 3, cornerRadius: 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sub Views

struct AccountSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "f0f0f0").ignoresSafeArea()
            DotPattern().opacity(0.1)
            
            ScrollView {
                VStack(spacing: 24) {
                    ProfileSection(title: "個人資訊") {
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
                    
                    Button(action: {
                        viewModel.saveProfile { }
                    }) {
                        Text("儲存修改")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .comicBorder(width: 3, cornerRadius: 15)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(24)
            }
        }
        .navigationTitle("帳號設定")
        .alert("發生錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.successMessage ?? "儲存成功")
        }
    }
}

struct CreditCardSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showingAddForm = false
    
    var body: some View {
        ZStack {
            Color(hex: "f0f0f0").ignoresSafeArea()
            DotPattern().opacity(0.1)
            
            VStack(spacing: 0) {
                List {
                    ForEach(viewModel.cards) { card in
                        EditableCardRow(card: card, onUpdate: { updatedCard in
                            viewModel.updateCard(card: updatedCard)
                        })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let id = viewModel.cards[index].id {
                                viewModel.removeCard(id: id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
                if showingAddForm {
                    VStack(spacing: 12) {
                        HStack {
                            Text("新增信用卡")
                                .font(.system(size: 16, weight: .black))
                                .italic()
                            Spacer()
                            Button(action: { showingAddForm = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        HStack(spacing: 12) {
                            MangaTextField(label: "名稱", text: $viewModel.newCardName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("結帳日")
                                    .font(.system(size: 10, weight: .bold))
                                TextField("1-31", value: $viewModel.newCardDay, format: .number)
                                    .font(.system(size: 14, weight: .bold))
                                    .keyboardType(.numberPad)
                                    .padding(10)
                                    .background(Color.white)
                                    .comicBorder(width: 2, cornerRadius: 8)
                                    .frame(width: 70)
                            }
                        }
                        
                        Button(action: {
                            viewModel.addNewCard()
                            showingAddForm = false
                        }) {
                            Text("增加這張卡片 !")
                                .font(.system(size: 14, weight: .black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MangaTheme.yellow)
                                .comicBorder(width: 2, cornerRadius: 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(16)
                    .background(Color.white)
                    .comicBorder(width: 4, cornerRadius: 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("信用卡設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.spring()) {
                        showingAddForm.toggle()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert("發生錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.successMessage ?? "儲存成功")
        }
    }
}

struct FamilySettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var showingAddForm = false
    
    var body: some View {
        ZStack {
            Color(hex: "f0f0f0").ignoresSafeArea()
            DotPattern().opacity(0.1)
            
            VStack(spacing: 0) {
                List {
                    ForEach(viewModel.family) { member in
                        EditableFamilyRow(member: member, onUpdate: { updated in
                            viewModel.updateFamilyMember(member: updated)
                        }, onToggleDefault: {
                            if let id = member.id { viewModel.toggleDefaultMember(id: id) }
                        })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let id = viewModel.family[index].id {
                                viewModel.removeFamilyMember(id: id)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                
                if showingAddForm {
                    VStack(spacing: 12) {
                        HStack {
                            Text("新增成員")
                                .font(.system(size: 16, weight: .black))
                                .italic()
                            Spacer()
                            Button(action: { showingAddForm = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        MangaTextField(label: "成員姓名", text: $viewModel.newFamilyName)
                        
                        Button(action: {
                            viewModel.addNewFamilyMember()
                            showingAddForm = false
                        }) {
                            Text("加入家庭 !")
                                .font(.system(size: 14, weight: .black))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(MangaTheme.yellow)
                                .comicBorder(width: 2, cornerRadius: 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(16)
                    .background(Color.white)
                    .comicBorder(width: 4, cornerRadius: 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("家庭成員設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.spring()) {
                        showingAddForm.toggle()
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .alert("發生錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.successMessage ?? "儲存成功")
        }
    }
}

struct BudgetSettingsView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        ZStack {
            Color(hex: "f0f0f0").ignoresSafeArea()
            DotPattern().opacity(0.1)
            
            VStack(spacing: 24) {
                ProfileSection(title: "每月預算") {
                    VStack(spacing: 20) {
                        Text("$\(Int(viewModel.monthlyLimit))")
                            .font(.system(size: 32, weight: .black))
                            .foregroundColor(.black)
                            .italic()
                        
                        Slider(value: $viewModel.monthlyLimit, in: 0...100000, step: 1000)
                            .tint(Color.black)
                        
                        Text("調整您的每月支出上限，幫助您更好地控制財務。")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                }
                
                Button(action: {
                    viewModel.saveProfile { }
                }) {
                    Text("確認上限")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .comicBorder(width: 3, cornerRadius: 15)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("支出上限設定")
        .alert("發生錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.errorMessage ?? "未知錯誤")
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("確定", role: .cancel) { }
                .buttonStyle(PlainButtonStyle())
        } message: {
            Text(viewModel.successMessage ?? "儲存成功")
        }
    }
}

// MARK: - List Rows

struct EditableCardRow: View {
    let card: CreditCardRecord
    var onUpdate: (CreditCardRecord) -> Void
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedDay: Int = 1
    
    var body: some View {
        HStack {
            if isEditing {
                VStack(spacing: 4) {
                    TextField("卡名", text: $editedName)
                        .font(.system(size: 14, weight: .bold))
                    HStack {
                        Text("出帳日:")
                            .font(.caption)
                        TextField("日", value: $editedDay, format: .number)
                            .font(.caption)
                            .frame(width: 30)
                    }
                }
                
                Button(action: {
                    var updated = card
                    updated.card_name = editedName
                    updated.billing_day = editedDay
                    onUpdate(updated)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { isEditing = false }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
            } else {
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
                    editedName = card.card_name
                    editedDay = card.billing_day
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 3, cornerRadius: 12)
        .comicShadow(offset: 2)
    }
}

struct EditableFamilyRow: View {
    let member: FamilyMemberRecord
    var onUpdate: (FamilyMemberRecord) -> Void
    var onToggleDefault: () -> Void
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    
    var body: some View {
        HStack {
            if isEditing {
                TextField("姓名", text: $editedName)
                    .font(.system(size: 14, weight: .bold))
                
                Button(action: {
                    var updated = member
                    updated.name = editedName
                    onUpdate(updated)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { isEditing = false }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                        if member.is_default == true {
                            Text("PRESET")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 4)
                                .background(MangaTheme.pink)
                                .foregroundColor(.white)
                                .comicBorder(width: 1, cornerRadius: 4)
                        }
                    }
                }
                Spacer()
                
                Button(action: onToggleDefault) {
                    Image(systemName: (member.is_default ?? false) ? "star.fill" : "star")
                        .foregroundColor((member.is_default ?? false) ? .orange : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
                
                Button(action: {
                    editedName = member.name
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 3, cornerRadius: 12)
        .comicShadow(offset: 2)
    }
}
