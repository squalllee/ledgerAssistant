import SwiftUI

struct ReceiptZoomView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .comicBorder(width: 4, cornerRadius: 0, color: .white)
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("無法讀取圖片")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }
            .padding(20)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(MangaTheme.yellow)
                            .background(Color.black.clipShape(Circle()))
                            .comicBorder(width: 2, cornerRadius: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(24)
                }
                Spacer()
            }
        }
    }
}
