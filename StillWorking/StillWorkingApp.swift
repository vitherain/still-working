import AppKit
import Combine
import SwiftUI

@main
enum StillWorkingApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = StillWorkingDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class StillWorkingDelegate: NSObject, NSApplicationDelegate {
    private let session = SessionController(power: MacPower())
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var sessionObserver: AnyCancellable?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        item.button?.setAccessibilityLabel("StillWorking")

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: panel(for: session.state))
        sessionObserver = session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.renderStatusItem(state)
            }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        // Let AppKit place the new status item before using it as the popover anchor.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            self?.showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.stop()
    }

    @objc private func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        session.refresh()
        guard let button = statusItem?.button, !popover.isShown else { return }
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func didWake() {
        session.refresh(afterWake: true)
    }

    @objc private func refresh() {
        session.refresh()
    }

    private func renderStatusItem(_ state: SessionController.State) {
        let button = statusItem?.button
        let symbol = state.countdown != nil ? "timer" : state.error == nil ? "moon.zzz" : "exclamationmark.circle"
        button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button?.title = state.countdown ?? ""
        button?.setAccessibilityValue(state.accessibleSummary)
        if let host = popover.contentViewController as? NSHostingController<SessionPanel> {
            host.rootView = panel(for: state)
        }

        refreshTimer?.invalidate()
        if let remaining = state.remainingTime {
            let timer = Timer(
                timeInterval: min(1, remaining.timeInterval), target: self,
                selector: #selector(refresh), userInfo: nil, repeats: false
            )
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
    }

    private func panel(for state: SessionController.State) -> SessionPanel {
        SessionPanel(
            state: state,
            start: { [weak self] in self?.session.start($0) },
            stop: { [weak self] in self?.session.stop() },
            quit: { [weak self] in self?.quit() }
        )
    }

    private func quit() {
        if !session.stop() {
            popover.performClose(nil)
            let alert = NSAlert()
            alert.messageText = "Could not confirm release"
            alert.informativeText = session.state.error ?? ""
            alert.addButton(withTitle: "Quit")
            alert.runModal()
        }
        NSApp.terminate(nil)
    }
}

private struct SessionPanel: View {
    let state: SessionController.State
    let start: (SessionSelection) -> Void
    let stop: () -> Void
    let quit: () -> Void

    @State private var draft = SessionDraft()

    var body: some View {
        let selection = draft.selection
        let validSelection = try? selection.get()
        VStack(alignment: .leading, spacing: 12) {
            Text("StillWorking")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if let countdown = state.countdown, let mode = state.displayMode {
                Text(countdown)
                    .font(.system(.largeTitle, design: .monospaced))
                    .accessibilityLabel("Remaining time")
                    .accessibilityValue(state.accessibleSummary)
                Text("Active · \(mode.label)")
            } else {
                Text(state.status.label)
            }

            if let error = state.error {
                Text(error)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Picker("Duration", selection: $draft.preset) {
                ForEach(SessionDraft.Preset.allCases, id: \.self) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.menu)

            if draft.preset == .custom {
                HStack {
                    durationField("Hours", text: $draft.hours)
                    durationField("Minutes", text: $draft.minutes)
                }
            }

            if case let .failure(problem) = selection {
                Text(problem.rawValue)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Keep display on", isOn: $draft.keepDisplayOn)

            HStack {
                if state.status == .active {
                    Button("Stop", action: stop)
                        .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Start") {
                        if let validSelection {
                            start(validSelection)
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(validSelection == nil)
                }
                Spacer()
                Button(state.status == .active ? "Stop Timer and Quit" : "Quit", action: quit)
                    .keyboardShortcut("q", modifiers: .command)
            }

            Text("Keeping the display on may delay automatic locking. Closing the lid or choosing Sleep still puts the Mac to sleep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 310)
    }

    private func durationField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .accessibilityHidden(true)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
        }
    }
}

private extension DisplayMode {
    var label: String {
        switch self {
        case .displayOn: "Display on"
        case .computerOnly: "Computer only"
        }
    }
}

private extension SessionController.Status {
    var label: String {
        switch self {
        case .inactive: "Inactive"
        case .active: "Active"
        case .finished: "Finished"
        case .stopped: "Stopped"
        }
    }
}

private extension SessionController.State {
    var accessibleSummary: String {
        if let seconds = roundedSeconds {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .full
            if let spoken = formatter.string(from: TimeInterval(seconds)) {
                return "\(spoken) remaining"
            }
        }
        return error ?? status.label
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
