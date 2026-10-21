import SwiftUI

/// The thumbwheel: a ribbed plastic cylinder poking out of the body. Drag it either way; it ratchets,
/// so progress carries across drags. A click on every rib, a firm stop, then `onWound`.
struct WindWheel: View {
    let isEnabled: Bool
    let onWound: () -> Void

    @State private var progress: CGFloat = 0
    /// The cylinder's turn, in points of surface travel.
    @State private var spin: CGFloat = 0
    @State private var lastTranslation: CGFloat = 0
    @State private var nudge = false

    private let travel: CGFloat = 132
    private let ribSpacing: CGFloat = 11
    /// Ratchet teeth are coarser than the ribs: about eight notches per frame.
    private let notchSpacing: CGFloat = 16.5
    private let size = CGSize(width: 164, height: 58)

    var body: some View {
        Canvas { context, size in
            let radius = size.width / 2
            let circumference = 2 * .pi * radius
            let ribCount = Int(circumference / ribSpacing)
            for i in 0..<ribCount {
                // Where this rib sits around the cylinder, as an angle from the front.
                let along = (CGFloat(i) * ribSpacing + spin).truncatingRemainder(dividingBy: circumference)
                let theta = along / radius
                let facing = cos(theta)
                guard facing > 0.05 else { continue }
                let x = radius + radius * sin(theta)
                let width = max(0.8, 4.2 * facing)
                let rib = CGRect(x: x - width / 2, y: 3, width: width, height: size.height - 6)
                context.fill(Path(roundedRect: rib, cornerRadius: width / 2), with: .color(.black.opacity(0.35 + 0.35 * facing)))
                // A glint along each rib's lit edge.
                let glint = CGRect(x: x - width / 2, y: 3, width: max(0.5, width * 0.35), height: size.height - 6)
                context.fill(Path(glint), with: .color(.white.opacity(0.18 * facing)))
            }
        }
        .frame(width: size.width, height: size.height)
        .background(
            // Round plastic catching light in the middle, falling away to the edges.
            LinearGradient(stops: [
                .init(color: Color(white: 0.06), location: 0),
                .init(color: Color(white: 0.30), location: 0.42),
                .init(color: Color(white: 0.36), location: 0.5),
                .init(color: Color(white: 0.22), location: 0.62),
                .init(color: Color(white: 0.05), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .overlay(
            // The body's lip shades the wheel top and bottom.
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Plastic.bodyEdge, lineWidth: 3)
        }
        .shadow(color: isEnabled ? Plastic.lamp.opacity(nudge ? 0.55 : 0.0) : .clear, radius: 8)
        .contentShape(Rectangle().inset(by: -16))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let delta = value.translation.width - lastTranslation
                    lastTranslation = value.translation.width
                    guard isEnabled else { return }
                    turn(by: delta)
                }
                .onEnded { _ in lastTranslation = 0 }
        )
        .onAppear { startNudge() }
        .onChange(of: isEnabled) { startNudge() }
        .accessibilityElement()
        .accessibilityLabel("Wind wheel")
        .accessibilityHint(isEnabled ? "Wind to the next frame" : "Wound and ready")
        .accessibilityAction {
            if isEnabled { turn(by: travel) }
        }
    }

    private func startNudge() {
        nudge = false
        guard isEnabled else { return }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { nudge = true }
    }

    private func turn(by delta: CGFloat) {
        let notchesBefore = Int(progress / notchSpacing)
        spin += delta
        progress += abs(delta)
        if progress >= travel {
            progress = 0
            Feel.shared.windStop()
            onWound()
        } else if Int(progress / notchSpacing) > notchesBefore {
            Feel.shared.windTick(tension: Double(progress / travel))
        }
    }
}
