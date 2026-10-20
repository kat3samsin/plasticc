import PlasticcCore
import SwiftUI

/// Choose a film and how many exposures, then unwrap a fresh camera.
struct PickFilmView: View {
    let model: RollModel
    @State private var film = FilmStock.superia400
    @State private var length = RollLength.standard

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plasticc")
                    .font(.largeTitle.bold())
                Text("Snappy 35 · pick a film")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(FilmStock.all) { stock in
                    Button { film = stock } label: {
                        FilmBox(film: stock, isSelected: stock == film)
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Exposures", selection: $length) {
                ForEach(RollLength.allCases, id: \.self) { length in
                    Text("\(length.exposures) exp").tag(length)
                }
            }
            .pickerStyle(.segmented)

            Spacer()

            Button {
                model.start(film: film, length: length)
            } label: {
                Text("Get a camera")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Plastic.body)
        }
        .padding()
    }
}

private struct FilmBox: View {
    let film: FilmStock
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(film.boxColor)
                .frame(width: 12, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(film.name)
                    .font(.headline)
                Text(film.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Plastic.trim : .clear, lineWidth: 2)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension FilmStock {
    var blurb: String {
        switch id {
        case "superia400": "Cool and punchy. Green shadows, bright blues."
        case "portra800": "Warm and soft. Kind to skin, good in low light."
        case "hp5": "Black and white. Grainy, deep blacks."
        default: ""
        }
    }

    var boxColor: Color {
        switch id {
        case "superia400": Color(red: 0.05, green: 0.55, blue: 0.30)
        case "portra800": Color(red: 0.95, green: 0.70, blue: 0.10)
        default: Color(white: 0.85)
        }
    }
}
