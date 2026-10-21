import PlasticcCore
import SwiftUI

/// Under the safelight: each print rocks in the developer tray and comes up out of the white.
struct DarkroomView: View {
    let model: RollModel
    @State private var emerge = 0.0

    private var total: Int { model.roll?.shots.count ?? 0 }

    var body: some View {
        ZStack {
            Paper.safelight.ignoresSafeArea()
            // The safelight lamp's pool of light.
            RadialGradient(colors: [Color(red: 0.95, green: 0.18, blue: 0.1).opacity(0.55), .clear],
                           center: .top, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
            Grain(opacity: 0.2).ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("DARKROOM")
                        .font(.print(13))
                        .tracking(4)
                        .opacity(0.7)
                    Text("Developing \(min(total, model.developedCount + 1)) of \(total)")
                        .font(.typed(22))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.68))
                .padding(.top, 50)

                Spacer()

                Tray(print: model.latestPrint, emerge: emerge)

                Spacer()

                if model.developFailed {
                    Button {
                        Task { await model.develop() }
                    } label: {
                        Text("The lab hit a snag. Try again")
                            .font(.print(16, weight: .heavy))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color(red: 1, green: 0.72, blue: 0.64), in: Capsule())
                            .foregroundStyle(Paper.safelight)
                    }
                }

                ProgressStrip(done: model.developedCount, total: total)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
        .onChange(of: model.developedCount) {
            emerge = 0
            withAnimation(.easeOut(duration: 0.5)) { emerge = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Developing \(model.developedCount) of \(total) prints")
    }
}

/// A developer tray with a print in it and the liquid rocking over it.
private struct Tray: View {
    let print: UIImage?
    let emerge: Double

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.08))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08), lineWidth: 3))
                    .shadow(color: .black.opacity(0.6), radius: 16, y: 10)

                // The print, coming up out of white under red light.
                ZStack {
                    Color.white
                    if let print {
                        Image(uiImage: print)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .opacity(emerge)
                            .blur(radius: (1 - emerge) * 6)
                    }
                }
                .colorMultiply(Color(red: 1, green: 0.42, blue: 0.36))
                .frame(width: 200, height: 260)
                .rotationEffect(.degrees(sin(t * 1.3) * 1.5))
                .offset(x: sin(t * 0.9) * 4)

                // Liquid sheen sliding back and forth.
                LinearGradient(colors: [.clear, .white.opacity(0.12), .clear],
                               startPoint: UnitPoint(x: 0.5 + sin(t * 0.9) * 0.6, y: 0),
                               endPoint: UnitPoint(x: 0.9 + sin(t * 0.9) * 0.6, y: 1))
                    .blendMode(.screen)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(10)
            }
            .frame(width: 270, height: 330)
        }
    }
}

/// One square per frame, filling in as prints come out.
private struct ProgressStrip: View {
    let done: Int
    let total: Int

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 12)
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < done ? Color(red: 1, green: 0.72, blue: 0.64) : .black.opacity(0.35))
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .animation(.easeOut(duration: 0.3), value: done)
            }
        }
    }
}
