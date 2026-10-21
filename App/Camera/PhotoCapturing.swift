import Foundation
import PlasticcCore

/// One frame's original, ready for the roll.
struct Capture: Sendable {
    let data: Data
    /// Scene brightness as EV at ISO 100, when the file's own EXIF won't carry it.
    let sceneEV100: Double?
    let fileExtension: String
}

/// Takes a photo for the roll: the iPhone camera on a device, sample photos on the simulator.
@MainActor
protocol PhotoCapturing: AnyObject {
    /// Asks for camera access if needed and starts the camera. False when access is denied.
    func start() async -> Bool
    func stop()
    func capture(flash: Bool) async throws -> Capture
}

@MainActor
func makeCamera() -> any PhotoCapturing {
    #if targetEnvironment(simulator)
    SampleCamera()
    #else
    LiveCamera()
    #endif
}
