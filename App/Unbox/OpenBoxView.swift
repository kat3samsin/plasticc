import PlasticcCore
import SwiftUI

/// Home with a new roll: lift the box's end flap, slide the plastic tube out, and pop its lid to get the film.
struct OpenBoxView: View {
    let model: RollModel

    private enum Step { case closed, open, tubeOut, popped }

    @State private var step = Step.closed
    /// The flap's lift, 0 shut to 1 open.
    @State private var flap: Double = 0
    @State private var flapStart: Double = 0
    @State private var lastCreak: Double = 0
    /// How far the tube has been pulled up out of the box, in points.
    @State private var lift: CGFloat = 0
    @State private var liftStart: CGFloat = 0
    @State private var lastSlide: CGFloat = 0
    /// The box sliding away once the tube's out.
    @State private var boxGone = false
    @State private var lidOff = false
    @State private var canisterUp = false
    @State private var hint = false

    private var film: FilmStock { model.film ?? .superia400 }
    private var exposures: Int { model.roll?.length.exposures ?? 24 }
    /// Where the tube sits in the box: centred on the open end, its lid just in the opening.
    private static let tubeSize = CGSize(width: 76, height: 168)
    private static let tubeHome = CGPoint(x: (BoxGeometry.size.width - tubeSize.width) / 2 - 4, y: 0)
    /// Pulled this far, the tube's clear of the box.
    private static let fullLift: CGFloat = 186
    /// How far the empty box slides away, off the bottom of the screen.
    private static let boxDrop: CGFloat = 620

    var body: some View {
        ZStack {
            Table()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.print(26))
                        .italic()
                        .swaps(on: step)
                    Text(instruction)
                        .font(.typed(16))
                        .opacity(0.8)
                        .swaps(on: step)
                }
                .foregroundStyle(Plastic.trim)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                scene
                    .frame(height: 500, alignment: .bottom)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { hint = true }
        }
    }

    private var title: String {
        switch step {
        case .closed: "A FRESH ROLL"
        case .open: "OPEN"
        case .tubeOut: "NEARLY THERE"
        case .popped: "THERE'S YOUR FILM"
        }
    }

    private var instruction: String {
        switch step {
        case .closed: "Lift the flap on top of the box."
        case .open: "Pull the tube up out of the box."
        case .tubeOut: "Pop the lid off the tube."
        case .popped: "Now load it into your camera."
        }
    }

    private var scene: some View {
        ZStack(alignment: .bottom) {
            FilmBox(film: film, exposures: exposures, flap: flap) {
                FilmTube(film: film, exposures: exposures, lidOff: lidOff, canisterUp: canisterUp)
                    .frame(width: Self.tubeSize.width, height: Self.tubeSize.height)
                    .offset(x: Self.tubeHome.x, y: Self.tubeHome.y - lift - (boxGone ? Self.boxDrop - 150 : 0))
                    .opacity(step == .closed && flap < 0.5 ? 0 : 1)
            }
            .offset(y: boxGone ? Self.boxDrop : 0)

            hintArrow
        }
        // The whole lower part of the screen is a handle, so a short tap on the tube's lid lands.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .gesture(boxGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Box of \(film.name)")
        .accessibilityHint(instruction)
        .accessibilityAction(named: "Open the box") { openEverything() }
    }

    /// A bobbing arrow pointing at what to pull next.
    @ViewBuilder private var hintArrow: some View {
        let label: String? = switch step {
        case .closed: "LIFT"
        case .open where lift < 10: "PULL"
        case .tubeOut: "POP"
        default: nil
        }
        if let label {
            VStack(spacing: 2) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .black))
                Text(label)
                    .font(.print(11))
                    .tracking(2)
            }
            .foregroundStyle(Plastic.accent)
            .offset(y: hint ? -6 : 0)
            .padding(.bottom, arrowHeight)
            .allowsHitTesting(false)
            .transition(.opacity)
            .id(label)
        }
    }

    /// The arrow sits just above whatever's next: the flap, the tube's top, or the lid of the tube on its own.
    private var arrowHeight: CGFloat {
        switch step {
        case .closed: BoxGeometry.size.height + 10
        case .open: BoxGeometry.size.height + 30
        default: BoxGeometry.size.height + Self.fullLift + 30 - 150
        }
    }

    // MARK: - Gestures

    /// One drag gesture for the whole box: what it moves depends on the step.
    private var boxGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let up = -value.translation.height
                switch step {
                case .closed:
                    flap = min(1, max(0, flapStart + up / 120))
                    if abs(flap - lastCreak) > 0.14 {
                        lastCreak = flap
                        Feel.shared.flapCreak(progress: flap)
                    }
                case .open:
                    lift = min(Self.fullLift, max(0, liftStart + up))
                    if abs(lift - lastSlide) > 26 {
                        lastSlide = lift
                        Feel.shared.tubeSlide(progress: Double(lift / Self.fullLift))
                    }
                case .tubeOut:
                    if up > 30 { popLid() }
                case .popped:
                    break
                }
            }
            .onEnded { value in
                switch step {
                case .closed:
                    if flap > 0.45 { openFlap() } else { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { flap = 0 } }
                    flapStart = flap
                case .open:
                    if lift > Self.fullLift * 0.6 { pullTubeOut() } else { withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { lift = 0 } }
                    liftStart = lift
                case .tubeOut:
                    if abs(value.translation.height) < 10, abs(value.translation.width) < 10 { popLid() }
                case .popped:
                    break
                }
            }
    }

    // MARK: - Steps

    private func openFlap() {
        guard step == .closed else { return }
        Feel.shared.flapOpen()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            flap = 1
            step = .open
        }
    }

    private func pullTubeOut() {
        guard step == .open else { return }
        Feel.shared.tubeOut()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { lift = Self.fullLift }
        withAnimation(.easeIn(duration: 0.55).delay(0.15)) { boxGone = true }
        withAnimation(.easeOut(duration: 0.25).delay(0.4)) { step = .tubeOut }
    }

    private func popLid() {
        guard step == .tubeOut, !lidOff else { return }
        Feel.shared.tubePop()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { lidOff = true }
        Task {
            try? await Task.sleep(for: .seconds(0.28))
            Feel.shared.canisterOut()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                canisterUp = true
                step = .popped
            }
            try? await Task.sleep(for: .seconds(1.5))
            model.tear()
        }
    }

    /// VoiceOver: the whole unboxing in one go.
    private func openEverything() {
        openFlap()
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            pullTubeOut()
            try? await Task.sleep(for: .seconds(0.8))
            popLid()
        }
    }
}

/// The smoky plastic tube a roll comes in, with its snap-on lid and the canister showing through.
private struct FilmTube: View {
    let film: FilmStock
    let exposures: Int
    let lidOff: Bool
    /// The canister's slid up out of the open tube.
    let canisterUp: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // The canister inside, seen through the plastic; it rises out once the lid's off.
            FilmCanister(film: film, exposures: exposures, leader: canisterUp ? 30 : 0)
                .scaleEffect(canisterUp ? 1.25 : 0.82)
                .offset(y: canisterUp ? -150 : 22)
                .zIndex(canisterUp ? 2 : 0)

            // The tube body: clear grey plastic with highlights down its curve.
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.55).opacity(0.55), location: 0),
                    .init(color: Color(white: 0.85).opacity(0.25), location: 0.3),
                    .init(color: Color(white: 0.6).opacity(0.2), location: 0.6),
                    .init(color: Color(white: 0.35).opacity(0.55), location: 1),
                ], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.45)).frame(width: 4).padding(.vertical, 18).padding(.leading, 12)
                }
                .padding(.top, 10)
                .allowsHitTesting(false)
                .opacity(canisterUp ? 0 : 1)
                .offset(y: canisterUp ? 140 : 0)

            // The snap-on lid.
            Lid()
                .frame(width: 84, height: 22)
                .rotationEffect(.degrees(lidOff ? 160 : 0))
                .offset(x: lidOff ? 120 : 0, y: lidOff ? -150 : 0)
                .opacity(lidOff ? 0 : 1)
        }
    }
}

private struct Lid: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.78), Color(white: 0.42)], startPoint: .leading, endPoint: .trailing))
            HStack(spacing: 3) {
                ForEach(0..<14, id: \.self) { _ in Rectangle().fill(.black.opacity(0.12)).frame(width: 1.5) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
    }
}
