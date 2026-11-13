import PlasticcCore
import SwiftUI

/// A 35 mm film box standing on the counter, seen a little from above and to the right: the printed front, the
/// shaded side, and the end flap on top. `flap` runs from 0 (tucked shut) to 1 (lifted open, showing the inside).
/// `inside` is drawn in the box, behind the front, so it can slide up out of the open end.
struct FilmBox<Inside: View>: View {
    let film: FilmStock
    let exposures: Int
    var flap: Double = 0
    @ViewBuilder var inside: Inside


    var body: some View {
        let brand = film.brand
        let w = BoxGeometry.front.width, h = BoxGeometry.front.height, dx = BoxGeometry.depth.width, dy = BoxGeometry.depth.height
        ZStack(alignment: .topLeading) {
            // The open end: the dark inside of the box.
            TopFace()
                .fill(Color(red: 0.12, green: 0.1, blue: 0.08))
                .overlay(TopFace().fill(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)))
                .frame(width: w + dx, height: dy)

            inside

            // The side, in shade, with the film's name running up it.
            ZStack {
                brand.sleeve
                Color.black.opacity(0.34)
                Text("\(brand.line) \(brand.speed)")
                    .font(.print(9))
                    .tracking(2)
                    .foregroundStyle(brand.ink.opacity(0.65))
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
                Grain(opacity: 0.12)
            }
            .frame(width: dx, height: h)
            .clipped()
            .transformEffect(CGAffineTransform(a: 1, b: -dy / dx, c: 0, d: 1, tx: 0, ty: 0))
            .offset(x: w, y: dy)

            BoxFront(film: film, exposures: exposures)
                .frame(width: w, height: h)
                .offset(y: dy)

            // The end flap, hinged along the back edge, lifting up and over.
            Flap(brand: brand, open: flap)
                .frame(width: w + dx, height: dy)
        }
        .frame(width: BoxGeometry.size.width, height: BoxGeometry.size.height, alignment: .topLeading)
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 12, x: 8, y: 14)
        .accessibilityElement()
        .accessibilityLabel("\(film.name), 35 millimetre film, \(exposures) exposures")
    }
}

extension FilmBox where Inside == EmptyView {
    init(film: FilmStock, exposures: Int, flap: Double = 0) {
        self.init(film: film, exposures: exposures, flap: flap) { EmptyView() }
    }
}

/// The box's proportions, shared with what's drawn inside it.
enum BoxGeometry {
    static let front = CGSize(width: 210, height: 290)
    /// How far the box's depth runs back and up.
    static let depth = CGSize(width: 30, height: 20)
    static var size: CGSize { CGSize(width: front.width + depth.width, height: front.height + depth.height) }
}

/// The top of the box as a parallelogram: front edge along the bottom, back edge shifted right.
private struct TopFace: Shape {
    func path(in rect: CGRect) -> Path {
        let dx = BoxGeometry.depth.width
        return Path { p in
            p.move(to: CGPoint(x: 0, y: rect.maxY))
            p.addLine(to: CGPoint(x: dx, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX - dx, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// The end flap. Shut, it's the box's top face; lifting, it swings up about the back edge until its plain
/// card inside faces you.
private struct Flap: View, Animatable {
    let brand: FilmBrand
    var open: Double

    /// Animated frame by frame, so the face swaps to the plain inside just as it passes upright.
    var animatableData: Double {
        get { open }
        set { open = newValue }
    }

    var body: some View {
        let angle = open * 150
        let inside = angle > 90
        TopFace()
            .fill(inside ? AnyShapeStyle(Color(red: 0.93, green: 0.9, blue: 0.84)) : AnyShapeStyle(brand.sleeve))
            .overlay(TopFace().fill(.white.opacity(inside ? 0 : 0.16)))
            .overlay(TopFace().stroke(.black.opacity(0.2), lineWidth: 0.5))
            .overlay {
                if !inside {
                    // The tuck tab's printed arrow.
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(brand.ink.opacity(0.5))
                }
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
    }
}

/// The printed front of the box: the film's colours, stripes, the big speed, and what's inside.
private struct BoxFront: View {
    let film: FilmStock
    let exposures: Int

    var body: some View {
        let brand = film.brand
        brand.sleeve
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(brand.band.opacity(1 - Double(i) * 0.25))
                            .frame(width: 420, height: 14 - CGFloat(i) * 3)
                            .rotationEffect(.degrees(-24))
                            .offset(x: -70, y: 196 + CGFloat(i) * 19)
                    }
                }
            }
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    Text(brand.line)
                        .font(.print(23))
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(brand.speed)
                        .font(.print(74))
                        .italic()
                        .padding(.top, -6)
                    Text(brand.process)
                        .font(.print(7, weight: .heavy))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.85)
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("135-\(exposures)")
                                .font(.print(16))
                                .contentTransition(.numericText())
                            Text("ISO \(brand.speed)/\(Self.din(brand.speed))°")
                                .font(.print(8, weight: .heavy))
                        }
                        Spacer()
                        VStack(spacing: 0) {
                            Text("\(exposures)")
                                .font(.print(24))
                                .contentTransition(.numericText())
                            Text("EXP").font(.print(8))
                        }
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(brand.band))
                        .foregroundStyle(brand.bandInk)
                    }
                }
                .foregroundStyle(brand.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .overlay(Grain(opacity: 0.16))
            .overlay(Sheen(strength: 0.2))
            .clipped()
    }

    /// The DIN degrees printed beside ISO speed.
    private static func din(_ speed: String) -> Int {
        guard let iso = Double(speed), iso > 0 else { return 0 }
        return Int((10 * log10(iso) + 1).rounded())
    }
}
