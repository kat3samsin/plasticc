import PlasticcCore
import SwiftUI

/// The film counter: swipe along the shelf of film boxes, pick how many exposures, buy a roll for your camera.
struct PickFilmView: View {
    let model: RollModel
    @State private var filmID: String?
    /// The last box settled in the middle; the scroll position reads nil while a swipe is settling.
    @State private var shownID: String
    @State private var length = Self.defaultLength

    /// The three-shot test roll is for debug builds only, where it's also the default.
    #if DEBUG
    private static let lengths = RollLength.allCases
    private static let defaultLength = RollLength.test
    #else
    private static let lengths = RollLength.allCases.filter { $0 != .test }
    private static let defaultLength = RollLength.standard
    #endif
    @State private var showSettings = false
    @State private var bought = false

    private var film: FilmStock { FilmStock.with(id: filmID ?? shownID) ?? .superia400 }

    /// Opens on the film you bought last time.
    init(model: RollModel) {
        self.model = model
        let last = UserDefaults.standard.string(forKey: Settings.lastFilmKey).flatMap(FilmStock.with)?.id ?? FilmStock.superia400.id
        _filmID = State(initialValue: last)
        _shownID = State(initialValue: last)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Layout.margin)
                    .padding(.top, 10)

                ZStack(alignment: .bottom) {
                    Shelf()
                        .frame(height: 46)
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(FilmStock.all) { stock in
                                FilmBox(film: stock, exposures: length.exposures)
                                    // Bought: lifted off the shelf and into the bag.
                                    .scaleEffect(bought && stock.id == film.id ? 0.6 : 1, anchor: .bottom)
                                    .offset(y: bought && stock.id == film.id ? -40 : 0)
                                    .rotationEffect(.degrees(bought && stock.id == film.id ? -8 : 0))
                                    .opacity(bought && stock.id == film.id ? 0 : 1)
                                    .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                        view
                                            .scaleEffect(phase.isIdentity ? 1 : 0.8, anchor: .bottom)
                                            .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
                                            .opacity(phase.isIdentity ? 1 : 0.55)
                                    }
                                    .padding(.bottom, 26)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .containerRelativeFrame(.horizontal)
                                    .id(stock.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $filmID)
                    .scrollIndicators(.hidden)
                    .scrollDisabled(bought)
                }
                // Gives way on short screens; the box only needs its own height plus the shelf.
                .frame(minHeight: BoxGeometry.size.height + 26, maxHeight: 390)
                .padding(.top, 8)
                .onChange(of: filmID) { _, id in
                    if let id { shownID = id }
                    Feel.shared.boxSlide()
                }

                VStack(spacing: 4) {
                    Text(film.name)
                        .font(.print(20))
                        .foregroundStyle(Paper.ink)
                    Text(film.brand.blurb)
                        .font(.typed(15))
                        .foregroundStyle(Paper.fadedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 30)
                .animation(.easeInOut(duration: 0.2), value: filmID)

                HStack(spacing: 18) {
                    ForEach(Self.lengths, id: \.self) { option in
                        ExposureSticker(exposures: option.exposures, selected: option == length) {
                            guard option != length else { return }
                            Feel.shared.click()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { length = option }
                        }
                    }
                }
                .padding(.top, 26)
                .disabled(bought)

                Spacer(minLength: 12)

                Button(action: buy) {
                    HStack(spacing: 10) {
                        Image(systemName: "bag.fill")
                        Text("Buy this roll")
                    }
                }
                .buttonStyle(PaperButtonStyle())
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, Layout.buttonInset)
                .disabled(bought)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    /// Off the shelf and into your bag, then home to open it.
    private func buy() {
        guard !bought else { return }
        let film = film, length = length
        UserDefaults.standard.set(film.id, forKey: Settings.lastFilmKey)
        Feel.shared.buy()
        withAnimation(.easeIn(duration: 0.5)) { bought = true }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            model.start(film: film, length: length)
            // Refused by the store: put the box back on the shelf.
            if model.roll == nil { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { bought = false } }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plasticc")
                    .font(.print(40))
                    .foregroundStyle(Paper.ink)
                Text("One camera. Any film. No do-overs.")
                    .font(.typed(15))
                    .foregroundStyle(Paper.fadedInk)
            }
            Spacer()
            Button {
                Feel.shared.click()
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Paper.ink)
                    .frame(width: Layout.tap, height: Layout.tap)
                    .background(.white.opacity(0.5), in: Circle())
                    .overlay(Circle().strokeBorder(Paper.ink.opacity(0.15), lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
    }
}

/// A round price-gun sticker for the exposure count.
private struct ExposureSticker: View {
    let exposures: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: -2) {
                Text("\(exposures)")
                    .font(.print(24))
                Text("EXP")
                    .font(.print(9))
                    .tracking(1)
            }
            .foregroundStyle(selected ? .white : Paper.ink)
            .frame(width: 70, height: 70)
            .background(Circle().fill(selected ? Paper.stampRed : .white.opacity(0.6)))
            .overlay(Circle().strokeBorder(selected ? .clear : Paper.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .scaleEffect(selected ? 1.08 : 1)
            .rotationEffect(.degrees(selected ? -6 : 0))
            .shadow(color: .black.opacity(selected ? 0.25 : 0), radius: 4, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exposures) exposures")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The wooden shelf the boxes stand on, with its lip catching the light.
private struct Shelf: View {
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.38, blue: 0.24), Color(red: 0.46, green: 0.31, blue: 0.19)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 30)
                .overlay(Grain(opacity: 0.08))
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 1) }
            Rectangle()
                .fill(Color(red: 0.33, green: 0.21, blue: 0.13))
                .frame(height: 16)
                .overlay(Grain(opacity: 0.08))
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 6)
        .accessibilityHidden(true)
    }
}
