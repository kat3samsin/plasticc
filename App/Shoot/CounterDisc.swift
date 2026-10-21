import SwiftUI

/// The frame counter: a printed number wheel seen through a little bubble window, turning one notch per frame.
struct CounterDisc: View {
    let remaining: Int

    private let window: CGFloat = 62
    private let wheelRadius: CGFloat = 120
    private let step: Double = 24

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.97))
            // The wheel's pivot sits below the window, so numbers sweep across in an arc.
            ZStack {
                // Only the numbers near the window; the rest would wrap round and overlap.
                ForEach(max(0, remaining - 3)...(remaining + 3), id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: n == remaining ? 28 : 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(n == 0 ? Plastic.counter : Color(white: 0.1))
                        .offset(y: -wheelRadius)
                        .rotationEffect(.degrees(Double(n) * step))
                }
            }
            .rotationEffect(.degrees(-Double(remaining) * step))
            .offset(y: wheelRadius)
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: remaining)

            // The index mark at the top of the window.
            Triangle()
                .fill(Plastic.counter)
                .frame(width: 8, height: 6)
                .offset(y: -window / 2 + 5)
            // Bubble lens: dark rim, a little glare.
            Circle()
                .strokeBorder(Plastic.dark, lineWidth: 5)
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .topLeading, endPoint: .center))
                .padding(7)
                .blendMode(.screen)
            Circle()
                .fill(RadialGradient(colors: [.clear, .black.opacity(0.28)], center: .center, startRadius: window * 0.25, endRadius: window * 0.55))
        }
        .frame(width: window, height: window)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .accessibilityElement()
        .accessibilityLabel("\(remaining) exposures left")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
