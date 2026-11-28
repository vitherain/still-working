import AppKit
import Combine
import CoreServices
import ServiceManagement
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
    private var requestedPanelOnLaunch = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(openApplication(_:reply:)),
            forEventClass: kCoreEventClass, andEventID: kAEOpenApplication
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel(_:))
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        item.button?.setAccessibilityLabel("StillWorking")

        let panel = SessionPanel(session: session, quit: { [weak self] in self?.quit() })
        settingsPanel.contentViewController = NSHostingController(rootView: panel)
        sessionObserver = session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.renderStatusItem(state)
            }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil
        )
        if requestedPanelOnLaunch {
            showPanelAfterLaunching()
        }
    }

    @objc private func openApplication(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        // Read the login marker while AppKit is handling the open event.
        guard event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue != keyAELaunchedAsLogInItem else { return }
        if statusItem == nil {
            requestedPanelOnLaunch = true
        } else {
            showPanelAfterLaunching()
        }
    }

    private func showPanelAfterLaunching() {
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
        let origin = CGPoint(x: x.rounded(), y: (y - frame.height).rounded())
        if frame.origin != origin {
            setFrameOrigin(origin)
        }
    }

    private func buttonAnchor(_ button: NSStatusBarButton, on screen: NSScreen) -> CGPoint? {
        guard let window = button.window else { return nil }
        let bounds = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard screen.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) else { return nil }
        return CGPoint(x: bounds.midX, y: bounds.minY)
    }
}

private struct SessionPanel: View {
    let session: SessionController
    let quit: () -> Void
    @State private var draft: SessionDraft
    @State private var isActive: Bool

    init(session: SessionController, quit: @escaping () -> Void) {
        self.session = session
        self.quit = quit
        _draft = State(initialValue: SessionDraft(selection: session.rememberedSelection))
        _isActive = State(initialValue: session.state.status == .active)
    }

    var body: some View {
        let selection = draft.selection
        let replacing = isActive
        VStack(alignment: .leading, spacing: 12) {
            Text("StillWorking")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            SessionSummary(session: session)

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
                .onSubmit { submitDraft(replacing: replacing) }
            }

            if case let .failure(problem) = selection {
                Text(problem.rawValue)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Keep display on", isOn: Binding(
                get: { draft.keepDisplayOn },
                set: { keepDisplayOn in
                    if session.state.status == .active {
                        session.setDisplayMode(keepDisplayOn ? .displayOn : .computerOnly)
                    } else {
                        draft.keepDisplayOn = keepDisplayOn
                    }
                }
            ))

            HStack {
                Button(replacing ? "Replace Timer" : "Start") {
                    submitDraft(replacing: replacing)
                }
                .keyboardShortcut(.defaultAction)
                .disabled((try? selection.get()) == nil)

                if replacing {
                    Button("Stop") { session.stop() }
                        .keyboardShortcut(".", modifiers: .command)
                }
                Spacer()
                Button(replacing ? "Stop Timer and Quit" : "Quit", action: quit)
                    .keyboardShortcut("q", modifiers: .command)
            }

            Text("Keeping the display on may delay automatic locking. macOS handles sleep when you close the lid or choose Sleep.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            LaunchAtLoginControl()
        }
        .padding(16)
        .frame(width: 350)
        .onReceive(session.$state.map(\.displayMode).removeDuplicates()) { mode in
            isActive = mode != nil
            if let mode {
                draft.keepDisplayOn = mode == .displayOn
            }
        }
    }

    private func submitDraft(replacing: Bool) {
        guard let selection = try? draft.selection.get() else { return }
        if replacing {
            session.replace(selection)
        } else {
            session.start(selection)
        }
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

private struct LaunchAtLoginControl: View {
    @State private var status = SMAppService.mainApp.status
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at Login", isOn: Binding(
                get: { status == .enabled }, set: { setEnabled($0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(status == .requiresApproval)

            if status == .requiresApproval {
                Text("macOS requires approval in Login Items.")
                    .foregroundStyle(.secondary)
                Button("Open Login Items in System Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            if let failure {
                Text(failure)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            let currentStatus = SMAppService.mainApp.status
            if status != currentStatus {
                failure = nil
                status = currentStatus
            }
        }
    }

    private func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        let currentStatus = service.status
        failure = nil
        defer { status = service.status }

        do {
            if enabled && currentStatus != .enabled && currentStatus != .requiresApproval {
                try service.register()
            } else if !enabled && (currentStatus == .enabled || currentStatus == .requiresApproval) {
                try service.unregister()
            }
        } catch {
            let action = enabled ? "enable" : "disable"
            failure = "Could not \(action) Launch at Login. \(error.localizedDescription)"
        }
    }
}

private struct SessionSummary: View {
    @ObservedObject var session: SessionController

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 12) {
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
