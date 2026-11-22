import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

struct MacPower: SessionPower {
    func readPowerSource() throws -> PowerSource {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() else {
            throw PowerError.unavailable
        }
        switch source as String {
        case kIOPSACPowerValue:
            return .external
        case kIOPSBatteryPowerValue:
            return try .battery(percent: batteryPercentage(in: snapshot))
        default:
            throw PowerError.unavailable
        }
    }

    private func batteryPercentage(in snapshot: CFTypeRef) throws -> Double {
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [AnyObject] else {
            throw PowerError.unavailable
        }
        for source in sources {
            guard let battery = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any],
                  battery[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  battery[kIOPSIsPresentKey] as? Bool == true else { continue }
            guard let current = battery[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = battery[kIOPSMaxCapacityKey] as? Int,
                  maximum > 0, (0...maximum).contains(current) else { break }
            return Double(current) * 100 / Double(maximum)
        }
        throw PowerError.unavailable
    }

    func acquire(_ kind: IdleAssertion, timeout: Duration) throws -> UInt32 {
        let type: String
        let description: String
        switch kind {
        case .idleSystem:
            type = kIOPMAssertionTypePreventUserIdleSystemSleep
            description = "computer awake"
        case .idleDisplay:
            type = kIOPMAssertionTypePreventUserIdleDisplaySleep
            description = "display on"
        }
        let duration = timeout.components
        let seconds = (Double(duration.seconds) + Double(duration.attoseconds) / 1e18).rounded(.up)
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithDescription(
            type as CFString, "StillWorking: Keep the \(description)" as CFString, nil, nil, nil, seconds,
            kIOPMAssertionTimeoutActionRelease as CFString, &id
        )
        guard result == kIOReturnSuccess else {
            throw PowerError.native("Could not keep the \(description)", result)
        }
        return id
    }

    func release(_ id: UInt32) throws {
        let result = IOPMAssertionRelease(id)
        // macOS 26.6.2 reports BadArgument for an owned ID removed by a timeout.
        if result == kIOReturnSuccess || result == kIOReturnNotFound ||
            (result == kIOReturnBadArgument && properties(of: id) == nil) {
            return
        }
        throw PowerError.native("Could not release an assertion", result)
    }

    func isActive(_ id: UInt32) -> Bool {
        properties(of: id)?[kIOPMAssertionLevelKey] as? Int == Int(kIOPMAssertionLevelOn)
    }

    private func properties(of id: UInt32) -> [String: Any]? {
        IOPMAssertionCopyProperties(id)?.takeRetainedValue() as? [String: Any]
    }
}

private enum PowerError: LocalizedError {
    case unavailable
    case native(String, IOReturn)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Power state could not be verified."
        case let .native(message, code):
            "\(message) (macOS error \(code))."
        }
    }
}
