import SwiftUI

/// The toy camera's multi-exposure button: press it after a shot and the next wind cocks the shutter without moving
/// the film, so the next shot lands on the same frame. It pops back up on its own after that second shot. Pressed when it
/// can't be used, it says why.
struct MultiSwitch: View {
    let isOn: Bool
    let isEnabled: Bool
    /// Why it can't be pressed now, shown briefly after a refused press.
    let blockedReason: String?
    let ink: Color
    let onChange: (Bool) -> Void

    @State private var shownReason: String?
    @State private var hideReason: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            key
            VStack(alignment: .leading, spacing: 1) {
                Text("MULTI")
                    .font(.print(12))
                    .tracking(1.5)
                    .foregroundStyle(isOn ? Plastic.lamp : ink)
                Text(isOn ? "ON" : "OFF")
                    .font(.print(9))
                    .tracking(1)
                    .foregroundStyle(isOn ? Plastic.lamp : ink.opacity(0.45))
            }
        }
        // Printed just under the key, out of the layout, so the row keeps its height when nothing's shown.
        .overlay(alignment: .topLeading) {
            Text(shownReason ?? " ")
                .font(.print(8, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Plastic.lamp.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
                .opacity(shownReason == nil ? 0 : 1)
                .offset(y: 44)
        }
        .accessibilityElement()
        .accessibilityLabel("Multiple exposure")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isEnabled ? (isOn ? "Turn off before winding" : "Put the next shot on this frame")
                                     : (blockedReason?.capitalized ?? "Available after a shot, before you wind"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
    }

    private var key: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Plastic.bodyEdge)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isOn ? Plastic.lamp : .black.opacity(0.6), lineWidth: isOn ? 2 : 1))
            // The key sits proud when off and sinks into the well when pressed in.
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(white: isOn ? 0.3 : 0.5), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text("2×")
                        .font(.print(15))
                        .foregroundStyle(isOn ? Plastic.lamp : .white.opacity(isEnabled ? 0.75 : 0.35))
                )
                .padding(3)
                .shadow(color: .black.opacity(isOn ? 0.2 : 0.5), radius: isOn ? 0.5 : 1.5, y: isOn ? 0 : 1.5)
                .offset(y: isOn ? 1 : 0)
        }
        .frame(width: 52, height: 40)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
    }

    private func toggle() {
        guard isEnabled else {
            Feel.shared.locked()
            show(blockedReason)
            return
        }
        show(nil)
        withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { onChange(!isOn) }
        Feel.shared.click()
    }

    private func show(_ reason: String?) {
        hideReason?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { shownReason = reason }
        guard reason != nil else { return }
        hideReason = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.3)) { shownReason = nil }
        }
    }
}
