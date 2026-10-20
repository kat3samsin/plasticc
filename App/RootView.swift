import PlasticcCore
import SwiftUI

/// Shows the screen for wherever the roll is in its life.
struct RootView: View {
    let model: RollModel

    var body: some View {
        switch model.roll?.phase {
        case nil:
            PickFilmView(model: model)
        case .sealed, .unwrapped:
            UnboxPlaceholderView(model: model)
        case .loaded, .shooting:
            ShootView(model: model)
        case .rewinding:
            RewindPlaceholderView(model: model)
        case .developing, .developed, .done:
            LabPlaceholderView(model: model)
        }
    }
}
