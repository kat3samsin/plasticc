import AVFoundation
import CoreHaptics
import UIKit

/// Every sound and haptic in the app, named for what the hand is doing.
/// Sounds follow the silent switch (ambient session) and the Sounds setting; haptics always play.
@MainActor
final class Feel {
    static let shared = Feel()

    nonisolated static let soundsKey = "sounds"

    private let selection = UISelectionFeedbackGenerator()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()
    private var engine: CHHapticEngine?
    private var chargePlayer: CHHapticPatternPlayer?
    private var sounds = SoundBank()
    private var isPrepared = false

    private init() {}

    private var soundsOn: Bool {
        UserDefaults.standard.object(forKey: Self.soundsKey) as? Bool ?? true
    }

    // MARK: - Shooting

    /// One notch of the thumbwheel. `tension` runs 0–1 across the wind: the spring tightens, so each notch
    /// lands a little firmer and louder.
    func windTick(tension: Double = 0.5) {
        prepareIfNeeded()
        rigid.impactOccurred(intensity: CGFloat(0.3 + 0.45 * tension))
        rigid.prepare()
        play("wind_tick", variants: 3, volume: Float(0.6 + 0.4 * tension))
    }

    /// The wheel locks on the next frame: the shutter cocks with a small click, then the wheel stops dead.
    func windStop() {
        prepareIfNeeded()
        play("wind_stop")
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95),
            ], relativeTime: 0.024),
        ]) { [rigid] in rigid.impactOccurred(intensity: 1) }
    }

    func shutter() {
        prepareIfNeeded()
        heavy.impactOccurred(intensity: 0.9)
        play("shutter")
        // The return snap of the leaf shutter, a beat later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [rigid] in rigid.impactOccurred(intensity: 0.45) }
    }

    /// The shutter pressed while the film isn't wound: the button meets the lock after a short travel,
    /// a dull, blunt stop with no click.
    func locked() {
        prepareIfNeeded()
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0),
            ], relativeTime: 0.005, duration: 0.05),
        ]) { [soft] in soft.impactOccurred(intensity: 0.8) }
    }

    /// A shot that didn't happen: a dead, soft press.
    func dud() {
        prepareIfNeeded()
        soft.impactOccurred(intensity: 0.35)
    }

    /// A flip of a plastic switch.
    func click() {
        prepareIfNeeded()
        light.impactOccurred(intensity: 0.7)
        play("wind_tick", variants: 3)
    }

    /// The flash capacitor charging: the whine plus a faint rising buzz under the thumb.
    func flashCharge(duration: TimeInterval) {
        prepareIfNeeded()
        play("flash_charge")
        playCharge(duration: duration)
    }

    func flashReady() {
        stopCharge()
        light.impactOccurred(intensity: 0.5)
        play("flash_ready")
    }

    func flashCancel() {
        stopCharge()
        sounds.stop("flash_charge")
    }

    // MARK: - Rewind

    /// One fine click of the crank's ratchet: light and quick, so a fast turn feels like a smooth purr.
    func crankTick(intensity: Double) {
        prepareIfNeeded()
        light.impactOccurred(intensity: CGFloat(0.3 + 0.45 * intensity))
        light.prepare()
        play("crank_tick", variants: 3, volume: Float(0.35 + 0.4 * intensity))
    }

    /// The leader slips off the spool: a short slack rumble, then a hollow tap.
    func crankRelease() {
        prepareIfNeeded()
        play("crank_release")
        playPattern([
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ], relativeTime: 0, duration: 0.16),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
            ], relativeTime: 0.17),
        ], curves: [
            CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 1), .init(relativeTime: 0.16, value: 0.1),
            ], relativeTime: 0),
        ]) { [soft] in soft.impactOccurred() }
    }

    // MARK: - The film counter

    /// A box sliding along the shelf to the front.
    func boxSlide() {
        prepareIfNeeded()
        selection.selectionChanged()
        play("box_slide", variants: 2, volume: 0.7)
    }

    /// A roll off the shelf and into the paper bag.
    func buy() {
        prepareIfNeeded()
        soft.impactOccurred(intensity: 0.7)
        play("bag")
    }

    // MARK: - Opening the box

    /// The end flap's tuck tab dragging against the card as it lifts.
    func flapCreak(progress: Double) {
        prepareIfNeeded()
        light.impactOccurred(intensity: CGFloat(0.25 + 0.4 * progress))
        play("flap_creak", variants: 3, volume: Float(0.5 + 0.4 * progress))
    }

    /// The tuck tab pops free and the flap swings open.
    func flapOpen() {
        prepareIfNeeded()
        play("flap_open")
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ], relativeTime: 0.01, duration: 0.12),
        ]) { [rigid] in rigid.impactOccurred(intensity: 0.7) }
    }

    /// The plastic tube rubbing up past the box's cardboard.
    func tubeSlide(progress: Double) {
        prepareIfNeeded()
        soft.impactOccurred(intensity: CGFloat(0.3 + 0.3 * progress))
        play("tube_slide", variants: 3, volume: Float(0.45 + 0.4 * progress))
    }

    /// The tube clears the box.
    func tubeOut() {
        prepareIfNeeded()
        soft.impactOccurred(intensity: 0.9)
        play("tube_out")
    }

    /// The tube's lid snapping off: a tight suction pop.
    func tubePop() {
        prepareIfNeeded()
        play("tube_pop")
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ], relativeTime: 0.05),
        ]) { [rigid] in rigid.impactOccurred(intensity: 1) }
    }

    /// The canister sliding out of the tube into your hand.
    func canisterOut() {
        prepareIfNeeded()
        play("canister_roll")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [heavy] in heavy.impactOccurred(intensity: 0.6) }
    }

    // MARK: - Loading and unloading

    func canisterClunk() {
        prepareIfNeeded()
        heavy.impactOccurred(intensity: 1)
        play("canister_clunk")
    }

    func doorSnap() {
        prepareIfNeeded()
        rigid.impactOccurred(intensity: 1)
        play("door_snap")
    }

    /// One sprocket hole of leader dragged across the film gate. `tension` rises as it nears the spool.
    func leaderTick(tension: Double) {
        prepareIfNeeded()
        rigid.impactOccurred(intensity: CGFloat(0.2 + 0.35 * tension))
        play("leader_tick", variants: 3, volume: Float(0.4 + 0.4 * tension))
    }

    /// The leader's tongue caught by the take-up spool's teeth.
    func leaderCatch() {
        prepareIfNeeded()
        play("leader_catch")
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
            ], relativeTime: 0.045),
        ]) { [rigid] in rigid.impactOccurred(intensity: 0.8) }
    }

    /// The back's latch giving way and its spring flipping the door open.
    func backOpen() {
        prepareIfNeeded()
        play("back_open")
        playPattern([
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
            ], relativeTime: 0.02, duration: 0.09),
        ]) { [rigid] in rigid.impactOccurred(intensity: 0.9) }
    }

    /// The canister dropped into the lab envelope.
    func envelopeDrop() {
        prepareIfNeeded()
        play("envelope_drop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [soft] in soft.impactOccurred(intensity: 1) }
    }

    // MARK: - Lab and prints

    func envelope() {
        prepareIfNeeded()
        soft.impactOccurred(intensity: 0.5)
        play("envelope")
    }

    func labBell() {
        prepareIfNeeded()
        notify.notificationOccurred(.success)
        play("lab_bell")
    }

    func printSlide() {
        prepareIfNeeded()
        play("print_slide")
    }

    func keep() {
        prepareIfNeeded()
        soft.impactOccurred(intensity: 0.8)
        play("keep")
    }

    func toss() {
        prepareIfNeeded()
        rigid.impactOccurred(intensity: 0.5)
        play("toss")
    }

    /// A card dragged past the point where letting go will decide it.
    func threshold() {
        prepareIfNeeded()
        selection.selectionChanged()
    }

    // MARK: - Plumbing

    private func play(_ name: String, variants: Int = 0, volume: Float = 1) {
        guard soundsOn else { return }
        sounds.play(name, variants: variants, volume: volume)
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        // Ambient: mixes with music and stays quiet when the silent switch is on, like a real camera can't.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        [light, rigid, heavy, soft].forEach { $0.prepare() }
        selection.prepare()
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = try? CHHapticEngine() {
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            self.engine = engine
        }
    }

    private func playPattern(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: () -> Void) {
        guard let engine,
              let pattern = try? CHHapticPattern(events: events, parameterCurves: curves),
              let player = try? engine.makePlayer(with: pattern) else {
            fallback()
            return
        }
        do {
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    private func playCharge(duration: TimeInterval) {
        stopCharge()
        guard let engine else { return }
        let events = [
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1),
            ], relativeTime: 0, duration: duration),
        ]
        let curves = [
            CHHapticParameterCurve(parameterID: .hapticSharpnessControl, controlPoints: [
                .init(relativeTime: 0, value: -0.3), .init(relativeTime: duration, value: 0.8),
            ], relativeTime: 0),
            CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 0.3), .init(relativeTime: duration, value: 1),
            ], relativeTime: 0),
        ]
        guard let pattern = try? CHHapticPattern(events: events, parameterCurves: curves),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
        chargePlayer = player
    }

    private func stopCharge() {
        try? chargePlayer?.stop(atTime: CHHapticTimeImmediate)
        chargePlayer = nil
    }
}

/// Preloaded players for the bundled `.caf` sounds. Each name keeps a few players so quick repeats overlap.
@MainActor
private struct SoundBank {
    private var players: [String: [AVAudioPlayer]] = [:]
    private var next: [String: Int] = [:]
    private var lastVariant: [String: Int] = [:]

    /// Plays `name`, or one of `name_1`…`name_<variants>` picked at random without repeating the last one.
    mutating func play(_ name: String, variants: Int, volume: Float) {
        var file = name
        if variants > 1 {
            var pick = Int.random(in: 1...variants)
            if pick == lastVariant[name] { pick = pick % variants + 1 }
            lastVariant[name] = pick
            file = "\(name)_\(pick)"
        }
        guard let player = player(for: file) else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    mutating func stop(_ name: String) {
        players[name]?.forEach { $0.stop() }
    }

    private mutating func player(for file: String) -> AVAudioPlayer? {
        if players[file] == nil {
            players[file] = (0..<3).compactMap { _ in
                guard let url = Bundle.main.url(forResource: file, withExtension: "caf"),
                      let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
        }
        guard let pool = players[file], !pool.isEmpty else { return nil }
        let index = next[file, default: 0]
        next[file] = (index + 1) % pool.count
        return pool[index]
    }
}
