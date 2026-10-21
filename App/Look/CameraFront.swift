import SwiftUI

/// The front of the Snappy 35: the film's sleeve with the lens, the flash window and the little finder.
struct CameraFront: View {
    let brand: FilmBrand
    let exposures: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(brand.sleeve)
                .overlay(Grain(opacity: 0.16))
                .overlay(alignment: .bottom) {
                    // The band round the bottom of the sleeve.
                    Rectangle().fill(brand.band).frame(height: 54)
                        .overlay(
                            Text("SINGLE-USE CAMERA · \(exposures) EXP · WITH FLASH")
                                .font(.print(10))
                                .tracking(1.2)
                                .foregroundStyle(brand.bandInk)
                        )
                        .padding(.bottom, 30)
                }
                .overlay(Sheen(strength: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    // Flash window: a ribbed reflector behind clear plastic.
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            HStack(spacing: 3) {
                                ForEach(0..<9, id: \.self) { _ in Rectangle().fill(.black.opacity(0.12)).frame(width: 2) }
                            }
                            .padding(6)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Plastic.bodyEdge, lineWidth: 4))
                        .frame(width: 92, height: 44)
                    Spacer()
                    // The finder's front window.
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.3, blue: 0.35), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Plastic.bodyEdge, lineWidth: 3))
                        .frame(width: 48, height: 34)
                }
                .padding(.horizontal, 26)
                .padding(.top, 26)

                Lens()
                    .frame(width: 150, height: 150)
                    .padding(.top, 14)

                VStack(spacing: 2) {
                    Text(brand.maker)
                        .font(.print(14))
                        .tracking(4)
                    Text(brand.line)
                        .font(.print(30))
                        .italic()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(brand.speed)
                        .font(.print(44))
                        .italic()
                }
                .foregroundStyle(brand.ink)
                .padding(.top, 18)
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 14, y: 10)
        .accessibilityElement()
        .accessibilityLabel("Snappy 35 single-use camera, \(brand.maker) \(brand.line) \(brand.speed)")
    }
}

/// A plastic lens in a moulded barrel: dark glass, coloured reflections, a bright glint.
private struct Lens: View {
    var body: some View {
        ZStack {
            Circle().fill(Plastic.bodyEdge)
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.28), Color(white: 0.08)], center: .center, startRadius: 4, endRadius: 70))
                .padding(14)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.12, green: 0.15, blue: 0.3), .black], center: .init(x: 0.45, y: 0.45), startRadius: 2, endRadius: 40))
                .padding(42)
            // Coating reflections.
            Circle()
                .trim(from: 0.05, to: 0.22)
                .stroke(Color(red: 0.6, green: 0.3, blue: 0.9).opacity(0.5), lineWidth: 5)
                .padding(48)
            Circle()
                .trim(from: 0.55, to: 0.68)
                .stroke(Color(red: 0.3, green: 0.9, blue: 0.6).opacity(0.35), lineWidth: 4)
                .padding(50)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 10, height: 10)
                .offset(x: -14, y: -16)
                .blur(radius: 1)
            Circle().strokeBorder(.white.opacity(0.08), lineWidth: 2).padding(14)
        }
    }
}
