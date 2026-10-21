import PlasticcCore
import SwiftUI

/// One print, full screen at full resolution. Pinch to zoom, drag to look around, double-tap to zoom in or out.
/// Tap anywhere else to put it back on the pile.
struct FullPrint: View {
    let url: URL
    /// The deck's smaller copy, shown until the full print has loaded.
    let preview: UIImage?
    let close: () -> Void
    let decide: (Verdict) -> Void

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture(perform: close)

            if let shown = image ?? preview {
                Image(uiImage: shown)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(zoom.simultaneously(with: pan))
                    .onTapGesture(count: 2) { toggleZoom() }
                    .onTapGesture { if scale == 1 { close() } }
                    .padding(.horizontal, 8)
                    .accessibilityLabel("Print")
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
                HStack(spacing: 16) {
                    choice("Toss", symbol: "xmark", color: Paper.stampRed) { decide(.trash) }
                    choice("Keep", symbol: "heart.fill", color: Paper.stampGreen) { decide(.keep) }
                }
                .padding(.bottom, 20)
                .opacity(scale > 1 ? 0 : 1)
            }
        }
        .task {
            let url = url
            image = await Task.detached { Thumbnail.load(url, maxPixel: 3200) }.value
        }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in scale = min(5, max(1, lastScale * value.magnification)) }
            .onEnded { _ in
                lastScale = scale
                if scale == 1 { recentre() }
            }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if scale > 1 {
                scale = 1
                recentre()
            } else {
                scale = 2.5
            }
            lastScale = scale
        }
    }

    private func recentre() {
        offset = .zero
        lastOffset = .zero
    }

    private func choice(_ label: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.print(16, weight: .heavy))
                .foregroundStyle(color)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .background(Paper.cream, in: Capsule())
        }
    }
}
