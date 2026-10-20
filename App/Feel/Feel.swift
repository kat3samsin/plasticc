import AVFoundation
import UIKit

/// Haptics and click sounds for the wheel and shutter.
@MainActor
final class Feel {
    static let shared = Feel()

    private let selection = UISelectionFeedbackGenerator()
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private var notchPlayers: [AVAudioPlayer] = []
    private var clunkPlayer: AVAudioPlayer?
    private var nextNotch = 0
    private var isPrepared = false

    private init() {}

    /// One rib of the wind wheel.
    func notch() {
        prepareIfNeeded()
        selection.selectionChanged()
        selection.prepare()
        guard !notchPlayers.isEmpty else { return }
        let player = notchPlayers[nextNotch]
        nextNotch = (nextNotch + 1) % notchPlayers.count
        player.currentTime = 0
        player.play()
    }

    /// The wheel hits its stop: the next frame is ready.
    func clunk() {
        prepareIfNeeded()
        rigid.impactOccurred()
        rigid.prepare()
        guard let clunkPlayer else { return }
        clunkPlayer.currentTime = 0
        clunkPlayer.play()
    }

    func shutter() {
        prepareIfNeeded()
        heavy.impactOccurred()
        heavy.prepare()
    }

    /// The shutter pressed while the film isn't wound: a dead, soft press.
    func dud() {
        prepareIfNeeded()
        rigid.impactOccurred(intensity: 0.3)
        rigid.prepare()
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        notchPlayers = (0..<3).compactMap { _ in Self.player(named: "notch") }
        clunkPlayer = Self.player(named: "clunk")
        selection.prepare()
        rigid.prepare()
        heavy.prepare()
    }

    private static func player(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }
}
