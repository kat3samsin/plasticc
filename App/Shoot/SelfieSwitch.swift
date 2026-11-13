import SwiftUI

/// A little round toggle that swaps to the selfie camera, like the mirror some single-use cameras carry by the lens.
struct SelfieSwitch: View {
    let isOn: Bool
    let ink: Color
    let onChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Plastic.bodyEdge)
                    .overlay(Circle().strokeBorder(isOn ? Plastic.lamp : .black.opacity(0.6), lineWidth: isOn ? 2 : 1))
                Circle()
                    .fill(LinearGradient(colors: [Color(white: isOn ? 0.3 : 0.5), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
                    .padding(3)
                    .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isOn ? Plastic.lamp : .white.opacity(0.75))
            }
            .frame(width: 44, height: 44)
            Text("SELFIE")
                .font(.print(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(isOn ? Plastic.lamp : ink.opacity(0.6))
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .accessibilityElement()
        .accessibilityLabel("Selfie camera")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { onChange(!isOn) }
        Feel.shared.click()
    }
}
