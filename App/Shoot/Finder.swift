import PlasticcCore
import SwiftUI

/// The viewfinder window: the scene through a cheap plastic eyepiece, with glare, darkened corners
/// and a bright frame line. It never shows a photo you've taken.
struct Finder: View {
    let model: RollModel
    let blink: Bool
    @AppStorage(Settings.printFormatKey) private var format = PrintFormat.classic

    var body: some View {
        ZStack {
            Color.black
            content
            // Plastic finder optics fall off toward the corners.
            RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: 90, endRadius: 260)
                .allowsHitTesting(false)
            // The bright frame line, in the print's shape: what the lab will crop to.
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.white.opacity(model.multi ? 0 : 0.55), lineWidth: 1.2)
                .aspectRatio(1 / format.ratio, contentMode: .fit)
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
            if model.multi { multiBanner }
            if model.isCapturing { saving }
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

    /// While the phone saves the full-size photo: the finder dims and a lamp pulses, so the shot feels taken.
    private var saving: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 8) {
                SavingDots()
                Text("SAVING FRAME")
                    .font(.print(10))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    /// MULTI on: the finder says plainly that the next shot lands on the last frame.
    private var multiBanner: some View {
        VStack {
            HStack(spacing: 6) {
                Text("2×").font(.print(13))
                Text("MULTIPLE EXPOSURE · FRAME \(model.roll?.shots.count ?? 0)")
                    .font(.print(9))
                    .tracking(1)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Plastic.lamp))
            .shadow(color: Plastic.lamp.opacity(0.7), radius: 8)
            // Hung on the frame line like a tag, rather than floating just under it.
            .padding(.top, 4)
            Spacer()
        }
        // Behind the tag, so the frame line runs under it rather than through its lettering.
        .background {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Plastic.lamp, lineWidth: 2)
                .aspectRatio(1 / format.ratio, contentMode: .fit)
                .padding(18)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var content: some View {
        if model.cameraAllowed == false {
            PermissionView()
        } else if let live = model.camera as? LiveCamera {
            CameraPreview(session: live.session, front: model.isFront)
        } else if let sample = model.camera as? SampleCamera, let image = sample.finderImage, model.shotCount >= 0 {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

/// Three lamp dots lighting in turn.
private struct SavingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Plastic.lamp)
                    .frame(width: 7, height: 7)
                    .opacity(i == phase ? 1 : 0.25)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.18))
                phase = (phase + 1) % 3
            }
        }
    }
}
