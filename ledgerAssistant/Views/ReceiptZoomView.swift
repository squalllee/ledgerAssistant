import SwiftUI

struct ReceiptZoomView: View {
    let imageUrl: String
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(.white)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 0.8), maxScale + 0.5)
                                        
                                        // Recenter if needed
                                        if scale > 1.0 {
                                            let deltaX = (0 - offset.width) * (1 - delta)
                                            let deltaY = (0 - offset.height) * (1 - delta)
                                            offset.width += deltaX
                                            offset.height += deltaY
                                        }
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            scale = min(max(scale, minScale), maxScale)
                                            validateAndCorrectOffset(in: geometry.size)
                                            lastOffset = offset
                                        }
                                        if scale <= minScale {
                                            haptic.impactOccurred()
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            let targetWidth = lastOffset.width + value.translation.width
                                            let targetHeight = lastOffset.height + value.translation.height
                                            
                                            // Apply rubber banding if dragging past boundaries
                                            let bounds = getBounds(for: scale, in: geometry.size)
                                            offset = CGSize(
                                                width: applyRubberBanding(value: targetWidth, bound: bounds.width),
                                                height: applyRubberBanding(value: targetHeight, bound: bounds.height)
                                            )
                                        }
                                    }
                                    .onEnded { value in
                                        if scale > 1.0 {
                                            let previousOffset = offset
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                validateAndCorrectOffset(in: geometry.size)
                                            }
                                            // Haptic feedback if we were corrected
                                            if abs(offset.width - previousOffset.width) > 5 || abs(offset.height - previousOffset.height) > 5 {
                                                haptic.impactOccurred(intensity: 0.8)
                                            }
                                        } else {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                            }
                                        }
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                haptic.impactOccurred(intensity: 0.4)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 3.0
                                    }
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                            Text("無法讀取圖片").font(.system(size: 16, weight: .bold))
                        }.foregroundColor(.white)
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
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        }
                        .padding(24)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            haptic.prepare()
        }
    }
    
    private func getBounds(for currentScale: CGFloat, in containerSize: CGSize) -> CGSize {
        let zoomedWidth = containerSize.width * currentScale
        let zoomedHeight = containerSize.height * currentScale
        
        return CGSize(
            width: max(0, (zoomedWidth - containerSize.width) / 2),
            height: max(0, (zoomedHeight - containerSize.height) / 2)
        )
    }
    
    private func applyRubberBanding(value: CGFloat, bound: CGFloat) -> CGFloat {
        if value > bound {
            return bound + (value - bound) * 0.3
        } else if value < -bound {
            return -bound + (value + bound) * 0.3
        }
        return value
    }
    
    private func validateAndCorrectOffset(in containerSize: CGSize) {
        if scale <= 1.0 {
            offset = .zero
            return
        }
        
        let bounds = getBounds(for: scale, in: containerSize)
        
        var newW = offset.width
        var newH = offset.height
        
        if offset.width > bounds.width { newW = bounds.width }
        else if offset.width < -bounds.width { newW = -bounds.width }
        
        if offset.height > bounds.height { newH = bounds.height }
        else if offset.height < -bounds.height { newH = -bounds.height }
        
        offset = CGSize(width: newW, height: newH)
    }
}
