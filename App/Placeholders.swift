import PlasticcCore
import SwiftUI

// Stand-ins for screens that arrive in later milestones: unboxing (9), rewind crank (5), the lab (6–8).

struct UnboxPlaceholderView: View {
    let model: RollModel

    var body: some View {
        PlaceholderScreen(
            title: model.roll?.phase == .sealed ? "Still in its wrap" : "Camera's open",
            detail: model.film?.name ?? "",
            action: model.roll?.phase == .sealed ? "Tear the wrap" : "Load the film"
        ) {
            model.roll?.phase == .sealed ? model.tear() : model.load()
        }
    }
}

struct RewindPlaceholderView: View {
    let model: RollModel

    var body: some View {
        PlaceholderScreen(title: "Roll finished", detail: "Rewind the film into its canister.", action: "Rewind") {
            model.rewind()
        }
    }
}

struct LabPlaceholderView: View {
    let model: RollModel

    var body: some View {
        PlaceholderScreen(title: "At the lab", detail: "\(model.roll?.shots.count ?? 0) frames waiting to develop.", action: nil) {}
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let detail: String
    let action: String?
    let perform: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title.bold())
            Text(detail)
                .foregroundStyle(Plastic.trim.opacity(0.8))
            if let action {
                Button(action, action: perform)
                    .buttonStyle(.borderedProminent)
                    .tint(Plastic.dark)
            }
        }
        .foregroundStyle(Plastic.trim)
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Plastic.body)
    }
}
