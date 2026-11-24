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
    private let session = SessionController(power: MacPower(), preferences: .standard)
    private let settingsPanel = StatusItemPanel()
    private var statusItem: NSStatusItem?
    private var sessionObserver: AnyCancellable?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel(_:))
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        item.button?.setAccessibilityLabel("StillWorking")

        settingsPanel.contentViewController = NSHostingController(rootView: panel(for: session.state))
        sessionObserver = session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.renderStatusItem(state)
            }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil
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

    @objc private func togglePanel(_ button: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let mouseLocation = event?.type == .leftMouseUp ? event?.cgEvent?.unflippedLocation : nil
        session.refresh()
        settingsPanel.present(relativeTo: button, mouseLocation: mouseLocation, toggling: true)
    }

    private func showPanel() {
        guard let button = statusItem?.button else { return }
        session.refresh()
        settingsPanel.present(relativeTo: button)
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        settingsPanel.dismiss()
    }

    @objc private func didWake(_ notification: Notification) {
        session.refresh(afterWake: true)
    }

    @objc private func refresh(_ timer: Timer) {
        session.refresh()
    }

    private func renderStatusItem(_ state: SessionController.State) {
        let button = statusItem?.button
        let symbol = state.countdown != nil ? "timer" : state.error == nil ? "moon.zzz" : "exclamationmark.circle"
        button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button?.title = state.countdown ?? ""
        button?.setAccessibilityValue(state.accessibleSummary)
        settingsPanel.updatePosition()
        if let host = settingsPanel.contentViewController as? NSHostingController<SessionPanel> {
            host.rootView = panel(for: state)
        }

        refreshTimer?.invalidate()
        if let remaining = state.remainingTime {
            let timer = Timer(
                timeInterval: min(1, remaining.timeInterval), target: self,
                selector: #selector(refresh(_:)), userInfo: nil, repeats: false
            )
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
    }

    private func panel(for state: SessionController.State) -> SessionPanel {
        SessionPanel(
            state: state,
            initialSelection: session.rememberedSelection,
            start: { [weak self] in self?.session.start($0) },
            replace: { [weak self] in self?.session.replace($0) },
            stop: { [weak self] in self?.session.stop() },
            quit: { [weak self] in self?.quit() }
        )
    }

    private func quit() {
        if !session.stop() {
            settingsPanel.dismiss()
            let alert = NSAlert()
            alert.messageText = "Could not confirm release"
            alert.informativeText = session.state.error ?? ""
            alert.addButton(withTitle: "Quit")
            alert.runModal()
        }
        NSApp.terminate(nil)
    }
}

@MainActor
private final class StatusItemPanel: NSPanel, NSWindowDelegate {
    private var anchor: (button: NSStatusBarButton, screen: NSScreen, fallback: CGPoint)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        title = "StillWorking"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        level = .floating
        animationBehavior = .none
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        delegate = self
    }

    func present(relativeTo button: NSStatusBarButton, mouseLocation: CGPoint? = nil, toggling: Bool = false) {
        guard let window = button.window else { return }
        // Use the click's display when AppKit's shared status button is still on another one.
        let clickedScreen = mouseLocation.flatMap { point in
            NSScreen.screens.first { $0.frame.contains(point) }
        }
        guard let targetScreen = clickedScreen ?? window.screen else { return }

        if isVisible && screen == targetScreen {
            if toggling { dismiss() }
            return
        }

        let clickAnchor = mouseLocation.map { CGPoint(x: $0.x, y: targetScreen.visibleFrame.maxY) }
        guard let point = buttonAnchor(button, on: targetScreen) ?? clickAnchor else { return }
        anchor = (button, targetScreen, point)
        updatePosition()
        makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard anchor != nil else { return }
        anchor = nil
        orderOut(nil)
    }

    func windowDidResize(_ notification: Notification) {
        updatePosition()
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    func updatePosition() {
        guard let anchor else { return }
        let point = buttonAnchor(anchor.button, on: anchor.screen) ?? anchor.fallback
        let visibleFrame = anchor.screen.visibleFrame
        let x = max(visibleFrame.minX, min(point.x - frame.width / 2, visibleFrame.maxX - frame.width))
        let top = min(point.y, visibleFrame.maxY) - 4
        let y = min(visibleFrame.maxY, max(top, visibleFrame.minY + frame.height))
        setFrameTopLeftPoint(CGPoint(x: x, y: y))
    }

    private func buttonAnchor(_ button: NSStatusBarButton, on screen: NSScreen) -> CGPoint? {
        guard let window = button.window else { return nil }
        let bounds = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard screen.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { return nil }
        return CGPoint(x: bounds.midX, y: bounds.minY)
    }
}

private struct SessionPanel: View {
    let state: SessionController.State
    let start: (SessionSelection) -> Void
    let replace: (SessionSelection) -> Void
    let stop: () -> Void
    let quit: () -> Void

    @State private var draft: SessionDraft

    init(
        state: SessionController.State,
        initialSelection: SessionSelection,
        start: @escaping (SessionSelection) -> Void,
        replace: @escaping (SessionSelection) -> Void,
        stop: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.state = state
        self.start = start
        self.replace = replace
        self.stop = stop
        self.quit = quit
        _draft = State(initialValue: SessionDraft(selection: initialSelection))
    }

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
                    Button("Replace Timer") {
                        if let validSelection {
                            replace(validSelection)
                        }
                    }
                    .disabled(validSelection == nil)
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

            Text("Keeping the display on may delay automatic locking. macOS handles sleep when you close the lid or choose Sleep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 350)
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
