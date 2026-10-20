import Foundation

/// Takes a photo for the roll: the iPhone camera on a device, sample photos on the simulator.
@MainActor
protocol PhotoCapturing: AnyObject {
    /// Asks for camera access if needed and starts the camera. False when access is denied.
    func start() async -> Bool
    func stop()
    /// An upright-tagged JPEG.
    func capture(flash: Bool) async throws -> Data
}

@MainActor
func makeCamera() -> any PhotoCapturing {
    #if targetEnvironment(simulator)
    SampleCamera()
    #else
    LiveCamera()
    #endif
}
