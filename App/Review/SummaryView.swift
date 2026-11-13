import PlasticcCore
import SwiftUI

/// The roll's done: how many prints you kept, and back to the film counter for another.
struct SummaryView: View {
    let model: RollModel
    let finished: RollModel.FinishedRoll

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: finished.kept > 0 ? "photo.on.rectangle.angled" : "trash")
                    .font(.system(size: 54, weight: .regular))
                    .foregroundStyle(Paper.ink.opacity(0.75))
                Text(finished.kept > 0 ? "\(finished.kept) of \(finished.total) kept" : "Nothing kept")
                    .font(.print(34))
                    .foregroundStyle(Paper.ink)
                Text(finished.kept > 0
                     ? "They're in your Photos. The rest went in the bin, like a real envelope of prints."
                     : "Every print went in the bin. It happens to the best rolls.")
                    .font(.typed(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Paper.fadedInk)
                    .padding(.horizontal, 30)
                // The film's name on a sticker in its box colours, so it reads on cream whatever the film.
                Text(finished.film.name.uppercased())
                    .font(.print(11))
                    .tracking(2)
                    .foregroundStyle(finished.film.brand.bandInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(finished.film.brand.band, in: Capsule())
                Text("Your Snappy 35 is empty and ready for the next roll.")
                    .font(.typed(14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Paper.fadedInk)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                Spacer()
                Button("Buy another roll") {
                    Feel.shared.click()
                    model.nextRoll()
                }
                .buttonStyle(PaperButtonStyle())
                .padding(.horizontal, Layout.margin)
                .padding(.bottom, Layout.buttonInset)
            }
        }
    }
}
