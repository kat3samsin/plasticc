import PlasticcCore
import SwiftUI

/// Loading your camera: drop the canister into the chamber, pull the leader across the gate to the take-up spool,
/// then the back snaps shut with the canister showing in the film window.
struct LoadFilmView: View {
    let model: RollModel

    private enum Step { case canister, thread, shut }

    @State private var step = Step.canister
    /// Resets by itself, springing the canister home, when the drag ends or the system cancels it.
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.4, dampingFraction: 0.7)))
    private var drag: CGSize = .zero
    @State private var near = false
    /// Leader pulled out of the canister, in points.
    @State private var leader: CGFloat = 34
    @State private var leaderStart: CGFloat = 34
    @State private var lastTick: CGFloat = 34
    @State private var caught = false
    @State private var spoolTurn: Double = 0
    @State private var doorShut = false
    @State private var hint = false

    private var film: FilmStock { model.film ?? .superia400 }
    private var exposures: Int { model.roll?.length.exposures ?? 24 }
    /// Where the canister waits, in bay coordinates: below the bay, centred.
    private static let rest = CGPoint(x: (FilmBay.size.width - 112) / 2, y: FilmBay.size.height + 90)
    /// The leader's length when its tongue reaches the spool.
    private static let fullLeader = FilmBay.spoolX - FilmBay.lipX - 6
    /// The film's sprocket pitch, in points: one tick per hole dragged across the gate.
    private static let pitch: CGFloat = 9

    var body: some View {
        ZStack {
            CameraBack()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.print(26))
                        .italic()
                        .swaps(on: step)
                    Text(instruction)
                        .font(.print(15, weight: .bold))
                        .opacity(0.8)
                        .swaps(on: step)
                }
                .foregroundStyle(Plastic.trim)
                .multilineTextAlignment(.center)
                .padding(.top, 40)

                ZStack(alignment: .topLeading) {
                    FilmBay(chamberLit: near, spoolTurn: spoolTurn, spoolLit: step == .thread && leader > Self.fullLeader * 0.7)

                    FilmCanister(film: film, exposures: exposures, leader: leader)
                        .scaleEffect(near ? 1.05 : 1, anchor: .topLeading)
                        .offset(x: canisterOrigin.x, y: canisterOrigin.y)
                        .gesture(step == .canister ? canisterGesture : nil)
                        .accessibilityElement()
                        .accessibilityLabel("Film canister, \(film.name)")
                        .accessibilityActions {
                            if step != .shut {
                                Button(step == .canister ? "Load" : "Thread the leader") { autoLoad() }
                            }
                        }

                    // Pull handle on the leader's tongue while threading.
                    if step == .thread {
                        hintArrow("PULL", systemImage: "chevron.right")
                            .offset(x: FilmBay.lipX + leader + 10, y: FilmBay.seat.y + 46)
                    } else if step == .canister, !near, drag == .zero {
                        hintArrow("DROP IN", systemImage: "chevron.up")
                            .offset(x: Self.rest.x + 14, y: Self.rest.y - 40)
                    }

                    BackDoor(film: film)
                        .frame(width: FilmBay.size.width + 12, height: FilmBay.size.height + 12)
                        .offset(x: -6, y: -6)
                        .rotation3DEffect(.degrees(doorShut ? 0 : -96), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.45)
                        .opacity(doorShut ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .frame(width: FilmBay.size.width, height: FilmBay.size.height + 260, alignment: .topLeading)
                .contentShape(Rectangle())
                .gesture(step == .thread ? threadGesture : nil)
                .frame(maxHeight: .infinity)
            }
        }
        // A drag the system cancelled (a call, Control Center) springs home without an end: unlight the chamber.
        .onChange(of: drag) { _, drag in if drag == .zero, near { near = false } }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { hint = true }
        }
    }

    private var title: String {
        switch step {
        case .canister: "LOAD THE FILM"
        case .thread: "THREAD THE LEADER"
        case .shut: "LOADED"
        }
    }

    private var instruction: String {
        switch step {
        case .canister: "Drop the canister into the chamber."
        case .thread: "Pull the film across to the spool."
        case .shut: "Back shut. Wind on to frame 1."
        }
    }

    private var canisterOrigin: CGPoint {
        step == .canister
            ? CGPoint(x: Self.rest.x + drag.width, y: Self.rest.y + drag.height)
            : FilmBay.seat
    }

    private func hintArrow(_ label: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .black))
            Text(label).font(.print(11)).tracking(2)
        }
        .foregroundStyle(Plastic.accent)
        .offset(x: systemImage == "chevron.right" ? (hint ? 6 : 0) : 0, y: systemImage == "chevron.up" ? (hint ? -6 : 0) : 0)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - Gestures

    private var canisterGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, drag, _ in drag = value.translation }
            .onChanged { value in
                let isNear = Self.overChamber(value.translation)
                if isNear != near {
                    withAnimation(.easeOut(duration: 0.15)) { near = isNear }
                    if isNear { Feel.shared.threshold() }
                }
            }
            .onEnded { value in
                if Self.overChamber(value.translation) { seat() }
            }
    }

    /// Whether a canister dragged this far from its rest is over the chamber.
    private static func overChamber(_ translation: CGSize) -> Bool {
        hypot(rest.x + translation.width - FilmBay.seat.x, rest.y + translation.height - FilmBay.seat.y) < 90
    }

    private var threadGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !caught else { return }
                leader = min(Self.fullLeader, max(34, leaderStart + value.translation.width))
                // A tick for every sprocket hole that crosses the gate, firmer as the film nears the spool.
                while leader - lastTick >= Self.pitch {
                    lastTick += Self.pitch
                    Feel.shared.leaderTick(tension: Double((leader - 34) / (Self.fullLeader - 34)))
                }
                while lastTick - leader >= Self.pitch { lastTick -= Self.pitch }
                if leader >= Self.fullLeader * 0.97 { catchLeader() }
            }
            .onEnded { _ in
                leaderStart = leader
            }
    }

    // MARK: - Steps

    private func seat() {
        guard step == .canister else { return }
        Feel.shared.canisterClunk()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
            step = .thread
            near = false
        }
    }

    private func catchLeader() {
        guard step == .thread, !caught else { return }
        caught = true
        Feel.shared.leaderCatch()
        withAnimation(.easeOut(duration: 0.3)) {
            leader = Self.fullLeader
            spoolTurn += 21
        }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                doorShut = true
                step = .shut
            }
            try? await Task.sleep(for: .seconds(0.3))
            Feel.shared.doorSnap()
            try? await Task.sleep(for: .seconds(1.2))
            model.load()
        }
    }

    /// VoiceOver: drop it in and thread it in one go.
    private func autoLoad() {
        seat()
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.easeInOut(duration: 0.5)) { leader = Self.fullLeader }
            catchLeader()
        }
    }
}
