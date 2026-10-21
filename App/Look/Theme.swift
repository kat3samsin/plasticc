import PlasticcCore
import SwiftUI

/// The Snappy 35's plastic and the paper things around it. The camera is yours to keep, so it wears its own
/// colours on every roll: charcoal, a cream panel and orange accents.
enum Plastic {
    static let body = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let bodyEdge = Color(red: 0.05, green: 0.05, blue: 0.06)
    /// The moulded panel on the back, a shade lighter than the body.
    static let panel = Color(red: 0.16, green: 0.155, blue: 0.16)
    /// Cream lettering and trim on the charcoal.
    static let trim = Color(red: 0.96, green: 0.93, blue: 0.84)
    /// The Snappy's orange: shutter ring, stripe, lettering accents.
    static let accent = Color(red: 0.95, green: 0.42, blue: 0.13)
    static let dark = Color(red: 0.07, green: 0.07, blue: 0.08)
    /// The frame counter's digits and the flash-ready lamp.
    static let counter = Color(red: 1.0, green: 0.42, blue: 0.10)
    static let lamp = Color(red: 1.0, green: 0.55, blue: 0.12)
}

enum Paper {
    static let cream = Color(red: 0.95, green: 0.92, blue: 0.86)
    static let kraft = Color(red: 0.80, green: 0.66, blue: 0.47)
    static let kraftDark = Color(red: 0.55, green: 0.42, blue: 0.27)
    static let ink = Color(red: 0.16, green: 0.14, blue: 0.13)
    static let fadedInk = Color(red: 0.16, green: 0.14, blue: 0.13).opacity(0.62)
    static let stampRed = Color(red: 0.80, green: 0.15, blue: 0.13)
    static let stampGreen = Color(red: 0.12, green: 0.52, blue: 0.30)
    static let table = Color(red: 0.36, green: 0.25, blue: 0.18)
    static let safelight = Color(red: 0.42, green: 0.04, blue: 0.03)
}

/// How a film's box and canister are printed.
struct FilmBrand {
    let maker: String
    let line: String
    let speed: String
    let blurb: String
    /// What's printed under the name: the kind of film and how it's processed.
    let process: String
    /// The box's main colour.
    let sleeve: Color
    /// The stripe across it.
    let band: Color
    /// Lettering printed on the sleeve.
    let ink: Color
    /// Lettering printed on the band.
    let bandInk: Color
}

extension FilmStock {
    var brand: FilmBrand {
        switch id {
        case "superia400":
            FilmBrand(maker: "FUJIFILM", line: "SUPERIA X-TRA", speed: "400",
                      blurb: "Cool and punchy. Green shadows, bright blues.",
                      process: "COLOR NEGATIVE FILM · C-41",
                      sleeve: Color(red: 0.0, green: 0.52, blue: 0.29), band: Color(red: 0.86, green: 0.10, blue: 0.16),
                      ink: .white, bandInk: .white)
        case "portra400":
            FilmBrand(maker: "KODAK", line: "PORTRA", speed: "400",
                      blurb: "Soft and warm. Creamy, kind to skin.",
                      process: "PROFESSIONAL COLOR NEGATIVE · C-41",
                      sleeve: Color(red: 0.99, green: 0.74, blue: 0.04), band: Color(red: 0.82, green: 0.12, blue: 0.10),
                      ink: Color(red: 0.12, green: 0.08, blue: 0.06), bandInk: .white)
        case "ektar100":
            FilmBrand(maker: "KODAK", line: "EKTAR", speed: "100",
                      blurb: "Vivid. Deep reds, rich blues, fine grain.",
                      process: "PROFESSIONAL COLOR NEGATIVE · C-41",
                      sleeve: Color(red: 0.78, green: 0.1, blue: 0.12), band: Color(red: 0.99, green: 0.76, blue: 0.06),
                      ink: .white, bandInk: Color(red: 0.15, green: 0.05, blue: 0.03))
        default:
            FilmBrand(maker: "ILFORD", line: "HP5 PLUS", speed: "400",
                      blurb: "Black and white. Grainy, deep blacks.",
                      process: "BLACK & WHITE NEGATIVE FILM",
                      sleeve: Color(red: 0.10, green: 0.10, blue: 0.10), band: Color(white: 0.94),
                      ink: .white, bandInk: Color(white: 0.08))
        }
    }
}

extension Font {
    /// Chunky printed lettering, like a sleeve or a box.
    static func print(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The lab's typewriter.
    static func typed(_ size: CGFloat) -> Font {
        .custom("AmericanTypewriter", size: size)
    }

    /// Felt-tip on an envelope.
    static func marker(_ size: CGFloat) -> Font {
        .custom("Noteworthy-Bold", size: size)
    }
}

/// Fine noise laid over flat colour so plastic, card and paper don't look like pixels.
struct Grain: View {
    var opacity: Double = 0.12
    var blend: BlendMode = .overlay

    var body: some View {
        Image(uiImage: Self.tile)
            .resizable(resizingMode: .tile)
            .blendMode(blend)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let tile: UIImage = {
        let size = 160
        var rng = SystemRandomNumberGenerator()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = 1
            return f
        }())
        return renderer.image { ctx in
            for y in 0..<size {
                for x in 0..<size {
                    let v = CGFloat(UInt8.random(in: 0...255, using: &rng)) / 255
                    ctx.cgContext.setFillColor(gray: v, alpha: 1)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
}

/// A soft diagonal sheen, like light across moulded plastic or a glossy sleeve.
struct Sheen: View {
    var strength: Double = 0.18

    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(strength), location: 0),
            .init(color: .white.opacity(0), location: 0.35),
            .init(color: .white.opacity(strength * 0.4), location: 0.62),
            .init(color: .white.opacity(0), location: 0.8),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

/// Cream paper with grain: the film counter, the lab, the settings card.
struct PaperBackground: View {
    var color = Paper.cream

    var body: some View {
        ZStack {
            color
            RadialGradient(colors: [.white.opacity(0.25), .clear], center: .top, startRadius: 0, endRadius: 600)
            Grain(opacity: 0.18, blend: .multiply)
        }
        .ignoresSafeArea()
    }
}

/// A warm wooden table top: where you open a new roll and sort your prints.
struct Table: View {
    var body: some View {
        ZStack {
            Paper.table
            Canvas { context, size in
                var rng = SeededRandom(seed: 88)
                var y: CGFloat = 0
                while y < size.height {
                    let h = CGFloat(2 + rng.unit() * 7)
                    let shade = rng.unit() < 0.5 ? Color.black.opacity(0.06 + rng.unit() * 0.08) : Color.white.opacity(0.03 + rng.unit() * 0.04)
                    context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: h)), with: .color(shade))
                    y += h + CGFloat(rng.unit() * 6)
                }
            }
            RadialGradient(colors: [.white.opacity(0.12), .black.opacity(0.35)], center: .center, startRadius: 80, endRadius: 520)
            Grain(opacity: 0.15)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Swaps a line of text when `value` changes: the new one fades up, the old one goes at once,
    /// so two different lines never cross-fade over each other.
    func swaps<V: Hashable>(on value: V) -> some View {
        id(value).transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .identity))
    }
}
