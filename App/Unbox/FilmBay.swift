import PlasticcCore
import SwiftUI

/// The inside of the Snappy with its back open: the canister chamber on the left, the film gate with its rails,
/// and the take-up spool on the right. Loading and unloading both happen here.
struct FilmBay: View {
    /// The chamber glows when a canister is held over it.
    var chamberLit = false
    /// The take-up spool's turn, in degrees of its ribs passing by.
    var spoolTurn: Double = 0
    /// The spool's slot glows while the leader's being pulled toward it.
    var spoolLit = false

    static let size = CGSize(width: 340, height: 230)
    /// Where a seated canister's top-left corner sits.
    static let seat = CGPoint(x: 8, y: 42)
    /// The leader's tongue has to reach this far right to catch on the spool.
    static let spoolX: CGFloat = 300
    /// The leader leaves the canister about here.
    static let lipX: CGFloat = seat.x + 74

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The moulded well.
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(LinearGradient(colors: [.black, Color(white: 0.22)], startPoint: .top, endPoint: .bottom), lineWidth: 5)
                )

            // Canister chamber.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(white: 0.14), lineWidth: 2))
                .frame(width: 84, height: 170)
                .shadow(color: chamberLit ? Plastic.lamp.opacity(0.9) : .clear, radius: 14)
                .offset(x: 6, y: 30)
            Text("FILM")
                .font(.print(9))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.2))
                .offset(x: 32, y: 206)

            // The film gate: an opening framed by polished rails.
            ZStack {
                Rectangle().fill(.black)
                Rectangle()
                    .strokeBorder(Color(white: 0.12), lineWidth: 1)
                    .padding(10)
            }
            .frame(width: 150, height: 104)
            .overlay(alignment: .top) { rail }
            .overlay(alignment: .bottom) { rail }
            .offset(x: 104, y: 58)

            // Take-up spool, ribbed, with a slot for the leader's tongue.
            Spool(turn: spoolTurn, lit: spoolLit)
                .frame(width: 44, height: 150)
                .offset(x: Self.spoolX - 22, y: 40)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private var rail: some View {
        Capsule()
            .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
            .frame(height: 4)
            .padding(.horizontal, -8)
    }
}

private struct Spool: View {
    let turn: Double
    let lit: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.32), Color(white: 0.1)], startPoint: .leading, endPoint: .trailing))
            // Ribs that roll past as the spool turns.
            Canvas { context, size in
                let pitch: CGFloat = 7
                let shift = CGFloat(turn.truncatingRemainder(dividingBy: Double(pitch)))
                var x = -pitch + shift
                while x < size.width + pitch {
                    let edge = abs(x - size.width / 2) / (size.width / 2)
                    context.fill(Path(CGRect(x: x, y: 8, width: 1.5, height: size.height - 16)),
                                 with: .color(.black.opacity(0.45 * (1 - edge))))
                    x += pitch
                }
            }
            .clipShape(Capsule())
            // The slot.
            Capsule()
                .fill(.black)
                .frame(width: 5, height: 86)
                .shadow(color: lit ? Plastic.lamp : .clear, radius: 8)
        }
    }
}

/// The camera's back door, hinged on the left, with the film window showing the canister once it's shut.
struct BackDoor: View {
    let film: FilmStock?

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(LinearGradient(colors: [Color(white: 0.2), Plastic.body], startPoint: .top, endPoint: .bottom))
            .overlay(Grain(opacity: 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
            .overlay {
                VStack(spacing: 14) {
                    FilmWindow(film: film)
                    HStack(spacing: 0) {
                        Text("SNAPPY").foregroundStyle(Plastic.trim)
                        Text(" 35").foregroundStyle(Plastic.accent)
                    }
                    .font(.print(15))
                    .italic()
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
    }
}
