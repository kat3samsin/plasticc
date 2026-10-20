import SwiftUI

/// The thumb wheel. Drag it either way; it ratchets, so progress carries across drags.
/// A click on every rib, a clunk at the stop, then `onWound`.
struct WindWheel: View {
    let isEnabled: Bool
    let onWound: () -> Void

    @State private var progress: CGFloat = 0
    @State private var ribOffset: CGFloat = 0
    @State private var lastTranslation: CGFloat = 0

    private let travel: CGFloat = 120
    private let ribSpacing: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            var x = ribOffset.truncatingRemainder(dividingBy: ribSpacing) - ribSpacing
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 4, height: size.height)), with: .color(.black.opacity(0.55)))
                x += ribSpacing
            }
        }
        .frame(width: 150, height: 48)
        .background(Color(white: 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isEnabled ? Plastic.trim : .clear, lineWidth: 2)
        }
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
        .accessibilityElement()
        .accessibilityLabel("Wind wheel")
        .accessibilityHint(isEnabled ? "Wind to the next frame" : "")
        .accessibilityAction {
            if isEnabled { turn(by: travel) }
        }
    }

    private func turn(by delta: CGFloat) {
        let ribsBefore = Int(progress / ribSpacing)
        ribOffset += delta
        progress += abs(delta)
        if progress >= travel {
            progress = 0
            Feel.shared.clunk()
            onWound()
        } else if Int(progress / ribSpacing) > ribsBefore {
            Feel.shared.notch()
        }
    }
}
