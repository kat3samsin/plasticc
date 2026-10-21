import SwiftUI

/// The back of the Snappy 35: black plastic body wrapped in the film's printed cardboard sleeve.
struct CameraBack: View {
    let brand: FilmBrand

    var body: some View {
        ZStack {
            Plastic.body
            Grain(opacity: 0.1)
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(brand.sleeve)
                .overlay(Grain(opacity: 0.16))
                .overlay(SleevePrint(brand: brand))
                .overlay(Sheen(strength: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(.black.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.5), radius: 3)
        }
        .ignoresSafeArea()
    }
}

/// Graphics printed on the sleeve: speed lines behind everything, like a cheerful 90s box.
private struct SleevePrint: View {
    let brand: FilmBrand

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Diagonal speed stripes across the lower corner.
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(brand.band.opacity(0.9 - Double(i) * 0.18))
                        .frame(width: geo.size.width * 1.6, height: 10 + CGFloat(i) * 3)
                        .rotationEffect(.degrees(-22))
                        .offset(x: geo.size.width * 0.15, y: geo.size.height * (0.47 + Double(i) * 0.03))
                }
                // A large faded film speed, like the number on a box.
                Text(brand.speed)
                    .font(.print(220))
                    .italic()
                    .foregroundStyle(brand.ink.opacity(0.07))
                    .offset(x: geo.size.width * 0.28, y: geo.size.height * 0.36)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
