import PlasticcCore
import SwiftUI

/// The shop counter: swipe through the cameras, pick how many exposures, take one home.
struct PickFilmView: View {
    let model: RollModel
    @State private var filmID: String? = FilmStock.superia400.id
    @State private var length = RollLength.standard
    @State private var showSettings = false

    private var film: FilmStock { filmID.flatMap(FilmStock.with) ?? .superia400 }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(FilmStock.all) { stock in
                            CameraBox(film: stock, exposures: length.exposures)
                                .frame(width: 240, height: 330)
                                .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                    view
                                        .scaleEffect(phase.isIdentity ? 1 : 0.82)
                                        .rotationEffect(.degrees(phase.value * 8))
                                        .opacity(phase.isIdentity ? 1 : 0.6)
                                }
                                .containerRelativeFrame(.horizontal)
                                .id(stock.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $filmID)
                .scrollIndicators(.hidden)
                .frame(height: 380)
                .padding(.top, 18)
                .onChange(of: filmID) { Feel.shared.windTick(tension: 0.3) }

                VStack(spacing: 4) {
                    Text(film.name)
                        .font(.print(20))
                        .foregroundStyle(Paper.ink)
                    Text(film.brand.blurb)
                        .font(.typed(15))
                        .foregroundStyle(Paper.fadedInk)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .animation(.easeInOut(duration: 0.2), value: filmID)

                HStack(spacing: 18) {
                    ForEach(RollLength.allCases, id: \.self) { option in
                        ExposureSticker(exposures: option.exposures, selected: option == length) {
                            guard option != length else { return }
                            Feel.shared.click()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { length = option }
                        }
                    }
                }
                .padding(.top, 26)

                Spacer(minLength: 12)

                Button {
                    Feel.shared.canisterClunk()
                    model.start(film: film, length: length)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bag.fill")
                        Text("Take this camera")
                    }
                    .font(.print(19, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Paper.ink, in: Capsule())
                    .foregroundStyle(Paper.cream)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plasticc")
                    .font(.print(40))
                    .foregroundStyle(Paper.ink)
                Text("One camera. One roll. No do-overs.")
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
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.5), in: Circle())
                    .overlay(Circle().strokeBorder(Paper.ink.opacity(0.15), lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
    }
}

/// A single-use camera in its retail box: the film's colours, big speed number, flash badge.
private struct CameraBox: View {
    let film: FilmStock
    let exposures: Int

    var body: some View {
        let brand = film.brand
        HStack(spacing: 0) {
            // Front face.
            brand.sleeve
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<3, id: \.self) { i in
                            Rectangle()
                                .fill(brand.band.opacity(1 - Double(i) * 0.25))
                                .frame(width: 420, height: 14 - CGFloat(i) * 3)
                                .rotationEffect(.degrees(-24))
                                .offset(x: -60, y: 220 + CGFloat(i) * 20)
                        }
                    }
                }
                .overlay {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(brand.maker)
                            .font(.print(13))
                            .tracking(3)
                        Text(brand.line)
                            .font(.print(24))
                            .italic()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(brand.speed)
                            .font(.print(78))
                            .italic()
                            .padding(.top, -6)
                        Spacer()
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SINGLE-USE")
                                Text("CAMERA")
                            }
                            .font(.print(11))
                            Spacer()
                            VStack(spacing: 0) {
                                Text("\(exposures)")
                                    .font(.print(26))
                                    .contentTransition(.numericText())
                                Text("EXP").font(.print(9))
                            }
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(brand.band))
                            .foregroundStyle(brand.bandInk)
                        }
                    }
                    .foregroundStyle(brand.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("FLASH")
                    }
                    .font(.print(10))
                    .foregroundStyle(Paper.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 1, green: 0.85, blue: 0.2), in: Capsule())
                    .rotationEffect(.degrees(12))
                    .padding(.top, 158)
                    .padding(.trailing, 10)
                }
            .overlay(Grain(opacity: 0.16))
            .overlay(Sheen(strength: 0.2))
            .clipped()

            // Side face, in shadow.
            brand.sleeve
                .overlay(Color.black.opacity(0.32))
                .overlay(
                    Text("\(brand.maker) \(brand.speed)")
                        .font(.print(10))
                        .tracking(2)
                        .foregroundStyle(brand.ink.opacity(0.7))
                        .fixedSize()
                        .rotationEffect(.degrees(90))
                )
                .frame(width: 26)
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.35), radius: 12, x: 6, y: 12)
        .accessibilityElement()
        .accessibilityLabel("\(film.name) single-use camera, \(exposures) exposures")
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
