import PlasticcCore
import SwiftUI

/// A 35 mm canister: metal caps with the spool's nub, a printed label in the film's colours, the DX code,
/// and the leader sticking out of the light trap.
struct FilmCanister: View {
    let film: FilmStock
    var exposures: Int = 24
    /// How much leader shows, in points; threading pulls more out.
    var leader: CGFloat = 34

    var body: some View {
        let brand = film.brand
        HStack(alignment: .center, spacing: -4) {
            VStack(spacing: 0) {
                // The spool's nub poking out of the top cap.
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.75), Color(white: 0.3)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 18, height: 7)
                cap
                ZStack {
                    brand.sleeve
                    VStack(spacing: 2) {
                        Text(brand.maker).font(.print(7)).tracking(1)
                        Text(brand.speed).font(.print(22)).italic()
                        Rectangle().fill(brand.band).frame(height: 8)
                        Text("135-\(exposures)").font(.print(7))
                        Spacer(minLength: 0)
                        DXCode().frame(height: 9)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .foregroundStyle(brand.ink)
                    // The light catching the curve of the can.
                    LinearGradient(colors: [.clear, .white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                        .blendMode(.screen)
                    LinearGradient(colors: [.black.opacity(0.25), .clear, .clear, .black.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                }
                .frame(width: 70, height: 104)
                cap
            }
            // The leader, cut with its tongue, coming out of the felt-lined lip.
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(white: 0.08)).frame(width: 6, height: 74)
                FilmStrip()
                    .frame(width: leader, height: 70)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                                      bottomTrailingRadius: 14, topTrailingRadius: 4))
                    .offset(x: 4)
            }
            .frame(width: leader + 4, alignment: .leading)
            .offset(y: 4)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
        .fixedSize()
        .accessibilityElement()
        .accessibilityLabel("\(film.name) film canister")
    }

    private var cap: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.88), Color(white: 0.38)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 74, height: 12)
    }
}

/// The silver-and-black DX checkerboard that tells a camera the film's speed.
private struct DXCode: View {
    var body: some View {
        Canvas { context, size in
            let cells = 12
            let w = size.width / CGFloat(cells)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.82)))
            for i in 0..<cells where i % 3 != 1 {
                for row in 0..<2 where (i + row) % 2 == 0 {
                    context.fill(Path(CGRect(x: CGFloat(i) * w, y: CGFloat(row) * size.height / 2, width: w, height: size.height / 2)),
                                 with: .color(Color(white: 0.1)))
                }
            }
        }
        .padding(.horizontal, 6)
    }
}

/// The little window in the back that shows whether there's film inside: a slice of the canister's label.
struct FilmWindow: View {
    let film: FilmStock?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.03))
            if let film {
                let brand = film.brand
                HStack(spacing: 6) {
                    Text(brand.speed).font(.print(11)).italic()
                    Rectangle().fill(brand.band).frame(width: 14)
                    Text(brand.maker).font(.print(7)).tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .foregroundStyle(brand.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(brand.sleeve)
                .overlay(LinearGradient(colors: [.black.opacity(0.45), .clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                .padding(3)
            }
            LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            RoundedRectangle(cornerRadius: 4).strokeBorder(Plastic.bodyEdge, lineWidth: 2)
        }
        .frame(width: 104, height: 24)
        .accessibilityHidden(true)
    }
}
