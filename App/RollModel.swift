import Foundation
import Observation
import os
import PlasticcCore

/// The one roll the app is working on, for the screens to show and drive.
@MainActor
@Observable
final class RollModel {
    private(set) var roll: Roll?
    var flash = false
    private(set) var isCapturing = false
    /// Bumped on every shot, so the finder can blink.
    private(set) var shotCount = 0
    /// Nil until the camera has been asked for; false when access is denied.
    private(set) var cameraAllowed: Bool?

    let camera: any PhotoCapturing
    private let store: RollStore
    private let log = Logger(subsystem: "com.katre.plasticc", category: "roll")

    init() {
        store = RollStore(directory: .applicationSupportDirectory.appending(path: "Roll"))
        camera = makeCamera()
        roll = store.current
    }

    var film: FilmStock? { roll.flatMap { FilmStock.with(id: $0.filmID) } }

    func start(film: FilmStock, length: RollLength) { perform { try store.start(film: film, length: length) } }
    func tear() { perform { try store.tear() } }
    func load() { perform { try store.load() } }
    func wind() { perform { try store.wind() } }

    /// Develop time arrives in milestone 6; until then the roll is ready at once.
    func rewind() { perform { try store.rewind(readyAt: Date()) } }

    func startCamera() async {
        cameraAllowed = await camera.start()
    }

    func stopCamera() { camera.stop() }

    func shoot() async {
        guard roll?.wound == true, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let jpeg = try await camera.capture(flash: flash)
            try store.shoot(jpeg, flash: flash)
            shotCount += 1
        } catch {
            log.error("Shot failed: \(String(describing: error))")
        }
        roll = store.current
    }

    private func perform(_ move: () throws -> Void) {
        do {
            try move()
        } catch {
            log.error("Move refused: \(String(describing: error))")
        }
        roll = store.current
    }
}
