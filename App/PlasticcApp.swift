import SwiftUI

@main
struct PlasticcApp: App {
    @State private var model = RollModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
