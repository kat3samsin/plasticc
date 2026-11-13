import Foundation

/// Keeps one roll on disk: its JPEGs plus a `roll.json` manifest. Survives app restarts.
public final class RollStore: @unchecked Sendable {
    public enum StoreError: Error, Equatable { case rollInProgress, noRoll }

    private let directory: URL
    private let lock = NSLock()
    private var _current: Roll?

    public var current: Roll? { lock.withLock { _current } }

    private var manifest: URL { directory.appendingPathComponent("roll.json") }

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // A missing or corrupt manifest means no roll; stray images are left alone.
        if let data = try? Data(contentsOf: manifest) {
            _current = try? JSONDecoder().decode(Roll.self, from: data)
        }
    }

    public func url(for file: String) -> URL {
        directory.appendingPathComponent(file)
    }

    public func start(film: FilmStock, length: RollLength) throws {
        try lock.withLock {
            guard _current == nil else { throw StoreError.rollInProgress }
            let roll = Roll(filmID: film.id, length: length)
            try write(roll)
            _current = roll
        }
    }

    public func tear() throws { try update { try $0.tear() } }
    public func load() throws { try update { try $0.load() } }
    public func wind() throws { try update { try $0.wind() } }
    public func rewind(readyAt: Date) throws { try update { try $0.rewind(readyAt: readyAt) } }
    public func setMulti(_ on: Bool) throws { try update { try $0.setMulti(on) } }

    /// Saves a shot's original. `fileExtension` follows the data: "jpg" or "heic".
    public func shoot(_ image: Data, flash: Bool, takenAt: Date = Date(), seed: UInt64 = .random(in: .min ... .max),
                      sceneEV100: Double? = nil, fileExtension: String = "jpg") throws {
        try update { roll in
            // Check the move before touching disk, so a refused shot leaves no file behind.
            var next = roll
            // A second exposure is named for the frame it lands on.
            let file = roll.multi ? Self.fileName(index: roll.shots.count - 1, kind: "-2", ext: fileExtension)
                                  : Self.fileName(index: roll.shots.count, kind: "", ext: fileExtension)
            try next.shoot(file: file, takenAt: takenAt, flash: flash, seed: seed, sceneEV100: sceneEV100)
            // The image goes first: the manifest must never point at a missing file.
            try image.write(to: url(for: file), options: .atomic)
            roll = next
        }
    }

    public func addDeveloped(_ jpeg: Data, index: Int) throws {
        try update { roll in
            var next = roll
            let file = Self.fileName(index: index, kind: "-dev")
            try next.markDeveloped(index: index, file: file)
            try jpeg.write(to: url(for: file), options: .atomic)
            roll = next
        }
    }

    /// Records the verdict and deletes the frame's files. Save a kept print to Photos before calling this.
    /// After the last card the roll is cleared, ready for a new one.
    public func review(index: Int, verdict: Verdict) throws {
        try lock.withLock {
            guard var roll = _current else { throw StoreError.noRoll }
            try roll.review(index: index, verdict: verdict)
            // Record the verdict before deleting, so the manifest never lists a print whose files are gone.
            if roll.phase == .done {
                try? FileManager.default.removeItem(at: manifest)
                _current = nil
            } else {
                try write(roll)
                _current = roll
            }
            let shot = roll.shots[index]
            try? FileManager.default.removeItem(at: url(for: shot.file))
            if let second = shot.second {
                try? FileManager.default.removeItem(at: url(for: second.file))
            }
            if let developed = shot.developedFile {
                try? FileManager.default.removeItem(at: url(for: developed))
            }
        }
    }

    private func update(_ change: (inout Roll) throws -> Void) throws {
        try lock.withLock {
            guard var roll = _current else { throw StoreError.noRoll }
            try change(&roll)
            try write(roll)
            _current = roll
        }
    }

    private func write(_ roll: Roll) throws {
        try JSONEncoder().encode(roll).write(to: manifest, options: .atomic)
    }

    /// A unique suffix, so a stray file from a crash or an old roll is never overwritten.
    private static func fileName(index: Int, kind: String, ext: String = "jpg") -> String {
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return String(format: "%03d", index + 1) + kind + "-" + suffix + "." + ext
    }
}
