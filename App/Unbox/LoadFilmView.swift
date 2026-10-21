import PlasticcCore
import SwiftUI

/// The back is open and the chamber's empty. Drag the canister in; it clunks into place and the door snaps shut.
struct LoadFilmView: View {
    let model: RollModel

    @State private var drag: CGSize = .zero
    @State private var seated = false
    @State private var shut = false
    @State private var near = false
    @State private var bob = false

    private var film: FilmStock { model.film ?? .superia400 }
    private var brand: FilmBrand { film.brand }
    /// Where the canister rests, relative to the chamber's centre.
    private let restOffset = CGSize(width: 0, height: 330)

    var body: some View {
        ZStack {
            CameraBack(brand: brand)

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(shut ? "LOADED" : "LOAD THE FILM")
                        .font(.print(26))
                        .italic()
                        .swaps(on: shut)
                    Text(shut ? "Wind on to frame 1." : "Drag the canister into the camera.")
                        .font(.print(15, weight: .bold))
                        .opacity(0.85)
                        .swaps(on: shut)
                }
                .foregroundStyle(brand.ink)
                .padding(.top, 36)

                ZStack {
                    Chamber(near: near, seated: seated)
                    Door(brand: brand)
                        .offset(x: shut ? 0 : 230)
                        .opacity(shut ? 1 : 0)

                    Canister(film: film, brand: brand)
                        .scaleEffect(seated ? 0.92 : (near ? 1.04 : 1))
                        .offset(seated ? .zero : CGSize(width: restOffset.width + drag.width,
                                                       height: restOffset.height + drag.height + (bob ? -6 : 0)))
                        .opacity(shut ? 0 : 1)
                        .gesture(seated ? nil : canisterGesture)
                        .accessibilityElement()
                        .accessibilityLabel("Film canister, \(film.name)")
                        .accessibilityAction(named: "Load") { seat() }
                }
                .frame(height: 300)
                .padding(.top, 50)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    private var canisterGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                let distance = hypot(restOffset.width + drag.width, restOffset.height + drag.height)
                let isNear = distance < 90
                if isNear != near {
                    near = isNear
                    if isNear { Feel.shared.threshold() }
                }
            }
            .onEnded { _ in
                if near {
                    seat()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    private func seat() {
        guard !seated else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            seated = true
            near = false
        }
        Feel.shared.canisterClunk()
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { shut = true }
            try? await Task.sleep(for: .seconds(0.22))
            Feel.shared.doorSnap()
            try? await Task.sleep(for: .seconds(0.9))
            model.load()
        }
    }
}

/// The open film chamber: a dark moulded well with a spool post and guide rails.
private struct Chamber: View {
    let near: Bool
    let seated: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(LinearGradient(colors: [.black, Color(white: 0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 6)
                )
                .shadow(color: near ? Plastic.lamp.opacity(0.8) : .clear, radius: 14)
            VStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in Capsule().fill(Color(white: 0.12)).frame(width: 110, height: 3) }
            }
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.15)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 14, height: 150)
                .opacity(seated ? 0 : 1)
            Text("FILM")
                .font(.print(10))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.25))
                .offset(y: 112)
        }
        .frame(width: 160, height: 250)
    }
}

/// A 35 mm canister: metal caps, a printed label in the film's colours, the leader sticking out.
private struct Canister: View {
    let film: FilmStock
    let brand: FilmBrand

    var body: some View {
        HStack(spacing: -4) {
            VStack(spacing: 0) {
                cap
                ZStack {
                    LinearGradient(stops: [
                        .init(color: brand.sleeve.opacity(0.75), location: 0),
                        .init(color: brand.sleeve, location: 0.35),
                        .init(color: brand.sleeve.opacity(0.65), location: 1),
                    ], startPoint: .leading, endPoint: .trailing)
                    VStack(spacing: 2) {
                        Text(brand.maker).font(.print(7)).tracking(1)
                        Text(brand.speed).font(.print(22)).italic()
                        Rectangle().fill(brand.band).frame(height: 8)
                        Text("135").font(.print(7))
                    }
                    .foregroundStyle(brand.ink)
                    LinearGradient(colors: [.clear, .white.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)
                        .blendMode(.screen)
                }
                .frame(width: 70, height: 104)
                cap
            }
            FilmStrip()
                .frame(width: 34, height: 70)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 14, topTrailingRadius: 4))
                .offset(y: 4)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
        .frame(width: 110, height: 130)
        .contentShape(Rectangle())
    }

    private var cap: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(white: 0.45), Color(white: 0.85), Color(white: 0.4)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 74, height: 12)
    }
}

/// The back door sliding shut over the chamber.
private struct Door: View {
    let brand: FilmBrand

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(white: 0.2), Plastic.body], startPoint: .top, endPoint: .bottom))
            .overlay(
                VStack(spacing: 8) {
                    ForEach(0..<8, id: \.self) { _ in Capsule().fill(.black.opacity(0.35)).frame(width: 120, height: 2) }
                }
            )
            .overlay(
                Text("\(brand.line) \(brand.speed)")
                    .font(.print(11))
                    .tracking(1)
                    .foregroundStyle(brand.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(brand.sleeve, in: Capsule())
            )
            .frame(width: 172, height: 262)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }
}
