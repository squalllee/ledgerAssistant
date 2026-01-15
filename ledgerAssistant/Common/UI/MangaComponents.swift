import SwiftUI

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

struct ChartSegment: Identifiable {
    let id = UUID()
    let proportion: Double
    let color: Color
}

struct DonutChart: View {
    var amount: String
    var segments: [ChartSegment] = []
    var changeLabel: String = "0%"
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(MangaTheme.black, lineWidth: 12)
                .frame(width: 200, height: 200)
            
            Circle()
                .stroke(Color(hex: "f3f4f6"), lineWidth: 10)
                .frame(width: 200, height: 200)
            
            // Dynamic Segments
            ForEach(0..<segments.count, id: \.self) { index in
                Circle()
                    .trim(from: startPoint(for: index), to: endPoint(for: index))
                    .stroke(segments[index].color, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
            }
            
            VStack {
                Text(amount)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .italic()
                
                HStack(spacing: 4) {
                    Text("\(changeLabel) vs 上月")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(MangaTheme.black)
                .foregroundColor(MangaTheme.yellow)
                .rotationEffect(.degrees(0))
            }
            .frame(width: 150, height: 150)
            .background(Color.white.opacity(0.8))
            .clipShape(Circle())
            .comicBorder(width: 2, cornerRadius: 75)
        }
    }
    
    private func startPoint(for index: Int) -> CGFloat {
        var start: Double = 0
        for i in 0..<index {
            start += segments[i].proportion
        }
        return CGFloat(start)
    }
    
    private func endPoint(for index: Int) -> CGFloat {
        return startPoint(for: index) + CGFloat(segments[index].proportion)
    }
}

struct MangaPieChart: View {
    var segments: [ChartSegment] = []
    
    var body: some View {
        ZStack {
            // Main Outer Border (Sticker Effect)
            Circle()
                .fill(Color.black)
                .frame(width: 292, height: 292)
            
            Circle()
                .fill(Color.white)
                .frame(width: 284, height: 284)
            
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                ZStack {
                    ForEach(0..<segments.count, id: \.self) { index in
                        let start = startAngle(for: index)
                        let end = endAngle(for: index)
                        
                        // Filled Segment with Gradient
                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                            path.closeSubpath()
                        }
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [segments[index].color.opacity(0.8), segments[index].color]),
                                center: .center,
                                startRadius: 0,
                                endRadius: radius
                            )
                        )
                        
                        // Screen-tone (Dot Pattern) Overlay
                        ZStack {
                            DotPattern(opacity: 0.1, spacing: 4)
                        }
                        .mask(
                            Path { path in
                                path.move(to: center)
                                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                                path.closeSubpath()
                            }
                        )
                        .opacity(0.15)
                        
                        // Segment border
                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                            path.closeSubpath()
                        }
                        .stroke(Color.black, lineWidth: 2)
                        
                        // Percentage Label
                        if segments[index].proportion > 0.04 {
                            let midAngle = (start.radians + end.radians) / 2
                            let labelRadius = radius * 0.72
                            let labelX = center.x + cos(midAngle) * labelRadius
                            let labelY = center.y + sin(midAngle) * labelRadius
                            
                            Text("\(Int(segments[index].proportion * 100))")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .italic()
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2, x: 2, y: 2)
                                .position(x: labelX, y: labelY)
                        }
                    }
                }
            }
            .frame(width: 280, height: 280)
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func startAngle(for index: Int) -> Angle {
        var start: Double = 0
        for i in 0..<index {
            start += segments[i].proportion
        }
        return Angle(degrees: start * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let end = (startAngle(for: index).degrees + segments[index].proportion * 360)
        return Angle(degrees: end)
    }
}

struct CategoryProgressBar: View {
    let category: String
    let icon: String
    let amount: String
    let proportion: Double
    let color: Color
    let change: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
                
                Text(category)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(amount)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(color)
                    
                    if let change = change {
                        Text(change)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .comicBorder(width: 1, cornerRadius: 4)
                    
                    // Progress
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.7), color]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(proportion))
                        .comicBorder(width: 2, cornerRadius: 4)
                        .overlay(
                            HStack {
                                Spacer()
                                Text("\(Int(proportion * 100))%")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1)
                                    .padding(.trailing, 4)
                            },
                            alignment: .trailing
                        )
                }
            }
            .frame(height: 20)
        }
        .padding(.vertical, 8)
    }
}

struct MangaTimelineView: View {
    let dateGroups: [TimelineDateGroup]
    var onReceiptTap: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 32) {
            ForEach(dateGroups) { dateGroup in
                TimelineSection(dateGroup: dateGroup, onReceiptTap: onReceiptTap)
            }
        }
    }
}

struct TimelineSection: View {
    let dateGroup: TimelineDateGroup
    var onReceiptTap: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Header
            HStack {
                Text(dateGroup.displayDate)
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("$\(Int(dateGroup.dailyTotal))")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 4)
            
            // Category Groups with Timeline
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<dateGroup.categoryGroups.count, id: \.self) { index in
                    let catGroup = dateGroup.categoryGroups[index]
                    let isLast = index == dateGroup.categoryGroups.count - 1
                    
                    TimelineCategoryRow(catGroup: catGroup, isLast: isLast, onReceiptTap: onReceiptTap)
                }
            }
        }
    }
}

struct TimelineCategoryRow: View {
    let catGroup: TimelineCategoryGroup
    let isLast: Bool
    var onReceiptTap: ((String) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timeline Column
            VStack(spacing: 0) {
                ZStack {
                     Circle()
                        .fill(catGroup.category.color)
                        .frame(width: 12, height: 12)
                        .comicBorder(width: 2, cornerRadius: 6)
                    
                    // Icon beside the dot
                    Image(systemName: catGroup.category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(catGroup.category.color)
                        .offset(x: -25)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)
            
            // Content Column
            VStack(alignment: .leading, spacing: 10) {
                // Category Header
                HStack(alignment: .center, spacing: 12) {
                    Text(catGroup.category.rawValue)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                    
                    if let method = catGroup.paymentMethod {
                        Text(method)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.1))
                            .comicBorder(width: 1.5, cornerRadius: 4)
                    }
                    
                    if let payer = catGroup.payerName {
                        HStack(spacing: 4) {
                            Text(payer)
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(MangaTheme.yellow.opacity(0.8))
                                .comicBorder(width: 1.5, cornerRadius: 4)
                            
                            // Receipts icons next to payer
                            if !catGroup.receiptUrls.isEmpty {
                                ForEach(catGroup.receiptUrls, id: \.self) { url in
                                    Button(action: {
                                        onReceiptTap?(url)
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(MangaTheme.pink)
                                            .comicBorder(width: 1.5, cornerRadius: 6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    } else if !catGroup.receiptUrls.isEmpty {
                        // If no payer but has receipts, show them after category/method
                        ForEach(catGroup.receiptUrls, id: \.self) { url in
                            Button(action: {
                                onReceiptTap?(url)
                            }) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(MangaTheme.pink)
                                            .comicBorder(width: 1.5, cornerRadius: 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer()
                    
                    Text("$\(Int(catGroup.total))")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.gray)
                }
                
                // Sub Items
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(catGroup.items) { item in
                        HStack(spacing: 8) {
                            Text("└ \(item.name)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(Int(item.amount))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 28)
        }
    }
}

struct TransactionItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let amount: String
    let type: String
    var iconColor: Color = .black
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .comicBorder(width: 2, cornerRadius: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .background(Color(hex: "f3f4f6"))
                        .border(Color(hex: "e5e7eb"), width: 1)
                }
            }
            
            Spacer()
            
            Text(amount)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.black)
        }
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 3, cornerRadius: 8)
    }
}

struct MangaTextField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.black)
            TextField("", text: $text)
                .padding(8)
                .background(Color.white)
                .comicBorder(width: 2)
        }
    }
}

struct ProfileSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .background(MangaTheme.yellow)
                .comicBorder(width: 2)
                .rotationEffect(.degrees(-2))
            
            content
                .padding(16)
                .background(Color.white)
                .comicBorder(width: 3, cornerRadius: 12)
        }
    }
}
