enum DisplayMode: String {
    case displayOn
    case computerOnly
}

struct SessionSelection: Equatable {
    let minutes: Int
    let displayMode: DisplayMode

    static let standard = SessionSelection(minutes: 30, displayMode: .displayOn)
    static let validMinutes = 1...10_080
}

struct SessionDraft {
    enum Preset: Int, CaseIterable {
        case quarterHour = 15
        case halfHour = 30
        case oneHour = 60
        case twoHours = 120
        case fourHours = 240
        case custom = 0

        var label: String {
            switch self {
            case .quarterHour: "15 minutes"
            case .halfHour: "30 minutes"
            case .oneHour: "1 hour"
            case .twoHours: "2 hours"
            case .fourHours: "4 hours"
            case .custom: "Custom"
            }
        }
    }

    enum InvalidDuration: String, Error {
        case hours = "Enter whole hours from 0 to 168."
        case minutes = "Enter whole minutes from 0 to 59."
        case total = "Choose a duration from 1 minute to 168 hours."
    }

    var preset: Preset
    var hours: String
    var minutes: String
    var keepDisplayOn: Bool

    init(selection: SessionSelection = .standard) {
        preset = Preset(rawValue: selection.minutes) ?? .custom
        hours = String(selection.minutes / 60)
        minutes = String(selection.minutes % 60)
        keepDisplayOn = selection.displayMode == .displayOn
    }

    var selection: Result<SessionSelection, InvalidDuration> {
        let mode: DisplayMode = keepDisplayOn ? .displayOn : .computerOnly
        guard preset == .custom else {
            return .success(SessionSelection(minutes: preset.rawValue, displayMode: mode))
        }
        guard let hours = wholeNumber(hours, within: 0...168) else {
            return .failure(.hours)
        }
        guard let minutes = wholeNumber(minutes, within: 0...59) else {
            return .failure(.minutes)
        }
        let total = hours * 60 + minutes
        guard SessionSelection.validMinutes.contains(total) else {
            return .failure(.total)
        }
        return .success(SessionSelection(minutes: total, displayMode: mode))
    }

    private func wholeNumber(_ text: String, within range: ClosedRange<Int>) -> Int? {
        guard text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(text), range.contains(number) else {
            return nil
        }
        return number
    }
}
