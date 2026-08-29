import XCTest
@testable import CouchToHour

final class SessionResumeStoreTests: XCTestCase {

    private let suite = "SessionResumeStoreTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func snapshot(savedAt: Date) -> InProgressSession {
        InProgressSession(
            key: SessionKey(week: 1, day: 2, makeup: false),
            phases: [.init(phaseRaw: "run", seconds: 60), .init(phaseRaw: "walk", seconds: 60)],
            segmentIndex: 1,
            secondsLeftInSegment: 42,
            savedAt: savedAt
        )
    }

    func testSaveThenLoadRoundTrips() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        SessionResumeStore.save(snapshot(savedAt: now), to: defaults)

        let loaded = SessionResumeStore.load(now: now, from: defaults)
        XCTAssertEqual(loaded?.key, SessionKey(week: 1, day: 2, makeup: false))
        XCTAssertEqual(loaded?.secondsLeftInSegment, 42)
        XCTAssertEqual(loaded?.sessionPlan.phases.count, 2)
    }

    func testStaleSnapshotIsDroppedOnLoad() {
        let saved = Date(timeIntervalSinceReferenceDate: 0)
        SessionResumeStore.save(snapshot(savedAt: saved), to: defaults)

        let later = saved.addingTimeInterval(SessionResumeStore.maxAge + 1)
        XCTAssertNil(SessionResumeStore.load(now: later, from: defaults))
        XCTAssertNil(defaults.data(forKey: SessionResumeStore.key))   // and cleared
    }

    func testClearRemovesTheSlot() {
        SessionResumeStore.save(snapshot(savedAt: Date(timeIntervalSinceReferenceDate: 0)), to: defaults)
        SessionResumeStore.clear(from: defaults)
        XCTAssertNil(SessionResumeStore.load(now: Date(timeIntervalSinceReferenceDate: 0), from: defaults))
    }
}
