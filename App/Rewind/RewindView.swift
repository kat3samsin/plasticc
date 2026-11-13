import PlasticcCore
import SwiftUI

/// The end of the roll: flip out the crank and wind the film back into its canister. Ticks get lighter and closer
/// as the spool empties, then the leader slips free, the back pops open, and the canister goes in the lab envelope.
struct RewindView: View {
    let model: RollModel

    @State private var crank: RewindCrank
    @State private var lastAngle: Double?
    /// Where the arm points, measured from straight up. It turns with the finger from wherever it's grabbed.
    @State private var armAngle: Double = 0
    @State private var released = false
    @State private var hint = false
    @State private var backOpen = false
    /// Resets by itself, springing the canister home, when the drag ends or the system cancels it.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.7)))
    private var drag: CGSize = .zero
    @State private var nearEnvelope = false
    @State private var dropped = false

    init(model: RollModel) {
        self.model = model
        _crank = State(initialValue: RewindCrank(exposures: model.roll?.length.exposures ?? 24))
    }

    private var film: FilmStock { model.film ?? .superia400 }
    private var exposures: Int { model.roll?.length.exposures ?? 24 }

    var body: some View {
        ZStack {
            CameraBack()

            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.print(26))
                        .italic()
                        .swaps(on: title)
                    Text(instruction)
                        .font(.print(15, weight: .bold))
                        .opacity(0.8)
                        .swaps(on: instruction)
                }
                .foregroundStyle(Plastic.trim)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

                if backOpen {
                    unloading
                        .transition(.opacity)
                } else {
                    Spacer()

                    knob

                    Spacer()

                    FilmLeft(progress: crank.progress, exposures: exposures, ink: Plastic.trim, band: Plastic.accent)
                        .padding(.bottom, 30)
                }
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
                    .stroke(Plastic.trim.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
                    .frame(width: 300, height: 300)
                    .rotationEffect(.degrees(hint ? 360 : 0))
                    .opacity(released || crank.angle > 0 ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: crank.angle > 0)
                // Film left on the spool, as a ring that empties.
                Circle()
                    .trim(from: 0, to: 1 - crank.progress)
                    .stroke(Plastic.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 262, height: 262)
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
        defer { lastAngle = angle }
        guard let lastAngle else { return }
        var delta = angle - lastAngle
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        armAngle += delta
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
                try? await Task.sleep(for: .seconds(1.1))
                Feel.shared.backOpen()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { backOpen = true }
            }
        }
    }

    private var title: String {
        if dropped { return "OFF TO THE LAB" }
        if backOpen { return "SEND IT TO THE LAB" }
        return released ? "FILM'S IN THE CANISTER" : "ROLL FINISHED"
    }

    private var instruction: String {
        if dropped { return "Your prints will be ready soon." }
        if backOpen { return "Drag the canister into the envelope." }
        return released ? "Opening the back…" : "Turn the crank to rewind the film."
    }

    // MARK: - Unloading

    /// Where the envelope's slot sits, in bay coordinates.
    private static let slot = CGPoint(x: FilmBay.size.width / 2, y: FilmBay.size.height + 150)

    private var unloading: some View {
        ZStack(alignment: .topLeading) {
            FilmBay()

            LabMailer(film: film, lit: nearEnvelope, filled: dropped)
                .frame(width: 230, height: 150)
                .offset(x: Self.slot.x - 115, y: Self.slot.y - 40)
                .zIndex(1)

            // The rewound canister, just its tongue left out.
            FilmCanister(film: film, exposures: exposures, leader: 14)
                .scaleEffect(nearEnvelope || dropped ? 0.85 : 1, anchor: .top)
                .offset(x: canisterOrigin.x, y: canisterOrigin.y)
                // Once it's dropped it slides down behind the envelope's front, into the slot.
                .zIndex(dropped ? 0.5 : 2)
                .gesture(dropped ? nil : canisterGesture)
                .accessibilityElement()
                .accessibilityLabel("Film canister, \(film.name)")
                .accessibilityAction(named: "Send to the lab") { drop() }

            if !dropped, drag == .zero {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down").font(.system(size: 14, weight: .black))
                    Text("DROP IN").font(.print(11)).tracking(2)
                }
                .foregroundStyle(Plastic.accent)
                .offset(x: Self.slot.x - 40, y: FilmBay.size.height + 30 + (hint ? 6 : 0))
                .allowsHitTesting(false)
            }
        }
        .frame(width: FilmBay.size.width, height: FilmBay.size.height + 260, alignment: .topLeading)
        .frame(maxHeight: .infinity)
        // A drag the system cancelled springs home without an end: unlight the envelope.
        .onChange(of: drag) { _, drag in if drag == .zero, nearEnvelope, !dropped { nearEnvelope = false } }
    }

    private var canisterOrigin: CGPoint {
        if dropped { return CGPoint(x: Self.slot.x - 45, y: Self.slot.y - 8) }
        return CGPoint(x: FilmBay.seat.x + drag.width, y: FilmBay.seat.y + drag.height)
    }

    private var canisterGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, drag, _ in drag = value.translation }
            .onChanged { value in
                let isNear = Self.overSlot(value.translation)
                if isNear != nearEnvelope {
                    withAnimation(.easeOut(duration: 0.15)) { nearEnvelope = isNear }
                    if isNear { Feel.shared.threshold() }
                }
            }
            .onEnded { value in
                if Self.overSlot(value.translation) { drop() }
            }
    }

    /// Whether the canister's middle, dragged this far, is over the envelope's slot.
    private static func overSlot(_ translation: CGSize) -> Bool {
        let x = FilmBay.seat.x + 45 + translation.width, y = FilmBay.seat.y + 68 + translation.height
        return hypot(x - slot.x, y - slot.y) < 110
    }

    private func drop() {
        guard !dropped else { return }
        Feel.shared.envelopeDrop()
        withAnimation(.easeIn(duration: 0.32)) {
            dropped = true
            nearEnvelope = false
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            model.rewind()
        }
    }
}

/// The lab's film mailer: a kraft envelope with a slot, waiting for the canister.
private struct LabMailer: View {
    let film: FilmStock
    let lit: Bool
    let filled: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Paper.kraft)
                .overlay(Grain(opacity: 0.2, blend: .multiply))
                .overlay(alignment: .top) {
                    // The open mouth, dark inside.
                    Capsule()
                        .fill(Color(red: 0.25, green: 0.17, blue: 0.1))
                        .frame(height: 16)
                        .padding(.horizontal, 26)
                        .padding(.top, 14)
                        .shadow(color: lit ? Plastic.lamp : .clear, radius: 10)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PLASTICC PHOTO LAB")
                            .font(.print(13))
                            .foregroundStyle(Paper.stampRed)
                        Text("FILM: \(film.name.uppercased())")
                            .font(.typed(10))
                            .foregroundStyle(Paper.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("DEVELOP & PRINT · 1 SET 4×6")
                            .font(.typed(10))
                            .foregroundStyle(Paper.fadedInk)
                    }
                    .padding(14)
                }
        }
        .rotationEffect(.degrees(lit ? -3 : -1.5))
        .scaleEffect(filled ? 1.04 : (lit ? 1.03 : 1))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: filled)
        .accessibilityHidden(true)
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
                    // The ribbed rim turns with the arm, so the whole knob reads as spinning.
                    ZStack {
                        ForEach(0..<36, id: \.self) { i in
                            Capsule()
                                .fill(.black.opacity(0.45))
                                .frame(width: 3, height: 12)
                                .offset(y: -104)
                                .rotationEffect(.degrees(Double(i) * 10))
                        }
                    }
                    .drawingGroup()
                    .rotationEffect(.radians(angle))
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
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.15))
                    // The strip slides left into the camera, sprocket holes and all.
                    FilmStrip()
                        .frame(width: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .offset(x: -geo.size.width * progress)
                }
                .clipped()
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
