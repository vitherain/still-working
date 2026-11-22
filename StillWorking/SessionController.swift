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
    private(set) var rememberedSelection: SessionSelection

    private static let selectionPreferenceKey = "lastSuccessfulSession"
    private let power: any SessionPower
    private let preferences: UserDefaults
    private let now: () -> ContinuousClock.Instant
    private var active: ActiveSession?
    private var unreleasedAssertions = Set<UInt32>()

    init(
        power: any SessionPower, preferences: UserDefaults,
        now: @escaping () -> ContinuousClock.Instant = { .now }
    ) {
        self.power = power
        self.preferences = preferences
        self.now = now
        if let saved = preferences.dictionary(forKey: Self.selectionPreferenceKey) as? [String: String],
           let duration = saved["minutes"], let minutes = Int(duration),
           SessionSelection.validMinutes.contains(minutes),
           let mode = saved["displayMode"], let displayMode = DisplayMode(rawValue: mode) {
            rememberedSelection = SessionSelection(minutes: minutes, displayMode: displayMode)
        } else {
            rememberedSelection = .standard
        }
    }

    func start(_ selection: SessionSelection = .standard) {
        guard active == nil else { return }
        applySelection(selection)
    }

    func replace(_ selection: SessionSelection) {
        guard active != nil else { return }
        applySelection(selection)
    }

    private func applySelection(_ selection: SessionSelection) {
        guard SessionSelection.validMinutes.contains(selection.minutes) else { return }
        guard verifyPowerOrFinish() else { return }
        if let error = release(unreleasedAssertions) {
            reportPreparationFailure(error)
            return
        }

        let duration = Duration.seconds(selection.minutes * 60)
        let deadline = now().advanced(by: duration)
        let assertions: [UInt32]
        do {
            assertions = try acquireProtection(mode: selection.displayMode, timeout: duration)
        } catch {
            reportPreparationFailure(error.localizedDescription)
            return
        }

        guard verifyPowerOrFinish(releasing: assertions) else { return }
        if let error = release(active?.assertions ?? []) {
            active = nil
            finish(.inactive, error: "Could not replace the timer. \(error)", releasing: assertions)
            return
        }

        active = ActiveSession(deadline: deadline, displayMode: selection.displayMode, assertions: assertions)
        updateRemainingTime()
        if active != nil {
            rememberedSelection = selection
            preferences.set(
                ["minutes": String(selection.minutes), "displayMode": selection.displayMode.rawValue],
                forKey: Self.selectionPreferenceKey
            )
        }
    }

    private func reportPreparationFailure(_ error: String) {
        guard let active else {
            setState(.inactive, error: error)
            return
        }
        let message = "Could not replace the timer. \(error)"
        if now().duration(to: active.deadline) <= .zero {
            finish(.finished, error: message)
        } else if verifyPowerOrFinish() {
            if active.assertions.allSatisfy(power.isActive) {
                updateRemainingTime(error: message)
            } else {
                finish(.inactive, error: "\(message) Previous timer protection could not be verified.")
            }
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
        guard verifyPowerOrFinish() else { return }

        if afterWake && !active.assertions.allSatisfy(power.isActive) {
            do {
                let assertions = try acquireProtection(mode: active.displayMode, timeout: remaining)
                guard verifyPowerOrFinish(releasing: assertions) else { return }
                self.active = ActiveSession(
                    deadline: active.deadline, displayMode: active.displayMode, assertions: assertions
                )
                updateRemainingTime(error: release(unreleasedAssertions.union(active.assertions)))
            } catch {
                finish(.inactive, error: "Protection could not be restored. \(error.localizedDescription)")
            }
        } else {
            updateRemainingTime(error: state.error)
        }
    }

    private func verifyPowerOrFinish(releasing assertions: [UInt32] = []) -> Bool {
        switch try? power.readPowerSource() {
        case .external:
            return true
        case let .battery(percent) where (0...100).contains(percent):
            guard percent <= 20 else { return true }
            if active != nil {
                finish(.stopped, error: "Timer stopped at the 20% unplugged battery floor.", releasing: assertions)
            } else {
                finish(.inactive, error: "Battery charge must be above 20% when unplugged.", releasing: assertions)
            }
        default:
            finish(.inactive, error: "Power state could not be verified.", releasing: assertions)
        }
        return false
    }

    private func acquireProtection(mode: DisplayMode, timeout: Duration) throws -> [UInt32] {
        var assertions: [UInt32] = []
        do {
            assertions.append(try power.acquire(.idleSystem, timeout: timeout))
            if mode == .displayOn {
                assertions.append(try power.acquire(.idleDisplay, timeout: timeout))
            }
            return assertions
        } catch {
            if let cleanupError = release(assertions) {
                throw ProtectionAcquisitionError(message: "\(error.localizedDescription) \(cleanupError)")
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
    private func finish(
        _ status: Status, error: String? = nil, releasing prepared: [UInt32] = []
    ) -> Bool {
        let assertions = unreleasedAssertions.union(active?.assertions ?? []).union(prepared)
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

private struct ProtectionAcquisitionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
