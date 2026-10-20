import SwiftUI

/// Shown in place of the finder when camera access is off.
struct PermissionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("Plasticc needs the camera")
                .font(.title3.bold())
            Text("Allow camera access in Settings to shoot this roll.")
                .multilineTextAlignment(.center)
                .opacity(0.8)
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            .buttonStyle(.borderedProminent)
            .tint(Plastic.body)
        }
        .foregroundStyle(Plastic.trim)
        .padding(24)
    }
}
