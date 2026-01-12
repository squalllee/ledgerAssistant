import SwiftUI

// MARK: - Constants & Styles
struct MangaTheme {
    static let yellow = Color(hex: "FFEB3B")
    static let black = Color.black
    static let white = Color.white
    static let gray = Color(hex: "E0E0E0")
    
    struct Shadow {
        static let sm = Color.black
        static let md = Color.black
        static let lg = Color.black
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ComicBorder: ViewModifier {
    var width: CGFloat = 3
    var cornerRadius: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(MangaTheme.black, lineWidth: width)
            )
    }
}

struct ComicShadow: ViewModifier {
    var offset: CGFloat = 4
    var color: Color = .black
    
    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(color)
                    .offset(x: offset, y: offset)
            )
    }
}

extension View {
    func comicBorder(width: CGFloat = 3, cornerRadius: CGFloat = 0) -> some View {
        modifier(ComicBorder(width: width, cornerRadius: cornerRadius))
    }
    
    func comicShadow(offset: CGFloat = 4, color: Color = .black) -> some View {
        modifier(ComicShadow(offset: offset, color: color))
    }
}

// MARK: - Components

struct DotPattern: View {
    var color: Color = .black
    var opacity: Double = 0.1
    var spacing: CGFloat = 6
    
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}

struct DonutChart: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(MangaTheme.black, lineWidth: 12)
                .frame(width: 200, height: 200)
            
            // Background ring light gray
            Circle()
                .stroke(Color(hex: "f3f4f6"), lineWidth: 10)
                .frame(width: 200, height: 200)
            
            // Example segments (simplified)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(MangaTheme.black, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
            
            Circle()
                .trim(from: 0.25, to: 0.7)
                .stroke(MangaTheme.yellow, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
            
            // Inner circle details
            Circle()
                .stroke(MangaTheme.black, lineWidth: 2)
                .frame(width: 170, height: 170)
            Circle()
                .stroke(MangaTheme.black, lineWidth: 2)
                .frame(width: 230, height: 230)
            
            VStack {
                Text("$1,240")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .italic()
                
                HStack(spacing: 4) {
                    Text("+12% vs 上月")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(MangaTheme.black)
                .foregroundColor(MangaTheme.yellow)
                .rotationEffect(.degrees(-10))
            }
            .frame(width: 150, height: 150)
            .background(Color.white.opacity(0.8))
            .clipShape(Circle())
            .comicBorder(width: 2, cornerRadius: 75)
        }
    }
}

struct TransactionItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let amount: String
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(width: 48, height: 48)
                .background(isHovered ? MangaTheme.yellow : Color.white)
                .comicBorder(width: 3, cornerRadius: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                Text(subtitle)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .background(Color(hex: "f3f4f6"))
                    .border(Color(hex: "e5e7eb"), width: 1)
            }
            
            Spacer()
            
            Text(amount)
                .font(.system(size: 18, weight: .black))
        }
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 3, cornerRadius: 8)
        .comicShadow(offset: 2)
    }
}

// MARK: - Main View

struct MangaStyleDashboardView: View {
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date()) - 1
    
    let months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    
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
                            Text("ALEX")
                                .font(.system(size: 24, weight: .black))
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
                        VStack {
                            // Month Selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<12, id: \.self) { index in
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            selectedMonth = index
                                        }
                                    }) {
                                        Text("\(months[index])支出")
                                            .font(.system(size: 18, weight: .black))
                                            .tracking(selectedMonth == index ? 4 : 1)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                            .background(selectedMonth == index ? Color.black : Color.white)
                                            .foregroundColor(selectedMonth == index ? .white : .black)
                                            .rotationEffect(.degrees(selectedMonth == index ? -10 : 0))
                                            .comicBorder(width: 2, cornerRadius: 4)
                                            .comicShadow(offset: selectedMonth == index ? 2 : 0)
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                            
                            DonutChart()
                                .padding(.top, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(LedgerCategory.allCases) { category in
                                        categoryLegend(category: category)
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
                                        .padding(.bottom, 2)
                                        .border(width: 2, edges: [.bottom], color: .black)
                                    Spacer()
                                    Image(systemName: "creditcard.fill")
                                        .padding(4)
                                        .background(Color.white)
                                        .comicBorder(width: 2, cornerRadius: 20)
                                }
                                
                                Text("$12,450")
                                    .font(.system(size: 36, weight: .black))
                                
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
                                balanceMiniCard(title: "本月收入", amount: "$5,000", icon: "arrow.down")
                                balanceMiniCard(title: "本月支出", amount: "$3,200", icon: "arrow.up")
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
                                
                                Button("查看全部") {}
                                    .font(.system(size: 14, weight: .bold))
                                    .underline()
                                    .foregroundColor(.black)
                            }
                            
                            VStack(spacing: 12) {
                                TransactionItem(icon: LedgerCategory.food.icon, title: "星巴克", subtitle: "\(LedgerCategory.food.rawValue) • 10:45 AM", amount: "-$5.50")
                                TransactionItem(icon: LedgerCategory.transportation.icon, title: "Uber 行程", subtitle: "\(LedgerCategory.transportation.rawValue) • 昨天", amount: "-$24.00")
                                TransactionItem(icon: LedgerCategory.clothing.icon, title: "Apple 直營店", subtitle: "\(LedgerCategory.clothing.rawValue) • 10月24日", amount: "-$1,099.00")
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
            }
            
            // Tab Bar
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    tabButton(icon: "house.fill")
                    tabButton(icon: "chart.pie.fill")
                    
                    HStack(spacing: 4) {
                        Button(action: {}) {
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
                        
                        Button(action: {}) {
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
                    }
                    .padding(.horizontal, 4)
                    
                    tabButton(icon: "creditcard.fill")
                    tabButton(icon: "person.fill")
                }
                .padding(8)
                .background(Color.white)
                .comicBorder(width: 4, cornerRadius: 16)
                .comicShadow(offset: 6)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func categoryLegend(category: LedgerCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(category == .food ? .black : .primary)
            Text(category.rawValue)
                .font(.system(size: 14, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(category == .food ? MangaTheme.yellow : Color.white)
        .comicBorder(width: 2, cornerRadius: 8)
        .comicShadow(offset: 2)
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
        .comicShadow(offset: 4)
    }
    
    private func tabButton(icon: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .cornerRadius(8)
        }
    }
}

// MARK: - Helper Modifiers
struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

// MARK: - Preview
struct MangaStyleDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MangaStyleDashboardView()
    }
}
