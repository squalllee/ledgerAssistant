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
            
            Circle()
                .stroke(MangaTheme.black, lineWidth: 2)
                .frame(width: 170, height: 170)
            Circle()
                .stroke(MangaTheme.black, lineWidth: 2)
                .frame(width: 230, height: 230)
            
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
                .rotationEffect(.degrees(-10))
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
                .foregroundColor(.black)
                .frame(width: 48, height: 48)
                .background(isHovered ? MangaTheme.yellow : Color.white)
                .comicBorder(width: 3, cornerRadius: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.black)
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
                .foregroundColor(.black)
        }
        .padding(12)
        .background(Color.white)
        .comicBorder(width: 3, cornerRadius: 8)
        .comicShadow(offset: 2)
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
                .comicShadow(offset: 4)
        }
    }
}
