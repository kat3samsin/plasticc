import PlasticcCore
import SwiftUI

/// The prints, fresh out of the envelope, spread on the table. Swipe right to keep one (it goes to Photos),
/// left to toss it. Tap a print to see it full screen; hold it to turn it over.
struct ReviewView: View {
    let model: RollModel

    @State private var drag: CGSize = .zero
    @State private var flipped = false
    @State private var flying: Verdict?
    @State private var crossed = false
    @State private var images: [Int: UIImage] = [:]
    /// The print open full screen, if any.
    @State private var viewing: Int?

    private let threshold: CGFloat = 110

    private var roll: Roll? { model.roll }
    /// Prints still to sort, in the order they were shot.
    private var pending: [Int] {
        (roll?.shots.indices).map { Array($0) }?.filter { roll?.shots[$0].verdict == nil } ?? []
    }
    private var kept: Int { roll?.shots.filter { $0.verdict == .keep }.count ?? 0 }

    var body: some View {
        ZStack {
            Table()

            VStack(spacing: 18) {
                header
                    .padding(.top, 20)

                Spacer(minLength: 0)

                ZStack {
                    // The next two prints wait underneath, a little askew.
                    ForEach(Array(pending.prefix(3).enumerated().reversed()), id: \.element) { depth, index in
                        card(depth: depth, index: index)
                    }
                }
                .frame(height: 470)

                Spacer(minLength: 0)

                buttons
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 20)
        }
        .alert("Plasticc can't save to Photos", isPresented: denied) {
            Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Allow adding photos in Settings to keep your prints. This one stays in the pile.")
        }
        .alert("This print didn't come out", isPresented: damaged) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The lab couldn't save this one to Photos. You can toss it.")
        }
        .task(id: pending.prefix(4).map(String.init).joined(separator: ",")) { loadImages() }
        .overlay {
            if let index = viewing, let file = roll?.shots[index].developedFile {
                FullPrint(url: model.url(for: file), preview: image(index)) {
                    withAnimation(.easeOut(duration: 0.2)) { viewing = nil }
                } decide: { verdict in
                    withAnimation(.easeOut(duration: 0.2)) { viewing = nil }
                    decide(index, verdict)
                }
                .transition(.opacity)
            }
        }
    }

    private var denied: Binding<Bool> {
        Binding { model.saveProblem == .denied } set: { if !$0 { model.saveProblem = nil } }
    }

    private var damaged: Binding<Bool> {
        Binding { model.saveProblem == .damaged } set: { if !$0 { model.saveProblem = nil } }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR PRINTS")
                    .font(.print(13))
                    .tracking(3)
                    .opacity(0.8)
                Text(model.film?.name ?? "")
                    .font(.typed(17))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\((roll?.shots.count ?? 0) - pending.count + 1) / \(roll?.shots.count ?? 0)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .contentTransition(.numericText())
                Text("\(kept) kept")
                    .font(.typed(13))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(Paper.cream)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }

    private var buttons: some View {
        HStack(spacing: 44) {
            RoundButton(symbol: "xmark", label: "Toss", color: Paper.stampRed) {
                if let first = pending.first { decide(first, .trash) }
            }
            RoundButton(symbol: "heart.fill", label: "Keep", color: Paper.stampGreen) {
                if let first = pending.first { decide(first, .keep) }
            }
        }
    }

    @ViewBuilder
    private func card(depth: Int, index: Int) -> some View {
        let top = depth == 0
        let print = PrintCard(image: image(index), shot: roll?.shots[index], frame: index + 1, film: model.film,
                              flipped: top && flipped)
        if top {
            print
                .overlay(alignment: .topLeading) {
                    Stamp(text: "KEEP", color: Paper.stampGreen).opacity(stampOpacity(1)).rotationEffect(.degrees(-14)).padding(28)
                }
                .overlay(alignment: .topTrailing) {
                    Stamp(text: "TOSS", color: Paper.stampRed).opacity(stampOpacity(-1)).rotationEffect(.degrees(12)).padding(28)
                }
                .rotationEffect(.degrees(Double(drag.width / 18)))
                .offset(drag)
                .gesture(dragGesture(index))
                .onTapGesture {
                    Feel.shared.printSlide()
                    withAnimation(.easeOut(duration: 0.2)) { viewing = index }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    Feel.shared.printSlide()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { flipped.toggle() }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Print \(index + 1) of \(roll?.shots.count ?? 0)")
                .accessibilityHint("Swipe right to keep, left to toss. Tap to see it full screen.")
                .accessibilityAction(named: "View full screen") { viewing = index }
                .accessibilityAction(named: "Turn over") { flipped.toggle() }
                .accessibilityAction(named: "Keep") { decide(index, .keep) }
                .accessibilityAction(named: "Toss") { decide(index, .trash) }
        } else {
            // The next prints wait underneath, a little askew.
            print
                .rotationEffect(.degrees(tilt(index)))
                .offset(y: CGFloat(depth) * 6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Dragging

    private func dragGesture(_ index: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard flying == nil else { return }
                drag = value.translation
                let past = abs(value.translation.width) > threshold
                if past != crossed {
                    crossed = past
                    if past { Feel.shared.threshold() }
                }
            }
            .onEnded { value in
                guard flying == nil else { return }
                let predicted = value.predictedEndTranslation.width
                if value.translation.width > threshold || predicted > threshold * 2.2 {
                    decide(index, .keep)
                } else if value.translation.width < -threshold || predicted < -threshold * 2.2 {
                    decide(index, .trash)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }
                    crossed = false
                }
            }
    }

    private func stampOpacity(_ side: CGFloat) -> Double {
        Double(max(0, min(1, drag.width * side / threshold)))
    }

    private func decide(_ index: Int, _ verdict: Verdict) {
        guard flying == nil else { return }
        flying = verdict
        verdict == .keep ? Feel.shared.keep() : Feel.shared.toss()
        withAnimation(.easeIn(duration: 0.28)) {
            drag = CGSize(width: verdict == .keep ? 560 : -560, height: drag.height + 60)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.28))
            let done = await model.review(index: index, verdict: verdict)
            flipped = false
            crossed = false
            flying = nil
            if done {
                images[index] = nil
                drag = .zero
            } else {
                // Couldn't keep it: the print slides back onto the pile.
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { drag = .zero }
            }
        }
    }

    // MARK: - Images

    private func image(_ index: Int) -> UIImage? { images[index] }

    private func loadImages() {
        guard let roll else { return }
        for index in pending.prefix(4) where images[index] == nil {
            guard let file = roll.shots[index].developedFile else { continue }
            images[index] = Thumbnail.load(model.url(for: file), maxPixel: 1800)
        }
    }

    private func tilt(_ index: Int) -> Double {
        var rng = SeededRandom(seed: UInt64(index) &* 7919)
        return (rng.unit() - 0.5) * 9
    }
}

/// A 4×6 lab print with its white border. Turned over, the back of the paper with the lab's printing.
private struct PrintCard: View {
    let image: UIImage?
    let shot: Roll.Shot?
    let frame: Int
    let film: FilmStock?
    let flipped: Bool

    private var landscape: Bool { (image?.size.width ?? 2) > (image?.size.height ?? 3) }

    var body: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        // A 2:3 print plus its 10 pt white border.
        .frame(width: landscape ? 350 : 280, height: landscape ? 240 : 410)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 8)
    }

    private var front: some View {
        ZStack {
            Color(white: 0.98)
            Color(white: 0.85)
                .overlay {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipped()
                .padding(10)
            // Gloss.
            LinearGradient(colors: [.white.opacity(0.22), .clear, .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.screen)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var back: some View {
        Color(red: 0.97, green: 0.96, blue: 0.93)
            .overlay {
                // The paper maker's name, repeated diagonally across the back.
                VStack(spacing: 18) {
                    ForEach(0..<14, id: \.self) { _ in
                        Text("PLASTICC LAB PAPER · CRYSTAL GLOSS · PLASTICC LAB PAPER · CRYSTAL GLOSS")
                            .font(.print(9, weight: .bold))
                            .tracking(1)
                            .fixedSize()
                    }
                }
                .foregroundStyle(Color(white: 0.55).opacity(0.22))
                .rotationEffect(.degrees(-30))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nº \(frame)  ·  \(film?.name ?? "")")
                    Text(shot.map { Self.date.string(from: $0.takenAt) } ?? "")
                    if shot?.flash == true { Text("FLASH") }
                }
                .font(.typed(12))
                .foregroundStyle(Color(red: 0.4, green: 0.2, blue: 0.5).opacity(0.8))
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

/// An inked rubber stamp.
private struct Stamp: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.print(34))
            .tracking(3)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color, lineWidth: 4))
            .overlay(Grain(opacity: 0.5, blend: .destinationOut))
            .compositingGroup()
    }
}

private struct RoundButton: View {
    let symbol: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(color)
                .frame(width: 74, height: 74)
                .background(Paper.cream, in: Circle())
                .overlay(Circle().strokeBorder(color.opacity(0.3), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
        }
        .accessibilityLabel(label)
    }
}
