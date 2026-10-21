import Foundation
import CoreImage
import Observation
import os
import PlasticcCore
import UIKit

/// The one roll the app is working on, for the screens to show and drive.
@MainActor
@Observable
final class RollModel {
    enum FlashState { case off, charging, ready }

    private(set) var roll: Roll?
    private(set) var flashState: FlashState = .off
    private(set) var isCapturing = false
    /// Bumped on every shot, so the finder can blink.
    private(set) var shotCount = 0
    /// Nil until the camera has been asked for; false when access is denied.
    private(set) var cameraAllowed: Bool?

    /// A roll just sorted, for the goodbye screen; cleared when you get a new camera.
    struct FinishedRoll {
        let film: FilmStock
        let kept: Int
        let total: Int
    }

    private(set) var isDeveloping = false
    /// The lab stopped partway; the darkroom offers to try again.
    private(set) var developFailed = false
    /// The print that just came out of the tray, small, for the darkroom.
    private(set) var latestPrint: UIImage?
    /// Each processed frame as it looks on the negative strip, by frame index.
    private(set) var negatives: [Int: UIImage] = [:]
    private(set) var finished: FinishedRoll?
    /// Why the last kept print didn't reach Photos, for the deck's alert.
    var saveProblem: PhotoLibrary.Problem?

    let camera: any PhotoCapturing
    private let store: RollStore
    private let log = Logger(subsystem: "com.katre.plasticc", category: "roll")
    private var chargeTask: Task<Void, Never>?
    private let developer = Developer()
    /// How long the flash capacitor takes to charge, like a real single-use camera's.
    static let chargeTime: TimeInterval = 2.2

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

    /// The film's in the canister: off to the lab, ready after the develop time you've set.
    func rewind() {
        let readyAt = Settings.developTime.readyAt(from: Date())
        perform { try store.rewind(readyAt: readyAt) }
        if let roll, let film, readyAt > Date() {
            Task { await LabNotice.schedule(at: readyAt, film: film.name, exposures: roll.length.exposures) }
        }
    }

    func startCamera() async {
        cameraAllowed = await camera.start()
    }

    func stopCamera() {
        camera.stop()
        chargeTask?.cancel()
        // A real flash would stay charged, but a new screen starts with the switch off and quiet.
        flashState = .off
        Feel.shared.flashCancel()
    }

    func setFlash(_ on: Bool) {
        chargeTask?.cancel()
        if on {
            charge()
        } else {
            flashState = .off
            Feel.shared.flashCancel()
        }
    }

    private func charge() {
        flashState = .charging
        Feel.shared.flashCharge(duration: Self.chargeTime)
        chargeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.chargeTime))
            guard let self, !Task.isCancelled else { return }
            flashState = .ready
            Feel.shared.flashReady()
        }
    }

    /// False when nothing was taken, so the shutter can feel dead.
    @discardableResult
    func shoot() async -> Bool {
        guard roll?.wound == true, !isCapturing else { return false }
        isCapturing = true
        defer { isCapturing = false }
        // A flash that hasn't finished charging doesn't fire, like the real thing.
        let fire = flashState == .ready
        do {
            let capture = try await camera.capture(flash: fire)
            try store.shoot(capture.data, flash: fire, source: capture.source, sceneEV100: capture.sceneEV100,
                            fileExtension: capture.fileExtension)
            shotCount += 1
            // Recharge, unless the switch went off meanwhile or that was the last frame.
            if fire, flashState != .off, store.current?.phase == .shooting { charge() }
            roll = store.current
            return true
        } catch {
            log.error("Shot failed: \(String(describing: error))")
            roll = store.current
            return false
        }
    }

    #if DEBUG
    /// Testing shortcut: takes one real photo and uses it for every frame left, so the roll is ready to rewind.
    func finishRollForTesting() async {
        guard let roll, roll.phase == .loaded || roll.phase == .shooting, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        guard let capture = try? await camera.capture(flash: false) else { return }
        while store.current?.phase == .loaded || store.current?.phase == .shooting {
            if store.current?.wound == false { try? store.wind() }
            do {
                try store.shoot(capture.data, flash: false, source: capture.source, sceneEV100: capture.sceneEV100,
                                fileExtension: capture.fileExtension)
            } catch { break }
        }
        self.roll = store.current
    }
    #endif

    // MARK: - Lab

    var developedCount: Int { roll?.shots.filter { $0.developedFile != nil }.count ?? 0 }

    func url(for file: String) -> URL { store.url(for: file) }

    /// Develops every frame not yet printed, one at a time, so the darkroom can show each print come up.
    func develop() async {
        guard !isDeveloping, let roll, let film, roll.isReady(at: Date()) else { return }
        isDeveloping = true
        developFailed = false
        // Finish the print in hand if the phone is locked mid-develop.
        let background = UIApplication.shared.beginBackgroundTask(withName: "develop")
        defer {
            isDeveloping = false
            UIApplication.shared.endBackgroundTask(background)
        }
        LabNotice.cancel()
        // Back from a relaunch mid-develop: the frames already done are on the strip too.
        for (index, shot) in roll.shots.enumerated() where negatives[index] == nil {
            if let file = shot.developedFile, let thumb = Thumbnail.load(store.url(for: file), maxPixel: 240)?.cgImage {
                negatives[index] = Self.negative(of: thumb, film: film)
            }
        }
        let stamp = Settings.dateStamp
        let developer = developer
        for (index, shot) in roll.shots.enumerated() where shot.developedFile == nil {
            let original = store.url(for: shot.file)
            let started = Date()
            let result = await Task.detached(priority: .userInitiated) { () -> (Data, CGImage)? in
                // A frame the lab can't grade still comes back, as the plain photo, as long as it's a real picture.
                // And a frame whose photo is lost comes back blank, as a real lab would hand it back.
                let candidates = [{ try? developer.develop(original: original, film: film, shot: shot, frameIndex: index, dateStamp: stamp) },
                                  { try? Data(contentsOf: original) },
                                  { try? developer.blankPrint(film: film, shot: shot, frameIndex: index) }]
                for make in candidates {
                    if let data = make(), let thumb = Thumbnail.make(from: data, maxPixel: 720) { return (data, thumb) }
                }
                return nil
            }.value
            guard let result else {
                log.error("Couldn't print frame \(index)")
                developFailed = true
                break
            }
            // Give each print a moment in the tray, even on a fast phone.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 0.55 { try? await Task.sleep(for: .seconds(0.55 - elapsed)) }
            do {
                try store.addDeveloped(result.0, index: index)
            } catch {
                log.error("Couldn't keep print \(index): \(String(describing: error))")
                developFailed = true
                break
            }
            latestPrint = UIImage(cgImage: result.1)
            negatives[index] = Self.negative(of: result.1, film: film)
            Feel.shared.printSlide()
            self.roll = store.current
        }
        if !developFailed { Feel.shared.envelope() }
    }

    /// Sorts one print. Keeping saves it to Photos first; if that fails the print stays in the deck.
    @discardableResult
    func review(index: Int, verdict: Verdict) async -> Bool {
        guard let roll, let film, roll.shots.indices.contains(index), let file = roll.shots[index].developedFile else { return false }
        let shot = roll.shots[index]
        if verdict == .keep, let problem = await PhotoLibrary.save(store.url(for: file), takenAt: shot.takenAt) {
            saveProblem = problem
            return false
        }
        let kept = roll.shots.filter { $0.verdict == .keep }.count + (verdict == .keep ? 1 : 0)
        perform { try store.review(index: index, verdict: verdict) }
        // Refused by the store: the print stays in the pile.
        if let current = self.roll, current.shots[index].verdict == nil { return false }
        if self.roll == nil {
            finished = FinishedRoll(film: film, kept: kept, total: roll.shots.count)
            latestPrint = nil
        }
        return true
    }

    func newCamera() {
        finished = nil
        negatives = [:]
    }

    private static let negativeContext = CIContext()

    /// A small negative of a print, for the strip.
    private static func negative(of print: CGImage, film: FilmStock) -> UIImage? {
        let image = Negative.make(from: CIImage(cgImage: print), film: film)
        let small = image.transformed(by: CGAffineTransform(scaleX: 240 / max(image.extent.width, image.extent.height),
                                                            y: 240 / max(image.extent.width, image.extent.height)))
        return negativeContext.createCGImage(small, from: small.extent).map { UIImage(cgImage: $0) }
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
