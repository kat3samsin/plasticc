import PlasticcCore
import SwiftUI

/// A fresh camera, still in its shrink-wrap. Pull the tab and drag to rip the plastic off.
struct UnwrapView: View {
    let model: RollModel

    /// How far the rip has run from the top-right corner, in points along the diagonal.
    @State private var rip: CGFloat = 0
    @State private var lastCrinkle: CGFloat = 0
    @State private var gone = false
    @State private var startRip: CGFloat = 0
    @State private var wiggle = false

    private let size = CGSize(width: 300, height: 470)
    private var finish: CGFloat { (size.width + size.height) * 0.78 }
    private var brand: FilmBrand { (model.film ?? .superia400).brand }

    var body: some View {
        ZStack {
            PaperBackground(color: Color(red: 0.88, green: 0.83, blue: 0.74))

            VStack(spacing: 30) {
                VStack(spacing: 6) {
                    Text(gone ? "FRESH OUT OF THE WRAP" : "STILL IN ITS WRAP")
                        .font(.print(24))
                        .swaps(on: gone)
                    Text(gone ? "Now load the film." : "Pull the red tab to tear the plastic.")
                        .font(.typed(16))
                        .opacity(0.75)
                        .swaps(on: gone)
                }
                .foregroundStyle(Paper.ink)
                .padding(.top, 40)

                ZStack {
                    CameraFront(brand: brand, exposures: model.roll?.length.exposures ?? 24)
                    wrap
                }
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(wiggle ? -1 : 1))
                .gesture(tearGesture)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Camera in shrink-wrap")
                .accessibilityAction(named: "Tear the wrap") { tearAway() }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.12).repeatCount(5, autoreverses: true).delay(0.6)) { wiggle = true }
        }
    }

    private var wrap: some View {
        ZStack {
            // The clear shrink-wrap: milky, glossy, with crinkled highlights.
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.2))
                .overlay(Crinkles().opacity(0.9))
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .white.opacity(0.5), location: 0),
                        .init(color: .white.opacity(0.0), location: 0.25),
                        .init(color: .white.opacity(0.28), location: 0.5),
                        .init(color: .white.opacity(0.0), location: 0.7),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 2))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .mask(
                    Rectangle()
                        .padding(-20)
                        .overlay(Rip(distance: rip, size: size).fill(.black).blendMode(.destinationOut))
                        .compositingGroup()
                )

            // The curled edge along the rip.
            RipEdge(distance: rip, size: size)
                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .mask(RoundedRectangle(cornerRadius: 30, style: .continuous).padding(-3))
                .opacity(rip > 4 && !gone ? 1 : 0)

            // The red pull tab, stuck to the top-right corner until the rip passes it.
            PullTab()
                .rotationEffect(.degrees(45))
                .position(x: size.width + 2, y: -2)
                .opacity(rip > 30 ? 0 : 1)
        }
        .offset(x: gone ? 260 : 0, y: gone ? -340 : 0)
        .rotationEffect(.degrees(gone ? 28 : 0))
        .opacity(gone ? 0 : 1)
        .allowsHitTesting(!gone)
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !gone else { return }
                // Down and to the left, along the camera's diagonal.
                let along = (-value.translation.width + value.translation.height) / 1.41
                rip = max(rip, startRip + along)
                if rip - lastCrinkle > 18 {
                    lastCrinkle = rip
                    Feel.shared.crinkle(strength: Double(min(1, rip / finish)))
                }
                if rip > finish * 0.65 { tearAway() }
            }
            .onEnded { _ in startRip = rip }
    }

    private func tearAway() {
        guard !gone else { return }
        Feel.shared.tear()
        withAnimation(.easeIn(duration: 0.45)) {
            rip = finish
            gone = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            model.tear()
        }
    }
}

/// The torn-away part of the wrap: everything above and right of a jagged line across the top-right corner.
private struct Rip: Shape {
    var distance: CGFloat
    let size: CGSize

    var animatableData: CGFloat {
        get { distance }
        set { distance = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let line = RipEdge(distance: distance, size: size).points()
        guard let first = line.first, let last = line.last else { return Path() }
        return Path { p in
            p.move(to: first)
            for point in line.dropFirst() { p.addLine(to: point) }
            p.addLine(to: CGPoint(x: last.x + 400, y: last.y))
            p.addLine(to: CGPoint(x: last.x + 400, y: -400))
            p.addLine(to: CGPoint(x: first.x, y: -400))
            p.closeSubpath()
        }
    }
}

/// The jagged rip line itself, from the top edge to the right edge.
private struct RipEdge: Shape {
    var distance: CGFloat
    let size: CGSize

    var animatableData: CGFloat {
        get { distance }
        set { distance = newValue }
    }

    func points() -> [CGPoint] {
        let reach = distance * 1.41 + 12
        let start = CGPoint(x: size.width + 12 - reach, y: -12)
        let end = CGPoint(x: size.width + 12, y: -12 + reach)
        let length = hypot(end.x - start.x, end.y - start.y)
        let along = CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length)
        let across = CGPoint(x: along.y, y: -along.x)
        // A tooth every 9 pt, each with its own fixed depth, so the jagged edge holds its shape as it moves.
        let count = Int(length / 9)
        var points = [start]
        for k in 1..<max(2, count) {
            var rng = SeededRandom(seed: 0x7EA2 &+ UInt64(k) &* 0x9E37)
            let jitter = CGFloat(rng.unit() - 0.5) * 11
            let d = CGFloat(k) * 9
            points.append(CGPoint(x: start.x + along.x * d + across.x * jitter, y: start.y + along.y * d + across.y * jitter))
        }
        points.append(end)
        return points
    }

    func path(in rect: CGRect) -> Path {
        let line = points()
        return Path { p in
            guard let first = line.first else { return }
            p.move(to: first)
            for point in line.dropFirst() { p.addLine(to: point) }
        }
    }
}

/// Fine highlight streaks where the shrink-wrap has creased.
private struct Crinkles: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 0xC41C)
            for _ in 0..<26 {
                let x = CGFloat(rng.unit()) * size.width, y = CGFloat(rng.unit()) * size.height
                let length = 20 + CGFloat(rng.unit()) * 70
                let angle = CGFloat(rng.unit()) * .pi
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                context.stroke(p, with: .color(.white.opacity(0.25 + rng.unit() * 0.35)), lineWidth: 0.8 + CGFloat(rng.unit()) * 1.4)
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

private struct PullTab: View {
    var body: some View {
        Text("PULL")
            .font(.print(11))
            .tracking(1.5)
            .foregroundStyle(.white)
            .frame(width: 74, height: 26)
            .background(Paper.stampRed, in: RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}
