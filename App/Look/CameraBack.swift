import SwiftUI

/// The back of your Snappy 35: charcoal plastic with a pebbled grip and a moulded panel.
/// The same camera on every roll; only the film inside changes.
struct CameraBack: View {
    var body: some View {
        ZStack {
            Plastic.bodyEdge
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.16), Plastic.body, Color(white: 0.085)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Pebbling().opacity(0.5))
                .overlay(Grain(opacity: 0.12))
                .overlay(
                    // The raised panel the controls sit on.
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Plastic.panel.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(LinearGradient(colors: [.white.opacity(0.1), .black.opacity(0.5)],
                                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 18)
                )
                .overlay(Sheen(strength: 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .shadow(color: .black.opacity(0.6), radius: 3)
        }
        .ignoresSafeArea()
    }
}

/// The fine pebbled texture of moulded grip plastic, drawn once as a tile.
private struct Pebbling: View {
    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let tile: UIImage = {
        let step: CGFloat = 5, rows = 8
        let size = CGSize(width: step * 8, height: step * 0.87 * CGFloat(rows))
        return UIGraphicsImageRenderer(size: size).image { ctx in
            for row in 0..<rows {
                let y = CGFloat(row) * step * 0.87
                var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                while x < size.width {
                    ctx.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
                    ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 2.2, height: 2.2))
                    ctx.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
                    ctx.cgContext.fillEllipse(in: CGRect(x: x + 0.6, y: y + 0.9, width: 2.2, height: 2.2))
                    x += step
                }
            }
        }
    }()
}
