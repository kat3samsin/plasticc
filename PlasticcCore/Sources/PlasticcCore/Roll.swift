import Foundation

/// Where a roll is in its life. Persisted, so a force-quit resumes on the right screen.
public enum RollPhase: String, Codable, Sendable {
    /// The camera is still in its plastic wrap.
    case sealed
    /// The wrap is off; the film isn't in yet.
    case unwrapped
    /// The film is in; it needs its first wind.
    case loaded
    case shooting
    /// Every frame is shot; the film must be rewound into the canister.
    case rewinding
    /// At the lab until `readyAt`, then rendered frame by frame.
    case developing
    /// Every frame is printed; the deck is being sorted.
    case developed
    case done
}

public enum Verdict: String, Codable, Sendable {
    case keep, trash
}

public enum RollError: Error, Equatable {
    case wrongPhase(RollPhase)
    case notWound
    case alreadyWound
    case noSuchShot
    case alreadyReviewed
}

/// One roll from sealed camera to sorted deck. Every move is checked, so the screens can't skip a step.
public struct Roll: Codable, Equatable, Sendable {
    public struct Shot: Codable, Equatable, Sendable {
        /// The original's file name in the roll folder.
        public var file: String
        public var takenAt: Date
        public var flash: Bool
        /// Drives grain and light leaks, so a frame always develops the same way.
        public var seed: UInt64
        /// How bright the scene was, as EV at ISO 100, when the original's own EXIF can't say.
        public var sceneEV100: Double?
        public var developedFile: String?
        public var verdict: Verdict?

        public init(file: String, takenAt: Date, flash: Bool, seed: UInt64,
                    sceneEV100: Double? = nil) {
            self.file = file
            self.takenAt = takenAt
            self.flash = flash
            self.seed = seed
            self.sceneEV100 = sceneEV100
        }
    }

    public var filmID: String
    public var length: RollLength
    public private(set) var phase: RollPhase = .sealed
    public private(set) var shots: [Shot] = []
    /// True when the shutter is armed.
    public private(set) var wound = false
    public private(set) var readyAt: Date?

    public var remaining: Int { length.exposures - shots.count }

    public init(filmID: String, length: RollLength) {
        self.filmID = filmID
        self.length = length
    }

    public mutating func tear() throws {
        try require(.sealed)
        phase = .unwrapped
    }

    public mutating func load() throws {
        try require(.unwrapped)
        phase = .loaded
    }

    /// The first wind after loading starts the roll; every later one arms the shutter for the next frame.
    public mutating func wind() throws {
        guard phase == .loaded || phase == .shooting else { throw RollError.wrongPhase(phase) }
        guard !wound else { throw RollError.alreadyWound }
        phase = .shooting
        wound = true
    }

    public mutating func shoot(file: String, takenAt: Date, flash: Bool, seed: UInt64,
                               sceneEV100: Double? = nil) throws {
        try require(.shooting)
        guard wound else { throw RollError.notWound }
        shots.append(Shot(file: file, takenAt: takenAt, flash: flash, seed: seed, sceneEV100: sceneEV100))
        wound = false
        if remaining == 0 { phase = .rewinding }
    }

    public mutating func rewind(readyAt: Date) throws {
        try require(.rewinding)
        self.readyAt = readyAt
        phase = .developing
    }

    public func isReady(at now: Date) -> Bool {
        guard phase == .developing, let readyAt else { return false }
        return now >= readyAt
    }

    public mutating func markDeveloped(index: Int, file: String) throws {
        try require(.developing)
        guard shots.indices.contains(index) else { throw RollError.noSuchShot }
        shots[index].developedFile = file
        if shots.allSatisfy({ $0.developedFile != nil }) { phase = .developed }
    }

    public mutating func review(index: Int, verdict: Verdict) throws {
        try require(.developed)
        guard shots.indices.contains(index) else { throw RollError.noSuchShot }
        guard shots[index].verdict == nil else { throw RollError.alreadyReviewed }
        shots[index].verdict = verdict
        if shots.allSatisfy({ $0.verdict != nil }) { phase = .done }
    }

    private func require(_ expected: RollPhase) throws {
        guard phase == expected else { throw RollError.wrongPhase(phase) }
    }
}
