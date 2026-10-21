import PlasticcCore
import SwiftUI

/// The processed roll feeding out onto a light box: each frame turns from blank emulsion into its negative
/// as the lab gets to it, with sprocket holes and the film's edge printing.
struct NegativeStrip: View {
    let model: RollModel

    private let frame = CGSize(width: 96, height: 64)
    private var shots: [Roll.Shot] { model.roll?.shots ?? [] }
    private var film: FilmStock { model.film ?? .superia400 }
    private var colour: Bool { film.look.monoWeights == nil }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    leader
                    ForEach(shots.indices, id: \.self) { index in
                        cell(index)
                            .id(index)
                    }
                    Color.clear.frame(width: 40)
                }
                .background(base)
            }
            .scrollIndicators(.hidden)
            .frame(height: frame.height + 34)
            .background(LightBox())
            .onChange(of: model.developedCount) { _, done in
                withAnimation(.easeInOut(duration: 0.5)) { reader.scrollTo(min(done, max(0, shots.count - 1)), anchor: .center) }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Negatives: \(model.developedCount) of \(shots.count) frames processed")
    }

    /// The film base: amber on colour negative, clear grey on silver film.
    private var base: Color {
        colour ? Color(red: 0.86, green: 0.48, blue: 0.22) : Color(white: 0.74)
    }

    private var edgeInk: Color {
        colour ? Color(red: 0.55, green: 0.22, blue: 0.06) : Color(white: 0.35)
    }

    /// The tongue of film before frame 1, with the maker's edge printing.
    private var leader: some View {
        ZStack {
            sprockets(width: 70)
            Text(film.brand.maker)
                .font(.print(9))
                .tracking(1.5)
                .foregroundStyle(edgeInk)
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
        .frame(width: 70, height: frame.height + 34)
    }

    private func cell(_ index: Int) -> some View {
        let done = shots[index].developedFile != nil
        let next = index == model.developedCount && model.isDeveloping
        return ZStack {
            sprockets(width: frame.width + 8)
            VStack(spacing: 0) {
                // Frame number and the stock's edge code, printed in the margin like real film.
                HStack(spacing: 4) {
                    Text("▸\(index + 1)")
                    Spacer(minLength: 0)
                    Text("\(film.brand.line) \(film.brand.speed)")
                        .lineLimit(1)
                }
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(edgeInk.opacity(done ? 1 : 0.5))
                .frame(width: frame.width, height: 12)
                image(index, done: done, next: next)
                    .frame(width: frame.width, height: frame.height)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
        }
        .frame(width: frame.width + 8, height: frame.height + 34)
    }

    @ViewBuilder
    private func image(_ index: Int, done: Bool, next: Bool) -> some View {
        if done, let negative = model.negatives[index] {
            let portrait = negative.size.height > negative.size.width
            Image(uiImage: negative)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // Portrait shots lie sideways on a 35 mm strip.
                .frame(width: portrait ? frame.height : frame.width, height: portrait ? frame.width : frame.height)
                .rotationEffect(.degrees(portrait ? -90 : 0))
                .frame(width: frame.width, height: frame.height)
                .clipped()
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            // Not processed yet: dull, unexposed-looking emulsion; the frame in the processor shimmers.
            ZStack {
                Color(red: 0.32, green: 0.24, blue: 0.20)
                if next { Shimmer() }
            }
        }
    }

    private func sprockets(width: CGFloat) -> some View {
        Canvas { context, size in
            let hole = CGSize(width: 5, height: 4)
            var x: CGFloat = 3
            while x + hole.width < size.width {
                for y in [3, size.height - 3 - hole.height] {
                    context.fill(Path(roundedRect: CGRect(origin: CGPoint(x: x, y: y), size: hole), cornerRadius: 1),
                                 with: .color(.white.opacity(0.85)))
                }
                x += 9.5
            }
        }
        .frame(width: width)
    }
}

/// A glowing light box under the strip, so the negatives read in the dark.
private struct LightBox: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(red: 1, green: 0.97, blue: 0.92))
            .shadow(color: Color(red: 1, green: 0.9, blue: 0.8).opacity(0.6), radius: 18)
            .padding(.vertical, -6)
    }
}

/// A slow sweep of light across the frame the processor is working on.
private struct Shimmer: View {
    @State private var phase = -1.0

    var body: some View {
        LinearGradient(colors: [.clear, .white.opacity(0.35), .clear],
                       startPoint: UnitPoint(x: phase, y: 0.5), endPoint: UnitPoint(x: phase + 0.6, y: 0.5))
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { phase = 1.4 }
            }
    }
}
