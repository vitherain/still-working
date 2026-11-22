import XCTest

final class SessionControllerTests: XCTestCase {
    func testBatteryFloorRefusesStartAndExternalPowerAllowsManualStart() {
        let power = FakePower()
        let session = SessionController(power: power)

        for percent in [19, 20] {
            power.source = .battery(percent: Double(percent))
            session.start()
            XCTAssertEqual(session.state.status, .inactive)
            XCTAssertTrue(session.state.error?.contains("20%") == true)
            XCTAssertTrue(power.owned.isEmpty)
        }

        power.source = .external
        session.refresh()
        XCTAssertTrue(power.owned.isEmpty)
        session.start()
        XCTAssertEqual(session.state.status, .active)
    }

    func testUnpluggingAtFloorStopsTimerAndReconnectingDoesNotRestartIt() {
        let power = FakePower()
        let session = SessionController(power: power)
        power.source = .battery(percent: 21)
        session.start()
        XCTAssertEqual(session.state.status, .active)

        power.source = .external
        session.refresh()
        XCTAssertEqual(session.state.status, .active)

        power.source = .battery(percent: 20)
        session.refresh()
        XCTAssertEqual(session.state.status, .stopped)
        XCTAssertTrue(session.state.error?.contains("20%") == true)
        XCTAssertTrue(power.owned.isEmpty)

        power.source = .external
        session.refresh()
        XCTAssertEqual(session.state.status, .stopped)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testPartialAcquisitionFailureReleasesSystemAssertion() {
        let power = FakePower()
        power.refuse = .idleDisplay
        let session = SessionController(power: power)

        session.start()

        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertNotNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testUnavailablePowerStatePreventsStartAndStopsAfterWake() {
        let power = FakePower()
        let session = SessionController(power: power)
        power.source = nil

        session.start()
        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNotNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)

        power.source = .external
        session.start()
        XCTAssertEqual(session.state.status, .active)

        power.source = nil
        session.refresh(afterWake: true)
        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNotNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testWakeRestoresMissingProtectionForTheOriginalRemainder() {
        let power = FakePower()
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: power, now: { currentTime })
        session.start()
        power.owned = power.owned.filter { $0.value == .idleSystem }

        currentTime = origin.advanced(by: .seconds(600))
        session.refresh(afterWake: true)

        XCTAssertEqual(session.state.status, .active)
        XCTAssertEqual(session.state.remainingTime, .seconds(1_200))
        XCTAssertNil(session.state.error)
        XCTAssertEqual(power.owned.count, 2)
        XCTAssertEqual(Set(power.owned.values), [.idleSystem, .idleDisplay])
        XCTAssertEqual(Array(power.timeouts.suffix(2)), [.seconds(1_200), .seconds(1_200)])

        power.owned.removeAll()
        currentTime = origin.advanced(by: .seconds(1_800))
        session.refresh(afterWake: true)
        XCTAssertEqual(session.state.status, .finished)
        XCTAssertNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testFailedWakeRestorationReleasesOldAndPartialProtection() {
        let power = FakePower()
        let session = SessionController(power: power)
        session.start()
        power.owned = power.owned.filter { $0.value == .idleSystem }
        power.refuse = .idleDisplay

        session.refresh(afterWake: true)

        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertTrue(session.state.error?.contains("restored") == true)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testUnexpectedReleaseFailureIsReportedAndCanBeRetried() {
        let power = FakePower()
        let session = SessionController(power: power)
        session.start()
        power.refuseRelease = .idleDisplay

        XCTAssertFalse(session.stop())
        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertTrue(session.state.error?.contains("released") == true)
        XCTAssertEqual(Array(power.owned.values), [.idleDisplay])

        power.refuseRelease = nil
        XCTAssertTrue(session.stop())
        XCTAssertEqual(session.state.status, .stopped)
        XCTAssertNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testColdLaunchIsInactiveAndStartOwnsBothAssertionsUntilExactDeadline() {
        let power = FakePower()
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: power, now: { currentTime })

        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertTrue(power.owned.isEmpty)

        session.start()

        XCTAssertEqual(session.state.status, .active)
        XCTAssertEqual(session.state.remainingTime, .seconds(1_800))
        XCTAssertEqual(Set(power.owned.values), [.idleSystem, .idleDisplay])
        XCTAssertEqual(power.timeouts, [.seconds(1_800), .seconds(1_800)])

        currentTime = origin.advanced(by: .seconds(1_799) + .milliseconds(900))
        session.refresh()
        XCTAssertEqual(session.state.status, .active)
        XCTAssertEqual(session.state.remainingTime, .milliseconds(100))

        currentTime = origin.advanced(by: .seconds(1_800))
        session.refresh()
        XCTAssertEqual(session.state.status, .finished)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertTrue(power.owned.isEmpty)
    }
}

private final class FakePower: SessionPower {
    var owned: [UInt32: IdleAssertion] = [:]
    var timeouts: [Duration] = []
    private var nextID: UInt32 = 0

    var refuse: IdleAssertion?
    var refuseRelease: IdleAssertion?
    var source: PowerSource? = .external

    func readPowerSource() throws -> PowerSource {
        guard let source else { throw FakeFailure.native }
        return source
    }

    func acquire(_ kind: IdleAssertion, timeout: Duration) throws -> UInt32 {
        if kind == refuse { throw FakeFailure.native }
        nextID += 1
        owned[nextID] = kind
        timeouts.append(timeout)
        return nextID
    }

    func release(_ id: UInt32) throws {
        if let kind = owned[id], kind == refuseRelease { throw FakeFailure.native }
        owned.removeValue(forKey: id)
    }

    func isActive(_ id: UInt32) -> Bool { owned[id] != nil }
}

private enum FakeFailure: Error { case native }
