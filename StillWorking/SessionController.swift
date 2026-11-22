import Combine
import Foundation

enum IdleAssertion: Hashable {
    case idleSystem
    case idleDisplay
}

enum PowerSource {
    case external
    case battery(percent: Double)
}

protocol SessionPower {
    func readPowerSource() throws -> PowerSource
    func acquire(_ kind: IdleAssertion, timeout: Duration) throws -> UInt32
    // Releasing a resource already removed by macOS succeeds.
    func release(_ id: UInt32) throws
    func isActive(_ id: UInt32) -> Bool
}

final class SessionController {
    enum Status: Equatable {
        case inactive
        case active
        case finished
        case stopped
    }

    struct State: Equatable {
        var status: Status = .inactive
        var remainingTime: Duration?
        var displayMode: DisplayMode?
        var error: String?
    }

    private struct ActiveSession {
        let deadline: ContinuousClock.Instant
        let displayMode: DisplayMode
        let assertions: [UInt32]
    }

    @Published private(set) var state = State()

    private let power: any SessionPower
    private let now: () -> ContinuousClock.Instant
    private var active: ActiveSession?
    private var unreleasedAssertions = Set<UInt32>()

    init(power: any SessionPower, now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.power = power
        self.now = now
    }

    func start(_ selection: SessionSelection = .standard) {
        guard active == nil, SessionSelection.validMinutes.contains(selection.minutes) else { return }
        if let error = release(unreleasedAssertions) {
            setState(.inactive, error: error)
            return
        }

        let duration = Duration.seconds(selection.minutes * 60)
        let deadline = now().advanced(by: duration)
        do {
            try checkPower()
            let assertions = try acquireProtection(mode: selection.displayMode, timeout: duration)
            active = ActiveSession(deadline: deadline, displayMode: selection.displayMode, assertions: assertions)
            updateRemainingTime()
        } catch {
            setState(.inactive, error: error.localizedDescription)
        }
    }

    @discardableResult
    func stop() -> Bool {
        guard active != nil || !unreleasedAssertions.isEmpty else { return true }
        return finish(.stopped)
    }

    func refresh(afterWake: Bool = false) {
        guard let active else { return }
        let remaining = now().duration(to: active.deadline)
        guard remaining > .zero else {
            finish(.finished)
            return
        }
        do {
            try checkPower()
        } catch SessionError.batteryFloor {
            finish(.stopped, error: "Timer stopped at the 20% unplugged battery floor.")
            return
        } catch {
            finish(.inactive, error: error.localizedDescription)
            return
        }

        if afterWake && !active.assertions.allSatisfy(power.isActive) {
            do {
                let assertions = try acquireProtection(mode: active.displayMode, timeout: remaining)
                self.active = ActiveSession(
                    deadline: active.deadline, displayMode: active.displayMode, assertions: assertions
                )
                updateRemainingTime(error: release(active.assertions))
            } catch {
                finish(.inactive, error: "Protection could not be restored. \(error.localizedDescription)")
            }
        } else {
            updateRemainingTime(error: state.error)
        }
    }

    private func checkPower() throws {
        let source = try power.readPowerSource()
        if case let .battery(percent) = source {
            guard (0...100).contains(percent) else {
                throw SessionError.powerUnavailable
            }
            guard percent > 20 else {
                throw SessionError.batteryFloor
            }
        }
    }

    private func acquireProtection(mode: DisplayMode, timeout: Duration) throws -> [UInt32] {
        var assertions: [UInt32] = []
        do {
            assertions.append(try power.acquire(.idleSystem, timeout: timeout))
            if mode == .displayOn {
                assertions.append(try power.acquire(.idleDisplay, timeout: timeout))
            }
            try checkPower()
            return assertions
        } catch {
            if let cleanupError = release(assertions) {
                throw SessionError.cleanup("\(error.localizedDescription) \(cleanupError)")
            }
            throw error
        }
    }

    private func updateRemainingTime(error: String? = nil) {
        guard let active else { return }
        let remaining = now().duration(to: active.deadline)
        if remaining > .zero {
            setState(.active, remainingTime: remaining, error: error)
        } else {
            finish(.finished, error: error)
        }
    }

    @discardableResult
    private func finish(_ status: Status, error: String? = nil) -> Bool {
        let assertions = unreleasedAssertions.union(active?.assertions ?? [])
        active = nil
        if let cleanupError = release(assertions) {
            let message = error.map { "\($0) \(cleanupError)" } ?? cleanupError
            setState(.inactive, error: message)
            return false
        }
        setState(status, error: error)
        return true
    }

    private func release(_ assertions: some Sequence<UInt32>) -> String? {
        var failures: [String] = []
        for id in assertions {
            do {
                try power.release(id)
                unreleasedAssertions.remove(id)
            } catch {
                unreleasedAssertions.insert(id)
                failures.append(error.localizedDescription)
            }
        }
        guard !failures.isEmpty else { return nil }
        return "Could not confirm all protection was released. \(failures.joined(separator: " "))"
    }

    private func setState(_ status: Status, remainingTime: Duration? = nil, error: String? = nil) {
        let updated = State(
            status: status, remainingTime: remainingTime, displayMode: active?.displayMode, error: error
        )
        if state != updated {
            state = updated
        }
    }
}

extension SessionController.State {
    var roundedSeconds: Int64? {
        guard let remainingTime else { return nil }
        let components = remainingTime.components
        return components.seconds + (components.attoseconds > 0 ? 1 : 0)
    }

    var countdown: String? {
        guard let seconds = roundedSeconds else { return nil }
        if seconds >= 3_600 {
            return String(format: "%lld:%02lld:%02lld", seconds / 3_600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%lld:%02lld", seconds / 60, seconds % 60)
    }
}

private enum SessionError: LocalizedError {
    case powerUnavailable
    case batteryFloor
    case cleanup(String)

    var errorDescription: String? {
        switch self {
        case .powerUnavailable: "Power state could not be verified."
        case .batteryFloor: "Battery charge must be above 20% when unplugged."
        case let .cleanup(message): message
        }
    }
}
