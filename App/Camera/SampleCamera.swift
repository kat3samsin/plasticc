import UIKit

/// Shoots the bundled sample photos in turn, so a whole roll can be shot in the simulator.
@MainActor
final class SampleCamera: PhotoCapturing {
    enum SampleError: Error { case missing(String) }

    private let names = ["street", "portrait", "night"]
    private var next = 0

    /// What the finder shows: the photo the next press will take.
    var finderImage: UIImage? { image(names[next]) }

    func start() async -> Bool { true }
    func stop() {}
    func setFront(_ front: Bool) {}

    func capture(flash: Bool) async throws -> Capture {
        let name = names[next]
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else {
            throw SampleError.missing(name)
        }
        next = (next + 1) % names.count
        return Capture(data: try Data(contentsOf: url), sceneEV100: nil, fileExtension: "jpg")
    }

    private func image(_ name: String) -> UIImage? {
        Bundle.main.url(forResource: name, withExtension: "jpg").flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
