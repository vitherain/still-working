import XCTest

final class SessionControllerTests: XCTestCase {
    func testFailedAcquisitionPreservesTheOriginalTimerWhileProtectionIsValid() {
        let preferences = testPreferences()
        let power = FakePower()
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: power, preferences: preferences, now: { currentTime })
        let original = SessionSelection(minutes: 30, displayMode: .computerOnly)
        session.start(original)
        let previousAssertions = power.owned

        currentTime = origin.advanced(by: .seconds(600))
        for failure in [IdleAssertion.idleSystem, .idleDisplay] {
            power.refuse = failure
            session.replace(.standard)

            XCTAssertEqual(session.state.status, .active)
            XCTAssertEqual(session.state.remainingTime, .seconds(1_200))
            XCTAssertEqual(session.state.displayMode, .computerOnly)
            XCTAssertTrue(session.state.error?.contains("replace") == true)
            XCTAssertEqual(power.owned, previousAssertions)
            XCTAssertEqual(SessionController(power: FakePower(), preferences: preferences).rememberedSelection, original)
        }

        power.owned.removeAll()
        session.replace(.standard)
        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.countdown)
        XCTAssertTrue(session.state.error?.contains("Previous timer protection could not be verified") == true)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testInvalidSavedSelectionFallsBackToBothFirstUseDefaults() {
        let preferences = testPreferences()
        for (minutes, displayMode) in [("0", "computerOnly"), ("10081", "computerOnly"), ("15", "unknown")] {
            preferences.set(["minutes": minutes, "displayMode": displayMode], forKey: "lastSuccessfulSession")

            let session = SessionController(power: FakePower(), preferences: preferences)
            XCTAssertEqual(session.rememberedSelection, .standard)
            XCTAssertEqual(session.state.status, .inactive)
        }
    }

    func testFailedReleaseOfPreviousProtectionDoesNotCommitReplacement() {
        let preferences = testPreferences()
        let power = FakePower()
        let session = SessionController(power: power, preferences: preferences)
        session.start()
        power.refuseRelease = .idleDisplay

        session.replace(SessionSelection(minutes: 60, displayMode: .computerOnly))

        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.countdown)
        XCTAssertTrue(session.state.error?.contains("released") == true)
        XCTAssertEqual(Array(power.owned.values), [.idleDisplay])
        XCTAssertEqual(SessionController(power: FakePower(), preferences: preferences).rememberedSelection, .standard)

        power.refuseRelease = nil
        XCTAssertTrue(session.stop())
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testUnverifiedPowerDuringReplacementStopsAllProtectionAndPreservesPreferences() {
        for unsafeSource in [nil, PowerSource.battery(percent: 20)] {
            let preferences = testPreferences()
            let power = FakePower()
            let previous = SessionSelection(minutes: 60, displayMode: .computerOnly)
            let session = SessionController(power: power, preferences: preferences)
            session.start(previous)
            power.nextPowerReadings = [.external, unsafeSource]

            session.replace(.standard)

            XCTAssertEqual(session.state.status, unsafeSource == nil ? .inactive : .stopped)
            XCTAssertNil(session.state.remainingTime)
            XCTAssertTrue(session.state.error?.contains(unsafeSource == nil ? "verified" : "20%") == true)
            XCTAssertTrue(power.owned.isEmpty)
            XCTAssertEqual(SessionController(power: FakePower(), preferences: preferences).rememberedSelection, previous)
        }
    }

    func testOnlySuccessfulSelectionsAreRememberedAcrossColdLaunch() {
        let preferences = testPreferences()
        let power = FakePower()
        let first = SessionSelection(minutes: 87, displayMode: .computerOnly)
        let replacement = SessionSelection(minutes: 15, displayMode: .displayOn)
        let session = SessionController(power: power, preferences: preferences)
        XCTAssertEqual(session.rememberedSelection, .standard)

        session.start(first)
        XCTAssertEqual(SessionController(power: FakePower(), preferences: preferences).rememberedSelection, first)

        session.replace(replacement)
        session.stop()
        power.refuse = .idleSystem
        session.start(first)
        let relaunched = SessionController(power: FakePower(), preferences: preferences)
        XCTAssertEqual(relaunched.rememberedSelection, replacement)
        XCTAssertEqual(relaunched.state.status, .inactive)
        XCTAssertNil(relaunched.state.remainingTime)
    }

    private func testPreferences() -> UserDefaults {
        let suite = "StillWorkingTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
        return preferences
    }

    func testReplacementStartsFullDurationWithTheNewModeWithoutAPowerGap() {
        let power = FakePower()
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: power, preferences: testPreferences(), now: { currentTime })
        session.start()
        power.requireSystemProtection = true

        currentTime = origin.advanced(by: .seconds(600))
        session.refresh()
        XCTAssertEqual(session.state.remainingTime, .seconds(1_200))

        session.replace(SessionSelection(minutes: 30, displayMode: .computerOnly))

        XCTAssertEqual(session.state.remainingTime, .seconds(1_800))
        XCTAssertEqual(session.state.displayMode, .computerOnly)
        XCTAssertEqual(Array(power.owned.values), [.idleSystem])
        XCTAssertFalse(power.lostRequiredSystemProtection)

        currentTime = origin.advanced(by: .seconds(1_800))
        session.refresh()
        XCTAssertEqual(session.state.remainingTime, .seconds(600))
    }

    func testComputerOnlySessionUsesSelectedDurationAndRestoresOnlySystemProtectionAfterWake() {
        let power = FakePower()
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: power, preferences: testPreferences(), now: { currentTime })

        session.start(SessionSelection(minutes: 15, displayMode: .computerOnly))

        XCTAssertEqual(session.state.remainingTime, .seconds(900))
        XCTAssertEqual(session.state.displayMode, .computerOnly)
        XCTAssertEqual(Array(power.owned.values), [.idleSystem])

        power.owned.removeAll()
        currentTime = origin.advanced(by: .seconds(120))
        session.refresh(afterWake: true)

        XCTAssertEqual(session.state.remainingTime, .seconds(780))
        XCTAssertEqual(session.state.displayMode, .computerOnly)
        XCTAssertEqual(Array(power.owned.values), [.idleSystem])
        XCTAssertEqual(power.timeouts.last, .seconds(780))

        session.stop()
        XCTAssertNil(session.state.displayMode)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testCustomDurationStartsAtMinimumIntermediateAndMaximum() throws {
        let origin = ContinuousClock.now
        let session = SessionController(power: FakePower(), preferences: testPreferences(), now: { origin })
        var draft = SessionDraft()
        draft.preset = .custom

        for (hours, minutes, seconds) in [("0", "1", 60), ("3", "47", 13_620), ("168", "0", 604_800)] {
            draft.hours = hours
            draft.minutes = minutes

            session.start(try draft.selection.get())

            XCTAssertEqual(session.state.remainingTime, .seconds(seconds))
            session.stop()
        }
    }

    func testInvalidCustomInputExplainsWhatPreventsStart() {
        let inputs: [(String, String, SessionDraft.InvalidDuration)] = [
            ("", "1", .hours), ("1", "", .minutes), ("-1", "30", .hours),
            ("-0", "1", .hours), ("1.5", "0", .hours), ("1", "2.5", .minutes),
            ("1", "minutes", .minutes), ("9999999999999999999999999", "0", .hours),
            ("169", "0", .hours), ("1", "60", .minutes), ("0", "0", .total), ("168", "1", .total)
        ]
        var draft = SessionDraft()
        draft.preset = .custom

        for (hours, minutes, expected) in inputs {
            draft.hours = hours
            draft.minutes = minutes

            XCTAssertEqual(draft.selection, .failure(expected), "\(hours)h \(minutes)m")
        }
    }

    func testFirstUseAndPresetSelectionsStartExpectedTimers() throws {
        let presets: [(SessionDraft.Preset, Duration)] = [
            (.quarterHour, .seconds(900)), (.halfHour, .seconds(1_800)), (.oneHour, .seconds(3_600)),
            (.twoHours, .seconds(7_200)), (.fourHours, .seconds(14_400))
        ]
        let origin = ContinuousClock.now
        let session = SessionController(power: FakePower(), preferences: testPreferences(), now: { origin })
        var draft = SessionDraft()

        XCTAssertEqual(draft.preset, .halfHour)
        XCTAssertTrue(draft.keepDisplayOn)

        for (preset, advertisedDuration) in presets {
            draft.preset = preset
            session.start(try draft.selection.get())

            XCTAssertEqual(session.state.remainingTime, advertisedDuration)
            XCTAssertEqual(session.state.displayMode, .displayOn)
            session.stop()
        }
    }

    func testCountdownRoundsUpToTheLastSecondAndFormatsTotalHours() {
        let origin = ContinuousClock.now
        var currentTime = origin
        let session = SessionController(power: FakePower(), preferences: testPreferences(), now: { currentTime })
        session.start(SessionSelection(minutes: 10_080, displayMode: .displayOn))
        XCTAssertEqual(session.state.countdown, "168:00:00")

        let deadline = origin.advanced(by: .seconds(604_800))
        let examples: [(Duration, String)] = [
            (.seconds(3_600), "1:00:00"), (.seconds(3_599), "59:59"),
            (.seconds(65) + .milliseconds(1), "1:06"), (.milliseconds(1), "0:01")
        ]
        for (remaining, expected) in examples {
            currentTime = deadline.advanced(by: .zero - remaining)
            session.refresh()
            XCTAssertEqual(session.state.countdown, expected)
        }

        currentTime = deadline
        session.refresh()
        XCTAssertEqual(session.state.status, .finished)
        XCTAssertNil(session.state.countdown)
    }

    func testBatteryFloorRefusesStartAndExternalPowerAllowsManualStart() {
        let power = FakePower()
        let session = SessionController(power: power, preferences: testPreferences())

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
        let session = SessionController(power: power, preferences: testPreferences())
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
        let session = SessionController(power: power, preferences: testPreferences())

        session.start()

        XCTAssertEqual(session.state.status, .inactive)
        XCTAssertNil(session.state.remainingTime)
        XCTAssertNotNil(session.state.error)
        XCTAssertTrue(power.owned.isEmpty)
    }

    func testUnavailablePowerStatePreventsStartAndStopsAfterWake() {
        let power = FakePower()
        let session = SessionController(power: power, preferences: testPreferences())
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
        let session = SessionController(power: power, preferences: testPreferences(), now: { currentTime })
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
        let session = SessionController(power: power, preferences: testPreferences())
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
        let session = SessionController(power: power, preferences: testPreferences())
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
        let session = SessionController(power: power, preferences: testPreferences(), now: { currentTime })

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
    var requireSystemProtection = false
    private(set) var lostRequiredSystemProtection = false
    private var nextID: UInt32 = 0

    var refuse: IdleAssertion?
    var refuseRelease: IdleAssertion?
    var source: PowerSource? = .external
    var nextPowerReadings: [PowerSource?] = []

    func readPowerSource() throws -> PowerSource {
        let reading = nextPowerReadings.isEmpty ? source : nextPowerReadings.removeFirst()
        guard let reading else { throw FakeFailure.native }
        return reading
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
        if requireSystemProtection && !owned.values.contains(.idleSystem) {
            lostRequiredSystemProtection = true
        }
    }

    func isActive(_ id: UInt32) -> Bool { owned[id] != nil }
}

private enum FakeFailure: Error { case native }
