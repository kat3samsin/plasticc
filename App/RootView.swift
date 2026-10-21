import PlasticcCore
import SwiftUI

/// Shows the screen for wherever the roll is in its life.
struct RootView: View {
    let model: RollModel

    var body: some View {
        Group {
            switch model.roll?.phase {
            case nil:
                if let finished = model.finished {
                    SummaryView(model: model, finished: finished)
                } else {
                    PickFilmView(model: model)
                }
            case .sealed:
                UnwrapView(model: model)
            case .unwrapped:
                LoadFilmView(model: model)
            case .loaded, .shooting:
                ShootView(model: model)
            case .rewinding:
                RewindView(model: model)
            case .developing:
                if model.isDeveloping || model.developFailed {
                    DarkroomView(model: model)
                } else {
                    LabView(model: model)
                }
            case .developed, .done:
                ReviewView(model: model)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: model.roll?.phase)
        .animation(.easeInOut(duration: 0.45), value: model.isDeveloping)
    }
}
