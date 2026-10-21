import SwiftUI

/// The viewfinder window: the scene through a cheap plastic eyepiece, with glare, darkened corners
/// and a bright frame line. It never shows a photo you've taken.
struct Finder: View {
    let model: RollModel
    let blink: Bool

    var body: some View {
        ZStack {
            Color.black
            content
            // Plastic finder optics fall off toward the corners.
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 90, endRadius: 260)
                .allowsHitTesting(false)
            // The bright frame line.
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(0.55), lineWidth: 1.2)
                .padding(18)
                .overlay(alignment: .center) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                }
            // Glass glare.
            LinearGradient(stops: [
                .init(color: .white.opacity(0.16), location: 0),
                .init(color: .white.opacity(0.03), location: 0.3),
                .init(color: .clear, location: 0.5),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.screen)
            Color.black.opacity(blink ? 1 : 0)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.black.opacity(0.8), lineWidth: 2)
        }
        .padding(10)
        .background(
            // The moulded bezel around the eyepiece.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.2), Plastic.bodyEdge], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
        )
        .accessibilityHidden(model.cameraAllowed != false)
    }

    @ViewBuilder private var content: some View {
        if model.cameraAllowed == false {
            PermissionView()
        } else if let live = model.camera as? LiveCamera {
            CameraPreview(session: live.session)
        } else if let sample = model.camera as? SampleCamera, let image = sample.finderImage, model.shotCount >= 0 {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}
