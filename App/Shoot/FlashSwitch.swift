import SwiftUI

/// A chunky slide switch with the ready lamp beside it: blinking while the flash charges, glowing when ready.
struct FlashSwitch: View {
    let state: RollModel.FlashState
    let ink: Color
    let onChange: (Bool) -> Void

    @State private var blink = false

    private var isOn: Bool { state != .off }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .black))
                Text("FLASH")
                    .font(.print(12))
                    .tracking(1.5)
            }
            .foregroundStyle(ink)

            HStack(spacing: 12) {
                track
                lamp
            }
        }
        .onChange(of: state) { updateBlink() }
        .onAppear { updateBlink() }
        .accessibilityElement()
        .accessibilityLabel("Flash")
        .accessibilityValue(state == .off ? "Off" : state == .charging ? "Charging" : "Ready")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
    }

    private var track: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(Plastic.bodyEdge)
                .overlay(Capsule().strokeBorder(.black.opacity(0.6), lineWidth: 1))
                // The side the knob uncovers says what the switch is set to.
                .overlay(alignment: .leading) {
                    Text("ON").font(.print(9)).foregroundStyle(Plastic.lamp.opacity(isOn ? 0.9 : 0)).padding(.leading, 12)
                }
                .overlay(alignment: .trailing) {
                    Text("OFF").font(.print(9)).foregroundStyle(.white.opacity(isOn ? 0 : 0.5)).padding(.trailing, 9)
                }
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { _ in Capsule().fill(.black.opacity(0.4)).frame(width: 2, height: 14) }
                    }
                )
                .frame(width: 44, height: 32)
                .padding(3)
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
        }
        .frame(width: 96, height: 38)
        .contentShape(Capsule())
        .onTapGesture { toggle() }
        .gesture(DragGesture(minimumDistance: 6).onEnded { value in
            if (value.translation.width > 0) != isOn { toggle() }
        })
    }

    private var lamp: some View {
        Circle()
            .fill(state == .off ? Color(red: 0.25, green: 0.12, blue: 0.06) : Plastic.lamp)
            .opacity(state == .charging ? (blink ? 1 : 0.25) : 1)
            .frame(width: 14, height: 14)
            .overlay(Circle().fill(.white.opacity(0.55)).frame(width: 4, height: 4).offset(x: -2, y: -2))
            .overlay(Circle().strokeBorder(.black.opacity(0.6), lineWidth: 1.5))
            .background(
                Circle()
                    .fill(Plastic.lamp.opacity(state == .ready ? 0.55 : 0))
                    .frame(width: 34, height: 34)
                    .blur(radius: 8)
            )
            .shadow(color: state == .ready ? Plastic.lamp : .clear, radius: 6)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { onChange(!isOn) }
        Feel.shared.click()
    }

    private func updateBlink() {
        blink = false
        guard state == .charging else { return }
        withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) { blink = true }
    }
}
