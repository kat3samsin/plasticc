import Foundation

/// The rewind crank's feel, turned into numbers. Longer rolls take more turns. As the film leaves the
/// spool the ticks come closer together and get lighter, then the leader slips free.
public struct RewindCrank: Sendable {
    public enum Event: Equatable, Sendable {
        /// One click of the crank. Intensity runs from 1 (full spool) down to 0.3 (nearly empty).
        case tick(intensity: Double)
        /// The leader has left the spool: the film is in the canister.
        case released
    }

    /// Radians of cranking for the whole roll.
    public let totalAngle: Double
    public private(set) var angle: Double = 0
    public private(set) var isDone = false
    private var nextTick: Double

    public var progress: Double { min(1, angle / totalAngle) }

    public init(exposures: Int) {
        // Half the turns of a real rewind crank, so it never drags: 1½ turns for 12 frames, 2½ for 36.
        totalAngle = Double(2 + exposures / 12) * .pi
        nextTick = Self.spacing(atProgress: 0)
    }

    /// Turn by a change in finger angle, in radians. Either direction winds the film in.
    public mutating func turn(by delta: Double) -> [Event] {
        guard !isDone else { return [] }
        angle += abs(delta)
        var events: [Event] = []
        while nextTick < totalAngle, angle >= nextTick {
            let at = nextTick / totalAngle
            events.append(.tick(intensity: 1 - 0.7 * at))
            nextTick += Self.spacing(atProgress: at)
        }
        if angle >= totalAngle {
            isDone = true
            events.append(.released)
        }
        return events
    }

    /// 20° between clicks on a full spool, narrowing to 10° near the end: a fine, smooth ratchet.
    static func spacing(atProgress progress: Double) -> Double {
        (20 - 10 * progress) * .pi / 180
    }
}
