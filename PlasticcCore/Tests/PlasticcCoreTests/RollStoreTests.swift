import XCTest
@testable import PlasticcCore

final class RollStoreTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

    func files() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
    }

    func shootingStore(_ length: RollLength = .short) throws -> RollStore {
        let store = RollStore(directory: dir)
        try store.start(film: .portra800, length: length)
        try store.tear()
        try store.load()
        return store
    }

    func shootAll(_ store: RollStore) throws {
        while store.current?.phase == .loaded || store.current?.phase == .shooting {
            try store.wind()
            try store.shoot(jpeg, flash: false)
        }
    }

    func testStartPersistsASealedRoll() throws {
        let store = RollStore(directory: dir)
        try store.start(film: .hp5, length: .long)
        let reloaded = RollStore(directory: dir)
        XCTAssertEqual(reloaded.current?.filmID, "hp5")
        XCTAssertEqual(reloaded.current?.length, .long)
        XCTAssertEqual(reloaded.current?.phase, .sealed)
    }

    func testStartIsRefusedWhileARollExists() throws {
        let store = RollStore(directory: dir)
        try store.start(film: .hp5, length: .short)
        XCTAssertThrowsError(try store.start(film: .superia400, length: .long)) {
            XCTAssertEqual($0 as? RollStore.StoreError, .rollInProgress)
        }
        XCTAssertEqual(store.current?.filmID, "hp5")
    }

    func testMovesWithoutARollThrow() {
        let store = RollStore(directory: dir)
        XCTAssertThrowsError(try store.tear()) { XCTAssertEqual($0 as? RollStore.StoreError, .noRoll) }
    }

    func testShotsAreOnDiskAndSurviveARelaunch() throws {
        let store = try shootingStore(.standard)
        for _ in 0..<3 {
            try store.wind()
            try store.shoot(jpeg, flash: true)
        }
        try store.wind()
        let reloaded = RollStore(directory: dir)
        XCTAssertEqual(reloaded.current, store.current)
        XCTAssertEqual(reloaded.current?.remaining, 21)
        XCTAssertEqual(reloaded.current?.wound, true)
        for shot in reloaded.current?.shots ?? [] {
            XCTAssertEqual(try Data(contentsOf: reloaded.url(for: shot.file)), jpeg)
            XCTAssertTrue(shot.flash)
        }
    }

    func testRefusedShotWritesNoFile() throws {
        let store = try shootingStore()
        try store.wind()
        try store.shoot(jpeg, flash: false)
        XCTAssertThrowsError(try store.shoot(jpeg, flash: false)) { XCTAssertEqual($0 as? RollError, .notWound) }
        XCTAssertEqual(try files().count, 2) // one JPEG plus roll.json
    }

    func testEachShotGetsItsOwnSeed() throws {
        let store = try shootingStore()
        try shootAll(store)
        let seeds = Set(store.current?.shots.map(\.seed) ?? [])
        XCTAssertEqual(seeds.count, 12)
    }

    func testCorruptManifestMeansNoRoll() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: dir.appendingPathComponent("roll.json"))
        XCTAssertNil(RollStore(directory: dir).current)
    }

    func testDevelopReviewAndClearTheRoll() throws {
        let store = try shootingStore()
        try shootAll(store)
        try store.rewind(readyAt: Date())
        for i in 0..<12 { try store.addDeveloped(jpeg, index: i) }
        XCTAssertEqual(store.current?.phase, .developed)
        XCTAssertEqual(try files().count, 25) // 12 originals, 12 prints, roll.json

        let first = try XCTUnwrap(store.current?.shots.first)
        try store.review(index: 0, verdict: .keep)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: first.file).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: try XCTUnwrap(first.developedFile)).path))
        XCTAssertEqual(RollStore(directory: dir).current?.shots.first?.verdict, .keep)

        for i in 1..<12 { try store.review(index: i, verdict: .trash) }
        XCTAssertNil(store.current)
        XCTAssertNil(RollStore(directory: dir).current)
        XCTAssertEqual(try files(), [])
        try store.start(film: .superia400, length: .standard)
        XCTAssertEqual(store.current?.phase, .sealed)
    }
}
