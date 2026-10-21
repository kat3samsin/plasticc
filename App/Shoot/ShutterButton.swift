import SwiftUI

/// The big shutter button. It sinks when pressed; when the film isn't wound it only gives a dead press.
struct ShutterButton: View {
    let isArmed: Bool
    let ring: Color
    /// Takes the photo; false if nothing was taken.
    let action: () async -> Bool

    var body: some View {
        Button {
            if isArmed {
                Feel.shared.shutter()
                Task { if await !action() { Feel.shared.dud() } }
            } else {
                Feel.shared.dud()
            }
        } label: {
            EmptyView()
        }
        .buttonStyle(Press(ring: ring, isArmed: isArmed))
        .accessibilityLabel("Shutter")
        .accessibilityHint(isArmed ? "Take a photo" : "Wind the film first")
    }

    private struct Press: ButtonStyle {
        let ring: Color
        let isArmed: Bool

        func makeBody(configuration: Configuration) -> some View {
            let down = configuration.isPressed
            ZStack {
                // The well in the body.
                Circle()
                    .fill(Plastic.bodyEdge)
                    .frame(width: 98, height: 98)
                    .overlay(Circle().strokeBorder(ring, lineWidth: 4).padding(-3))
                // The button cap.
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.42), Color(white: 0.16)], center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 60))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1.5).padding(4))
                    .overlay(
                        Text("PUSH")
                            .font(.print(11))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(isArmed ? 0.7 : 0.3))
                    )
                    .shadow(color: .black.opacity(down ? 0.2 : 0.6), radius: down ? 1 : 5, y: down ? 0 : 4)
                    .scaleEffect(down ? 0.93 : 1)
                    .offset(y: down ? 2 : 0)
            }
            .animation(.spring(response: 0.12, dampingFraction: 0.55), value: down)
        }
    }
}
