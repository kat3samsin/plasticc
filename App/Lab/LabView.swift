import PlasticcCore
import SwiftUI

/// The roll is at the lab: a kraft photo envelope with your order on it, until the prints are ready.
struct LabView: View {
    let model: RollModel
    @State private var rang = false
    @State private var lift = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let ready = model.roll?.isReady(at: context.date) == true
            ZStack {
                PaperBackground(color: Color(red: 0.90, green: 0.84, blue: 0.74))
                VStack(spacing: 26) {
                    Text(ready ? "YOUR PRINTS ARE READY" : "AT THE LAB")
                        .font(.print(24))
                        .foregroundStyle(Paper.ink)
                        .padding(.top, 34)
                        .swaps(on: ready)

                    Envelope(roll: model.roll, film: model.film, ready: ready)
                        .rotationEffect(.degrees(-2))
                        .offset(y: lift ? -6 : 0)
                        .onTapGesture { if ready { open() } }
                        .accessibilityAddTraits(ready ? .isButton : [])
                        .accessibilityHint(ready ? "Open the envelope" : "")
                        .accessibilityAction { if ready { open() } }

                    if ready {
                        Button(action: open) {
                            Text("Open the envelope")
                                .font(.print(18, weight: .heavy))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                                .background(Paper.stampRed, in: Capsule())
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if let readyAt = model.roll?.readyAt {
                        VStack(spacing: 4) {
                            Text(countdown(to: readyAt, from: context.date))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                            Text("We'll let you know when they're done.")
                                .font(.typed(14))
                                .opacity(0.7)
                        }
                        .foregroundStyle(Paper.ink)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
            }
            .onChange(of: ready) { _, now in ring(now) }
            .onAppear { ring(ready) }
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: ready)
        }
    }

    private func ring(_ ready: Bool) {
        guard ready, !rang else { return }
        rang = true
        Feel.shared.labBell()
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { lift = true }
    }

    private func open() {
        Feel.shared.envelope()
        Task { await model.develop() }
    }

    private func countdown(to date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

/// A one-hour-photo envelope: kraft paper, a flap, the lab's stamp, your order typed and scrawled on.
private struct Envelope: View {
    let roll: Roll?
    let film: FilmStock?
    let ready: Bool

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PLASTICC")
                                .font(.print(26))
                            Text("PHOTO LAB · PRINTS & PROCESSING")
                                .font(.print(9, weight: .heavy))
                                .tracking(1)
                        }
                        .foregroundStyle(Paper.stampRed)
                        Spacer()
                    }
                    .padding(.top, 54)

                    field("FILM", film?.name ?? "")
                    field("EXP.", "\(roll?.length.exposures ?? 0)")
                    field("PRINTS", "4×6 GLOSSY · 1 SET")
                    HStack(alignment: .firstTextBaseline) {
                        Text("READY")
                            .font(.typed(13))
                            .foregroundStyle(Paper.fadedInk)
                        Text(roll?.readyAt.map { Self.time.string(from: $0) } ?? "")
                            .font(.marker(24))
                            .foregroundStyle(Color(red: 0.12, green: 0.2, blue: 0.55))
                            .rotationEffect(.degrees(-3))
                    }
                    Spacer(minLength: 0)
                    Barcode()
                        .frame(height: 34)
                        .opacity(0.8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

                OneHourStamp()
                    .rotationEffect(.degrees(14))
                    .padding(.top, 196)
                    .padding(.trailing, 26)
                    .opacity(ready ? 0.9 : 0.75)
            }
            .frame(width: 300, height: 360)
            .background(Paper.kraft)
            .overlay(alignment: .top) { Flap() }

            // The claim-check stub.
            HStack {
                Text("CLAIM CHECK")
                    .font(.print(10, weight: .heavy))
                    .tracking(1.5)
                Spacer()
                Text("Nº \(String(format: "%04d", (roll?.shots.first?.seed ?? 0) % 10000))")
                    .font(.typed(14))
            }
            .foregroundStyle(Paper.ink.opacity(0.75))
            .padding(.horizontal, 22)
            .frame(width: 300, height: 46)
            .background(Paper.kraft)
            .overlay(alignment: .top) {
                Line().stroke(Paper.kraftDark, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(height: 1)
            }
        }
        .overlay(Grain(opacity: 0.22, blend: .multiply))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo lab envelope. \(film?.name ?? ""), \(roll?.length.exposures ?? 0) exposures.")
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.typed(13))
                .foregroundStyle(Paper.fadedInk)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.typed(15))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paper.kraftDark.opacity(0.5)).frame(height: 1).offset(y: 4)
        }
    }
}

private struct Flap: View {
    var body: some View {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: 300, y: 0))
            p.addLine(to: CGPoint(x: 150, y: 44))
            p.closeSubpath()
        }
        .fill(Paper.kraftDark.opacity(0.55))
        .frame(width: 300, height: 44)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
    }
}

private struct OneHourStamp: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Paper.stampRed, lineWidth: 3)
            Circle().strokeBorder(Paper.stampRed, lineWidth: 1).padding(6)
            VStack(spacing: 0) {
                Text("1")
                    .font(.print(30))
                Text("HOUR")
                    .font(.print(10))
                    .tracking(2)
            }
            .foregroundStyle(Paper.stampRed)
        }
        .frame(width: 74, height: 74)
    }
}

private struct Barcode: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var rng = SeededRandom(seed: 417)
            while x < size.width {
                let w = CGFloat([1, 1, 2, 3].randomElement(using: &rng)!)
                context.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(Paper.ink))
                x += w + CGFloat([1, 2, 2, 3].randomElement(using: &rng)!)
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}
