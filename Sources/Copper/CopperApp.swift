import AppKit
import Combine
import CopperCore
import SwiftUI

@main
@MainActor
struct CopperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store)
        }
        .commands {
            CopperCommands(store: appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: CopperStore
    private let arguments: [String]
    private let backgroundUITest: Bool
    private let captureDiagnosticOnly: Bool
    private var panel: NSWindow?
    private var captureMonitor: GlobalCaptureMonitor?
    private var preferencesCancellable: AnyCancellable?
    private var keyMonitor: Any?
    private var editorWindows: [NSWindow] = []
    private var captureToastController: CaptureToastController?

    override init() {
        let arguments = ProcessInfo.processInfo.arguments
        self.arguments = arguments
        self.backgroundUITest = arguments.contains("--background-ui-test")
            || ProcessInfo.processInfo.environment["COPPER_BACKGROUND_UI_TEST"] == "1"
        self.captureDiagnosticOnly = arguments.contains("--capture-diagnostic-only")

        if let storePath = arguments.first(where: { $0.hasPrefix("--store-path=") }) {
            let path = String(storePath.dropFirst("--store-path=".count))
            self.store = CopperStore(fileURL: URL(fileURLWithPath: path), seedIfEmpty: true)
        } else {
            self.store = CopperStore()
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if backgroundUITest {
            let testWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            testWindow.title = "Copper — Background UI Test"
            testWindow.level = .normal
            testWindow.collectionBehavior = []
            testWindow.appearance = NSAppearance(named: .aqua)
            testWindow.isOpaque = false
            testWindow.backgroundColor = .clear
            testWindow.hasShadow = true
            testWindow.setFrameAutosaveName("CopperBackgroundUITestWindow")
            if captureDiagnosticOnly {
                // The capture diagnostic intentionally has no SwiftUI list graph;
                // it exercises AX selection and toast placement in isolation.
                testWindow.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 760))
            } else {
                testWindow.contentView = fixedHostingView(backgroundTestPanelContent())
            }
            testWindow.center()
            positionBackgroundTestWindowIfRequested(testWindow)
            // Make the normal-level window inspectable without activating Copper.
            // A frontmost user app can cover it naturally.
            testWindow.orderFront(nil)
            NSApp.deactivate()
            self.panel = testWindow
        } else {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
                styleMask: [.borderless, .nonactivatingPanel, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.appearance = NSAppearance(named: .aqua)
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.setFrameAutosaveName("CopperCompanionPanel")
            panel.contentView = fixedHostingView(MainPanelView(store: store))
            panel.center()
            // Keep the production companion visible without stealing focus from
            // the app the user is working in.
            panel.orderFrontRegardless()
            self.panel = panel
        }

        store.openEditor = { [weak self] noteID in
            self?.openEditor(noteID: noteID)
        }

        captureToastController = CaptureToastController()
        // Computer Use must never observe or intercept the user's keyboard. The
        // production path retains both the global capture monitor and the local
        // Copper shortcut monitor unchanged.
        if !backgroundUITest {
            let monitor = GlobalCaptureMonitor(shortcut: store.preferences.captureShortcut) { [weak self] in
                Task { @MainActor in self?.captureSelectedText() }
            }
            monitor.start()
            captureMonitor = monitor
            preferencesCancellable = store.$preferences
                .map(\.captureShortcut)
                .removeDuplicates()
                .sink { [weak monitor] shortcut in monitor?.update(shortcut: shortcut) }
            installKeyMonitor()
        }
        if !backgroundUITest {
            AccessibilityReader.promptForTrustIfNeeded()
        }
        writeAccessibilityDiagnosticIfRequested()
        writeWindowDiagnosticIfRequested()
        if backgroundUITest, arguments.contains("--capture-on-launch") {
            // Read the named process's existing AX focus without activating
            // Copper or the source app. If that app no longer exposes its
            // selection while inactive, the diagnostic records a limitation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.performCaptureDiagnosticIfRequested()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureMonitor?.stop()
        captureMonitor = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        preferencesCancellable = nil
    }

    @discardableResult
    private func captureSelectedText(applicationIdentifier: String? = nil) -> (selection: CapturedSelection, note: CopperNote)? {
        let selected = applicationIdentifier.flatMap(AccessibilityReader.selectedSelection(applicationIdentifier:))
            ?? AccessibilityReader.selectedSelection()
        guard let selected else {
            store.showToast("Select text to capture", kind: .neutral)
            return nil
        }
        guard let note = store.addNote(markdown: selected.markdown) else {
            store.showToast("Could not capture selection", kind: .error)
            return nil
        }
        // Let the list's Published update finish its AppKit constraint pass before
        // updating the separate toast hosting view. This avoids a SwiftUI/AppKit
        // constraint assertion when capture and toast creation happen together.
        let sourceFrame = selected.sourceFrame
        DispatchQueue.main.async { [weak self] in
            self?.captureToastController?.show(message: "Captured", sourceFrame: sourceFrame)
        }
        return (selected, note)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel != nil else { return event }

            // A non-activating panel can receive key events without becoming
            // NSApp.keyWindow. Keep separate editor windows' normal text editing
            // behaviour intact, while allowing the companion panel's configurable
            // shortcuts to be handled inside Copper.
            if let keyWindow = NSApp.keyWindow,
               self.editorWindows.contains(where: { $0 === keyWindow }) {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Keep ordinary typing and Space/Escape editing behaviour intact. Command
            // shortcuts are handled here because a borderless accessory panel does not
            // consistently route them through SwiftUI's scene command system.
            if let panel = self.panel,
               (panel.firstResponder is NSTextView || panel.firstResponder is NSTextField),
               !modifiers.contains(.command) {
                return event
            }

            if CopperShortcut.parse(store.preferences.copyShortcut)?.matches(event) == true {
                _ = store.copySelected(asList: false)
                return nil
            }
            if CopperShortcut.parse(store.preferences.copyAsListShortcut)?.matches(event) == true {
                _ = store.copySelected(asList: true)
                return nil
            }
            if CopperShortcut.parse(store.preferences.markDoneShortcut)?.matches(event) == true {
                store.toggleSelectedCompletion()
                return nil
            }
            if CopperShortcut.parse("⇧⌘M")?.matches(event) == true {
                store.mergeSelected()
                return nil
            }
            return event
        }
    }

    private func writeAccessibilityDiagnosticIfRequested() {
        let outputPrefix = "--accessibility-diagnostic-output="
        guard let outputArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(outputPrefix) }) else {
            return
        }

        let outputPath = String(outputArgument.dropFirst(outputPrefix.count))
        guard !outputPath.isEmpty else { return }

        let report: [String: Any] = [
            "isTrusted": AccessibilityReader.isTrusted,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? NSNull(),
            "bundlePath": Bundle.main.bundleURL.path,
            "executablePath": Bundle.main.executableURL?.path ?? NSNull(),
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "backgroundUITest": backgroundUITest,
            "keyboardMonitorsInstalled": captureMonitor != nil || keyMonitor != nil,
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        } catch {
            fputs("[DEBUG-copper-tcc] Could not write Accessibility diagnostic: \(error)\n", stderr)
        }

        if ProcessInfo.processInfo.arguments.contains("--accessibility-diagnostic-exit") {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private func backgroundTestPanelContent() -> some View {
        let base = MainPanelView(store: store)
            .environment(\.copperForceReduceMotion, arguments.contains("--force-reduce-motion"))
            .environment(
                \.copperForceDifferentiateWithoutColor,
                arguments.contains("--force-differentiate-without-color")
            )
            .environment(\.copperForceHighContrast, arguments.contains("--force-high-contrast"))

        if arguments.contains("--force-accessibility-scale") {
            base.dynamicTypeSize(.accessibility3)
        } else {
            base
        }
    }

    private func positionBackgroundTestWindowIfRequested(_ window: NSWindow) {
        let prefix = "--background-ui-test-screen-index="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }),
              let index = Int(argument.dropFirst(prefix.count)),
              NSScreen.screens.indices.contains(index) else { return }

        let visible = NSScreen.screens[index].visibleFrame
        let frame = window.frame
        window.setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2
        ))
    }

    private func writeWindowDiagnosticIfRequested() {
        let outputPrefix = "--window-diagnostic-output="
        guard let outputArgument = arguments.first(where: { $0.hasPrefix(outputPrefix) }) else {
            return
        }
        let outputPath = String(outputArgument.dropFirst(outputPrefix.count))
        guard !outputPath.isEmpty else { return }

        // Deactivation and AppKit window ordering settle on the next run-loop
        // turns. Sample afterwards so the report observes the actual state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, let window = self.panel else { return }
            let frame = window.frame
            let screens = NSScreen.screens.map { screen -> [String: Any] in
                let screenFrame = screen.frame
                return [
                    "x": Double(screenFrame.origin.x),
                    "y": Double(screenFrame.origin.y),
                    "width": Double(screenFrame.size.width),
                    "height": Double(screenFrame.size.height),
                ]
            }
            let report: [String: Any] = [
                "backgroundUITest": self.backgroundUITest,
                "applicationActive": NSApp.isActive,
                "keyboardMonitorsInstalled": self.captureMonitor != nil || self.keyMonitor != nil,
                "windowClass": String(describing: type(of: window)),
                "windowLevel": window.level.rawValue,
                "collectionBehaviorRawValue": Int64(window.collectionBehavior.rawValue),
                "isFloatingPanel": (window as? NSPanel)?.isFloatingPanel ?? false,
                "isKeyWindow": window.isKeyWindow,
                "isVisible": window.isVisible,
                "windowFrame": [
                    "x": Double(frame.origin.x),
                    "y": Double(frame.origin.y),
                    "width": Double(frame.size.width),
                    "height": Double(frame.size.height),
                ],
                "screenCount": screens.count,
                "screens": screens,
                "forcedReduceMotion": self.arguments.contains("--force-reduce-motion"),
                "forcedDifferentiateWithoutColor": self.arguments.contains("--force-differentiate-without-color"),
                "forcedHighContrast": self.arguments.contains("--force-high-contrast"),
                "forcedAccessibilityScale": self.arguments.contains("--force-accessibility-scale"),
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            } catch {
                fputs("[DEBUG-copper-window] Could not write window diagnostic: \(error)\n", stderr)
            }

            if self.arguments.contains("--window-diagnostic-exit") {
                NSApp.terminate(nil)
            }
        }
    }

    private func performCaptureDiagnosticIfRequested() {
        let applicationIdentifier = arguments.first(where: { $0.hasPrefix("--capture-application-bundle-id=") })
            .map { String($0.dropFirst("--capture-application-bundle-id=".count)) }
        let result = captureSelectedText(applicationIdentifier: applicationIdentifier)
        guard let outputArgument = arguments.first(where: { $0.hasPrefix("--capture-diagnostic-output=") }) else {
            return
        }
        let outputPath = String(outputArgument.dropFirst("--capture-diagnostic-output=".count))
        guard !outputPath.isEmpty else { return }

        // The toast is intentionally deferred by one main-queue turn after the
        // store mutation. Write the report after that turn so its visibility and
        // focus state are observable rather than merely inferred.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            var report: [String: Any] = [
                "captured": result != nil,
                "backgroundUITest": self.backgroundUITest,
                "keyboardMonitorsInstalled": self.captureMonitor != nil || self.keyMonitor != nil,
                "applicationActive": NSApp.isActive,
                "activeSectionID": self.store.activeSectionID?.uuidString ?? NSNull(),
                "noteID": result?.note.id.uuidString ?? NSNull(),
                "noteMarkdown": result?.note.markdown ?? NSNull(),
                "toastExpected": result != nil,
            ]
            if let frame = result?.selection.sourceFrame {
                report["sourceFrame"] = [
                    "x": Double(frame.origin.x),
                    "y": Double(frame.origin.y),
                    "width": Double(frame.size.width),
                    "height": Double(frame.size.height),
                ]
            } else {
                report["sourceFrame"] = NSNull()
            }
            if result == nil, let applicationIdentifier {
                report["selectionProbe"] = AccessibilityReader.selectionProbe(applicationIdentifier: applicationIdentifier)
            }
            report["toastState"] = self.captureToastController?.diagnosticState() ?? [
                "visible": false,
                "isKeyWindow": false,
                "level": NSNull(),
            ]

            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            } catch {
                fputs("[DEBUG-copper-capture] Could not write capture diagnostic: \(error)\n", stderr)
            }
        }
    }

    private func openEditor(noteID: UUID) {
        guard store.notes.contains(where: { $0.id == noteID }) else { return }
        let editor = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        editor.title = "Copper — Edit Note"
        editor.isReleasedWhenClosed = false
        editor.contentView = fixedHostingView(EditorView(store: store, noteID: noteID))
        editor.center()
        if backgroundUITest {
            editor.orderFront(nil)
            NSApp.deactivate()
        } else {
            editor.makeKeyAndOrderFront(nil)
        }
        editorWindows.append(editor)
    }
}

@MainActor
final class CaptureToastController {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func diagnosticState() -> [String: Any] {
        guard let panel else {
            return ["visible": false, "isKeyWindow": false, "level": NSNull()]
        }
        let frame = panel.frame
        return [
            "visible": panel.isVisible,
            "isKeyWindow": panel.isKeyWindow,
            "level": panel.level.rawValue,
            "x": Double(frame.origin.x),
            "y": Double(frame.origin.y),
            "width": Double(frame.size.width),
            "height": Double(frame.size.height),
        ]
    }

    func show(message: String, sourceFrame: NSRect?) {
        dismissalTask?.cancel()
        let toast = CopperToast(message: message, kind: .capture)
        let toastSize = NSSize(width: 128, height: 38)
        let toastPanel: NSPanel
        if let panel {
            toastPanel = panel
            toastPanel.contentView = makeCaptureToastView(message: toast.message)
        } else {
            toastPanel = NSPanel(
                contentRect: NSRect(origin: .zero, size: toastSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            toastPanel.isFloatingPanel = true
            toastPanel.level = .floating
            toastPanel.hidesOnDeactivate = false
            toastPanel.becomesKeyOnlyIfNeeded = false
            toastPanel.ignoresMouseEvents = true
            toastPanel.isOpaque = false
            toastPanel.backgroundColor = .clear
            toastPanel.hasShadow = true
            toastPanel.collectionBehavior = [.moveToActiveSpace]
            toastPanel.contentView = makeCaptureToastView(message: toast.message)
            panel = toastPanel
        }

        toastPanel.setFrame(positionedNear: sourceFrame, size: toastSize)
        // orderFront does not activate the app or make the panel key.
        toastPanel.orderFront(nil)
        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }
}

@MainActor
private func makeCaptureToastView(message: String) -> NSView {
    let content = NSView(frame: NSRect(x: 0, y: 0, width: 128, height: 38))
    content.wantsLayer = true
    content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
    content.layer?.cornerRadius = 19

    let icon = NSImageView(image: NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Captured") ?? NSImage())
    icon.contentTintColor = .white
    icon.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(labelWithString: message)
    label.textColor = .white
    label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    label.alignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false

    let stack = NSStackView(views: [icon, label])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(stack)

    NSLayoutConstraint.activate([
        icon.widthAnchor.constraint(equalToConstant: 14),
        icon.heightAnchor.constraint(equalToConstant: 14),
        stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 12),
        stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
    ])
    return content
}

@MainActor
private func fixedHostingView<Content: View>(_ rootView: Content) -> NSHostingView<Content> {
    let hostingView = NSHostingView(rootView: rootView)
    // Copper windows have explicit AppKit frames. Prevent SwiftUI from trying to
    // animate the window size when a note or toast changes its content graph.
    hostingView.sizingOptions = []
    return hostingView
}

private extension NSPanel {
    func setFrame(positionedNear sourceFrame: NSRect?, size: NSSize) {
        let fallbackScreen = NSScreen.main ?? NSScreen.screens.first
        let sourcePoint = sourceFrame.map { NSPoint(x: $0.minX, y: $0.minY) }
        let screen = sourcePoint.flatMap { point in
            NSScreen.screens.first(where: { $0.frame.contains(point) })
        } ?? fallbackScreen
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let x = min(max(sourceFrame?.minX ?? visible.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
        // Accessibility coordinates have a top-left origin; AppKit uses bottom-left.
        let y: CGFloat
        if let sourceFrame, let screen {
            y = screen.frame.maxY - sourceFrame.maxY - size.height - 12
        } else {
            y = visible.maxY - size.height - 24
        }
        setFrame(NSRect(x: x, y: max(visible.minY + 8, y), width: size.width, height: size.height), display: true)
    }
}

struct CopperCommands: Commands {
    @ObservedObject var store: CopperStore

    var body: some Commands {
        CommandMenu("Copper") {
            Button("Copy") { _ = store.copySelected(asList: false) }
                .keyboardShortcut("c", modifiers: [.command])
            Button("Copy as List") { _ = store.copySelected(asList: true) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Toggle Done") { store.toggleSelectedCompletion() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Merge Notes") { store.mergeSelected() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Button("Clear Selection") { store.clearSelection() }
                .keyboardShortcut(.escape, modifiers: [])
        }
    }
}
