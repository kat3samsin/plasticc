import PlasticcCore
import SwiftUI

/// The end of the roll: flip out the crank and wind the film back into its canister.
/// Ticks get lighter and closer as the spool empties, then the leader slips free.
struct RewindView: View {
    let model: RollModel

    @State private var crank: RewindCrank
    @State private var lastAngle: Double?
    /// Where the arm points: always at the finger, measured from straight up.
    @State private var armAngle: Double = 0
    @State private var released = false
    @State private var hint = false

    init(model: RollModel) {
        self.model = model
        _crank = State(initialValue: RewindCrank(exposures: model.roll?.length.exposures ?? 24))
    }

    private var brand: FilmBrand { (model.film ?? .superia400).brand }

    var body: some View {
        ZStack {
            CameraBack(brand: brand)

            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text(released ? "FILM'S IN THE CANISTER" : "ROLL FINISHED")
                        .font(.print(28))
                        .italic()
                        .swaps(on: released)
                    Text(released ? "Off to the lab." : "Turn the crank to rewind the film.")
                        .font(.print(15, weight: .bold))
                        .opacity(0.85)
                        .swaps(on: released)
                }
                .foregroundStyle(brand.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

                Spacer()

                knob

                Spacer()

                FilmLeft(progress: crank.progress, exposures: model.roll?.length.exposures ?? 0, ink: brand.ink, band: brand.band)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) { hint = true }
        }
    }

    private var knob: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // Printed "rewind" arrow around the crank.
                Circle()
                    .trim(from: 0.05, to: 0.82)
                    .stroke(brand.ink.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
                    .frame(width: 300, height: 300)
                    .rotationEffect(.degrees(hint && crank.angle == 0 ? 360 : 0))
                    .opacity(released ? 0 : 1)
                // Film left on the spool, as a ring that empties.
                Circle()
                    .trim(from: 0, to: 1 - crank.progress)
                    .stroke(brand.band, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 262, height: 262)
                    .animation(.linear(duration: 0.1), value: crank.progress)
                CrankKnob(angle: armAngle, released: released)
                    .frame(width: 230, height: 230)
            }
            .position(center)
            .contentShape(Circle().inset(by: -30))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in turn(to: value.location, around: center) }
                    .onEnded { _ in lastAngle = nil }
            )
        }
        .frame(height: 320)
        .accessibilityElement()
        .accessibilityLabel("Rewind crank")
        .accessibilityValue("\(Int((1 - crank.progress) * 100)) percent of the film left")
        .accessibilityAction(named: "Rewind") {
            for event in crank.turn(by: crank.totalAngle) { handle(event) }
        }
    }

    private func turn(to point: CGPoint, around center: CGPoint) {
        guard !released else { return }
        let dx = point.x - center.x, dy = point.y - center.y
        // Too close to the spindle to read a direction.
        guard dx * dx + dy * dy > 18 * 18 else { lastAngle = nil; return }
        let angle = atan2(dy, dx)
        armAngle = angle + .pi / 2
        defer { lastAngle = angle }
        guard let lastAngle else { return }
        var delta = angle - lastAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        for event in crank.turn(by: delta) { handle(event) }
    }

    private func handle(_ event: RewindCrank.Event) {
        switch event {
        case .tick(let intensity):
            Feel.shared.crankTick(intensity: intensity)
        case .released:
            Feel.shared.crankRelease()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { released = true }
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                model.rewind()
            }
        }
    }
}

/// The crank: a ribbed knob with a fold-out arm and a little handle, turned by the finger.
private struct CrankKnob: View {
    let angle: Double
    let released: Bool

    var body: some View {
        ZStack {
            // Knob body with a ribbed rim.
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.32), Color(white: 0.1)], center: .init(x: 0.4, y: 0.35), startRadius: 4, endRadius: 130))
                .overlay(
                    ForEach(0..<36, id: \.self) { i in
                        Capsule()
                            .fill(.black.opacity(0.45))
                            .frame(width: 3, height: 12)
                            .offset(y: -104)
                            .rotationEffect(.degrees(Double(i) * 10))
                    }
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 2).padding(18))
                .shadow(color: .black.opacity(0.55), radius: 10, y: 6)

            // Arm and handle turn with the finger.
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.25)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 30, height: 112)
                    .offset(y: -42)
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.75), Color(white: 0.3)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 30))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
                    .offset(y: -86)
            }
            .rotationEffect(.radians(angle))

            // The spindle cap.
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.6), Color(white: 0.2)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 24))
                .frame(width: 34, height: 34)
            Image(systemName: released ? "checkmark" : "arrow.clockwise")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.8))
        }
        .scaleEffect(released ? 0.94 : 1)
    }
}

/// A strip of film running out of the camera, shorter as it's wound in.
private struct FilmLeft: View {
    let progress: Double
    let exposures: Int
    let ink: Color
    let band: Color

    private var framesOut: Int { Int(ceil(Double(exposures) * (1 - progress))) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width * (1 - progress)
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.15))
                    FilmStrip()
                        .frame(width: max(0, width))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 34)
            Text(progress >= 1 ? "ALL WOUND IN" : "\(framesOut) \(framesOut == 1 ? "FRAME" : "FRAMES") STILL OUT")
                .font(.print(11))
                .tracking(1.2)
                .foregroundStyle(ink.opacity(0.75))
                .monospacedDigit()
        }
        .accessibilityHidden(true)
    }
}

/// Orange-brown negative stock with sprocket holes.
struct FilmStrip: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.55, green: 0.27, blue: 0.10)))
            let hole = CGSize(width: 5, height: 4)
            var x: CGFloat = 4
            while x < size.width {
                for y in [3, size.height - 3 - hole.height] {
                    context.fill(Path(roundedRect: CGRect(origin: CGPoint(x: x, y: y), size: hole), cornerRadius: 1), with: .color(.black.opacity(0.65)))
                }
                x += 9
            }
            // Frame dividers.
            var f: CGFloat = 0
            while f < size.width {
                context.fill(Path(CGRect(x: f, y: 9, width: 1.5, height: size.height - 18)), with: .color(.black.opacity(0.3)))
                f += 46
            }
        }
    }
}
