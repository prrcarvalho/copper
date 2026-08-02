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
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store: CopperStore
    private let arguments: [String]
    private let backgroundUITest: Bool
    private let captureDiagnosticOnly: Bool
    private var panel: NSWindow?
    private var captureMonitor: GlobalCaptureMonitor?
    private var preferencesCancellable: AnyCancellable?
    private var editorWindows: [NSWindow] = []
    private var captureToastController: CaptureToastController?
    private var liveCaptureGestureCount = 0
    private var liveCaptureSuccessCount = 0
    private var showPanelObserver: NSObjectProtocol?

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

        showPanelObserver = NotificationCenter.default.addObserver(
            forName: .copperShowPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showCopper(activate: true)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(
            backgroundUITest
                ? CopperWindowLifecycleContract.backgroundUITestActivationPolicy
                : CopperWindowLifecycleContract.productionActivationPolicy
        )

        if backgroundUITest {
            let testWindow = CopperBackgroundUITestWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            testWindow.title = "Copper — Background UI Test"
            testWindow.level = CopperWindowLifecycleContract.backgroundUITestWindowLevel
            testWindow.collectionBehavior = CopperWindowLifecycleContract.backgroundUITestCollectionBehavior
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
            let visibleFrame = visibleFrame(for: nil)
            let panel = CopperPanel(
                contentRect: CopperWindowGeometry.centeredFrame(in: visibleFrame),
                styleMask: CopperPanel.companionStyleMask,
                backing: .buffered,
                defer: false
            )
            panel.title = "Copper"
            panel.isFloatingPanel = false
            panel.level = CopperWindowLifecycleContract.productionWindowLevel
            panel.appearance = NSAppearance(named: .aqua)
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.titlebarSeparatorStyle = .none
            panel.isMovable = true
            // Only CopperPanelContentView's narrow top drag strip may move
            // the window. Background dragging would steal card, search,
            // button, composer, and editor hit targets.
            panel.isMovableByWindowBackground = false
            panel.isReleasedWhenClosed = false
            panel.minSize = CopperWindowGeometry.minimumSize
            panel.maxSize = CopperWindowGeometry.maximumSize(for: visibleFrame)
            panel.collectionBehavior = CopperWindowLifecycleContract.productionCollectionBehavior
            for button in [
                NSWindow.ButtonType.closeButton,
                .miniaturizeButton,
                .zoomButton,
            ] {
                panel.standardWindowButton(button)?.isHidden = true
            }
            panel.setFrameAutosaveName(CopperWindowGeometry.autosaveName)
            if !panel.setFrameUsingName(CopperWindowGeometry.autosaveName) {
                panel.setFrame(CopperWindowGeometry.centeredFrame(in: visibleFrame), display: false)
            }
            panel.contentView = CopperPanelContentView(
                hostingView: fixedHostingView(
                    CopperMainPanelHostingView(rootView: MainPanelView(store: store))
                )
            )
            panel.cancelOperationHandler = {
                NotificationCenter.default.post(name: .copperEscape, object: nil)
            }
            // Assigning the hosting view can reset AppKit's default size
            // limits, so apply the explicit companion contract afterwards.
            constrainProductionPanel(panel)
            panel.delegate = self
            // A normal-level order does not activate Copper or force it above
            // the user's current application.
            panel.orderFront(nil)
            self.panel = panel
            // SwiftUI updates NSHostingView's intrinsic size on the next run
            // loop and can restore AppKit's unconstrained defaults. Reapply the
            // explicit companion limits after that layout pass.
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let self, let panel else { return }
                self.constrainProductionPanel(panel)
            }
        }

        store.openEditor = { [weak self] noteID in
            self?.openEditor(noteID: noteID)
        }

        captureToastController = CaptureToastController()
        // Computer Use must never observe the user's keyboard. Production has
        // one observational global capture monitor; in-app shortcuts are normal
        // menu commands/key handlers, never a local event monitor.
        if !backgroundUITest {
            let monitor = GlobalCaptureMonitor(shortcut: store.preferences.captureShortcut) { [weak self] in
                Task { @MainActor in self?.handleGlobalCaptureGesture() }
            }
            monitor.start()
            captureMonitor = monitor
            preferencesCancellable = store.$preferences
                .map(\.captureShortcut)
                .removeDuplicates()
                .sink { [weak monitor] shortcut in monitor?.update(shortcut: shortcut) }
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

    func applicationDidResignActive(_ notification: Notification) {
        guard !backgroundUITest else { return }
        NotificationCenter.default.post(name: .copperDismissTransientUI, object: panel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !backgroundUITest else { return false }
        showCopper(activate: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !backgroundUITest, panel != nil else { return }
        showCopper(activate: false, focus: true)
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        guard let panel = panel as? CopperPanel else { return }
        panelGeometryDidChange(panel, saveFrame: false)
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? CopperPanel else { return }
        panelGeometryDidChange(panel, saveFrame: true)
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? CopperPanel else { return }
        panelGeometryDidChange(panel, saveFrame: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !backgroundUITest,
              let resignedPanel = notification.object as? CopperPanel,
              resignedPanel === panel else { return }

        // A panel key loss can be a transient responder bounce. Wait for
        // AppKit to settle before deciding whether another Copper window owns
        // focus or the application actually left the foreground.
        DispatchQueue.main.async { [weak self, weak resignedPanel] in
            guard let self,
                  let resignedPanel,
                  let currentPanel = self.panel as? CopperPanel,
                  currentPanel === resignedPanel,
                  !currentPanel.isKeyWindow else { return }

            let hasDifferentKeyWindow = NSApp.keyWindow.map { $0 !== currentPanel } ?? false
            guard !currentPanel.isVisible || !NSApp.isActive || hasDifferentKeyWindow else { return }
            NotificationCenter.default.post(name: .copperDismissTransientUI, object: currentPanel)
        }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let panel = notification.object as? CopperPanel else { return }
        panelGeometryDidChange(panel, saveFrame: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        captureMonitor?.stop()
        captureMonitor = nil
        preferencesCancellable = nil
        if let observer = showPanelObserver {
            NotificationCenter.default.removeObserver(observer)
            showPanelObserver = nil
        }
    }

    private func showCopper(activate: Bool, focus: Bool = true) {
        guard !backgroundUITest, let panel = panel as? CopperPanel else { return }
        if panel.isMiniaturized {
            panel.deminiaturize(nil)
        }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
        if focus {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFront(nil)
        }
    }

    private func visibleFrame(for window: NSWindow?) -> NSRect {
        guard let window else {
            return (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
                ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
        let referenceFrame = window.frame
        let screen = NSScreen.screens.max { lhs, rhs in
            intersectionArea(referenceFrame, lhs.frame) < intersectionArea(referenceFrame, rhs.frame)
        }
        if let screen, intersectionArea(referenceFrame, screen.frame) > 0 {
            return screen.visibleFrame
        }
        return (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func intersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
        lhs.intersection(rhs).width * lhs.intersection(rhs).height
    }

    private func constrainProductionPanel(_ panel: CopperPanel) {
        guard !backgroundUITest else { return }
        _ = panel.applyCompanionConstraints(to: visibleFrame(for: panel))
    }

    private func panelGeometryDidChange(_ panel: CopperPanel, saveFrame: Bool) {
        guard !backgroundUITest else { return }
        constrainProductionPanel(panel)
        if saveFrame {
            panel.saveFrame(usingName: CopperWindowGeometry.autosaveName)
        }
    }

    @discardableResult
    private func captureSelectedText(applicationIdentifier: String? = nil) -> (selection: CapturedSelection, note: CopperNote)? {
        let selected = applicationIdentifier.flatMap(AccessibilityReader.selectedSelection(applicationIdentifier:))
            ?? AccessibilityReader.selectedSelection()
        guard let selected else {
            store.showToast("Select text to capture", kind: .neutral)
            return nil
        }
        guard let note = store.capture(selected) else {
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

    private func handleGlobalCaptureGesture() {
        let noteCountBefore = store.notes.count
        let clipboardChangeCountBefore = NSPasteboard.general.changeCount
        let toastPresentationCountBefore = captureToastController?.presentationCount ?? 0
        let frontmostApplicationBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        liveCaptureGestureCount += 1
        let result = captureSelectedText()
        if result != nil {
            liveCaptureSuccessCount += 1
        }
        writeLiveCaptureDiagnosticIfRequested(
            result: result,
            noteCountBefore: noteCountBefore,
            clipboardChangeCountBefore: clipboardChangeCountBefore,
            toastPresentationCountBefore: toastPresentationCountBefore,
            frontmostApplicationBefore: frontmostApplicationBefore
        )
    }

    private func writeLiveCaptureDiagnosticIfRequested(
        result: (selection: CapturedSelection, note: CopperNote)?,
        noteCountBefore: Int,
        clipboardChangeCountBefore: Int,
        toastPresentationCountBefore: Int,
        frontmostApplicationBefore: String?
    ) {
        let outputPrefix = "--live-capture-diagnostic-output="
        guard let outputArgument = arguments.first(where: { $0.hasPrefix(outputPrefix) }) else {
            return
        }
        let outputPath = String(outputArgument.dropFirst(outputPrefix.count))
        guard !outputPath.isEmpty else { return }

        // The monitor callback records only counters and state after the normal
        // capture path has completed. It never consumes, replaces, or reposts
        // the originating keyboard event.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            let frontmostApplicationAfter = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            var report: [String: Any] = [
                "gestureCount": self.liveCaptureGestureCount,
                "successCount": self.liveCaptureSuccessCount,
                "captured": result != nil,
                "noteCountBeforeLatestGesture": noteCountBefore,
                "noteCountAfterLatestGesture": self.store.notes.count,
                "noteDeltaLatestGesture": self.store.notes.count - noteCountBefore,
                "toastPresentationDeltaLatestGesture":
                    (self.captureToastController?.presentationCount ?? 0) - toastPresentationCountBefore,
                "clipboardChangeCountBeforeLatestGesture": clipboardChangeCountBefore,
                "clipboardChangeCountAfterLatestGesture": NSPasteboard.general.changeCount,
                "clipboardUnchangedLatestGesture": NSPasteboard.general.changeCount == clipboardChangeCountBefore,
                "frontmostApplicationBundleIDBefore": frontmostApplicationBefore ?? NSNull(),
                "frontmostApplicationBundleIDAfter": frontmostApplicationAfter ?? NSNull(),
                "sourceApplicationRemainedActive": frontmostApplicationBefore != nil
                    && frontmostApplicationBefore == frontmostApplicationAfter,
                "applicationActive": NSApp.isActive,
                "globalCaptureMonitorInstalled": self.captureMonitor != nil,
                "localKeyboardMonitorInstalled": false,
                "noteID": result?.note.id.uuidString ?? NSNull(),
                "noteMarkdown": result?.note.markdown ?? NSNull(),
                "selectionSource": result?.selection.source.rawValue ?? NSNull(),
                "toastState": self.captureToastController?.diagnosticState() ?? [
                    "visible": false,
                    "isKeyWindow": false,
                    "presentationCount": 0,
                ],
            ]
            if let result, let frontmostApplicationBefore {
                report["selectionPreservedAfter"] = AccessibilityReader
                    .selectedSelection(applicationIdentifier: frontmostApplicationBefore)?.markdown == result.selection.markdown
                report["matchingNoteCountAfter"] = self.store.notes.filter {
                    $0.markdown == result.note.markdown
                }.count
            } else {
                report["selectionPreservedAfter"] = NSNull()
                report["matchingNoteCountAfter"] = 0
            }
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

            do {
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            } catch {
                fputs("[DEBUG-copper-live-capture] Could not write live capture diagnostic: \(error)\n", stderr)
            }
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
            "activationPolicy": NSApp.activationPolicy().rawValue,
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "backgroundUITest": backgroundUITest,
            "keyboardMonitorsInstalled": captureMonitor != nil,
            "globalCaptureMonitorInstalled": captureMonitor != nil,
            "localKeyboardMonitorInstalled": false,
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
                "activationPolicy": NSApp.activationPolicy().rawValue,
                "applicationActive": NSApp.isActive,
                "keyboardMonitorsInstalled": self.captureMonitor != nil,
                "globalCaptureMonitorInstalled": self.captureMonitor != nil,
                "localKeyboardMonitorInstalled": false,
                "windowClass": String(describing: type(of: window)),
                "styleMaskRawValue": Int64(window.styleMask.rawValue),
                "windowLevel": window.level.rawValue,
                "collectionBehaviorRawValue": Int64(window.collectionBehavior.rawValue),
                "isFloatingPanel": (window as? NSPanel)?.isFloatingPanel ?? false,
                "isMovable": window.isMovable,
                "isMovableByWindowBackground": window.isMovableByWindowBackground,
                "isResizable": window.isResizable,
                "isMiniaturized": window.isMiniaturized,
                "minimumSize": [
                    "width": Double(window.minSize.width),
                    "height": Double(window.minSize.height),
                ],
                "maximumSize": [
                    "width": Double(window.maxSize.width),
                    "height": Double(window.maxSize.height),
                ],
                "frameAutosaveName": window.frameAutosaveName,
                "dragStripFrame": (window.contentView as? CopperPanelContentView).map { strip in
                    [
                        "x": Double(strip.diagnosticDragStripFrame.origin.x),
                        "y": Double(strip.diagnosticDragStripFrame.origin.y),
                        "width": Double(strip.diagnosticDragStripFrame.width),
                        "height": Double(strip.diagnosticDragStripFrame.height),
                    ]
                } ?? NSNull(),
                "dragHitTestClass": (window.contentView as? CopperPanelContentView).map { strip in
                    String(describing: type(of: strip.hitTest(NSPoint(
                        x: strip.bounds.midX,
                        y: strip.bounds.maxY - 62
                    )) ?? NSView()))
                } ?? NSNull(),
                "closeButtonHidden": window.standardWindowButton(.closeButton)?.isHidden ?? false,
                "miniaturizeButtonHidden": window.standardWindowButton(.miniaturizeButton)?.isHidden ?? false,
                "zoomButtonHidden": window.standardWindowButton(.zoomButton)?.isHidden ?? false,
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
        let noteCountBefore = store.notes.count
        let clipboardChangeCountBefore = NSPasteboard.general.changeCount
        let toastPresentationCountBefore = captureToastController?.presentationCount ?? 0
        let frontmostApplicationBefore = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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
                "keyboardMonitorsInstalled": self.captureMonitor != nil,
                "globalCaptureMonitorInstalled": self.captureMonitor != nil,
                "localKeyboardMonitorInstalled": false,
                "applicationActive": NSApp.isActive,
                "frontmostApplicationBundleIDBefore": frontmostApplicationBefore ?? NSNull(),
                "frontmostApplicationBundleIDAfter": NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? NSNull(),
                "activeSectionID": self.store.activeSectionID?.uuidString ?? NSNull(),
                "noteID": result?.note.id.uuidString ?? NSNull(),
                "noteMarkdown": result?.note.markdown ?? NSNull(),
                "selectionSource": result?.selection.source.rawValue ?? NSNull(),
                "noteCountBefore": noteCountBefore,
                "noteCountAfter": self.store.notes.count,
                "noteDelta": self.store.notes.count - noteCountBefore,
                "toastExpected": result != nil,
                "toastPresentationDelta": (self.captureToastController?.presentationCount ?? 0) - toastPresentationCountBefore,
                "clipboardChangeCountBefore": clipboardChangeCountBefore,
                "clipboardChangeCountAfter": NSPasteboard.general.changeCount,
                "clipboardUnchanged": NSPasteboard.general.changeCount == clipboardChangeCountBefore,
            ]
            if let result, let applicationIdentifier {
                report["selectionPreservedAfter"] = AccessibilityReader
                    .selectedSelection(applicationIdentifier: applicationIdentifier)?.markdown == result.selection.markdown
                report["matchingNoteCountAfter"] = self.store.notes.filter {
                    $0.markdown == result.note.markdown
                }.count
            } else {
                report["selectionPreservedAfter"] = NSNull()
                report["matchingNoteCountAfter"] = 0
            }
            if let applicationIdentifier {
                report["selectionProbe"] = AccessibilityReader.selectionProbe(
                    applicationIdentifier: applicationIdentifier
                )
            }
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
    private(set) var presentationCount = 0
    private var lastMessage: String?

    func diagnosticState() -> [String: Any] {
        guard let panel else {
            return [
                "visible": false,
                "isKeyWindow": false,
                "level": NSNull(),
                "presentationCount": presentationCount,
                "lastMessage": lastMessage ?? NSNull(),
            ]
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
            "presentationCount": presentationCount,
            "lastMessage": lastMessage ?? NSNull(),
        ]
    }

    func show(message: String, sourceFrame: NSRect?) {
        dismissalTask?.cancel()
        presentationCount += 1
        lastMessage = message
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
final class CopperMainPanelHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
private func fixedHostingView<Content: View>(_ rootView: Content) -> NSHostingView<Content> {
    fixedHostingView(NSHostingView(rootView: rootView))
}

@MainActor
private func fixedHostingView<Content: View>(_ hostingView: NSHostingView<Content>) -> NSHostingView<Content> {
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

extension Notification.Name {
    static let copperShowPanel = Notification.Name("Copper.ShowPanel")
    static let copperEscape = Notification.Name("Copper.Escape")
    static let copperDismissTransientUI = Notification.Name("Copper.DismissTransientUI")
}

@MainActor
final class CopperBackgroundUITestWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: .copperEscape, object: nil)
    }
}

struct CopperCommands: Commands {
    @ObservedObject var store: CopperStore

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                route(.undo) { _ = store.undo() }
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("Redo") {
                route(.redo) { _ = store.redo() }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                sendTextAction(#selector(NSText.cut(_:)))
            }
            .keyboardShortcut("x", modifiers: [.command])

            commandButton("Copy", shortcut: store.preferences.copyShortcut) {
                if !sendTextAction(#selector(NSText.copy(_:))) {
                    _ = store.copySelected(asList: false)
                }
            }

            if CopperShortcut.parse(store.preferences.copyShortcut)?.canonical != "⌘C" {
                Button("Copy Text") {
                    sendTextAction(#selector(NSText.copy(_:)))
                }
                .keyboardShortcut("c", modifiers: [.command])
            }

            commandButton("Copy as List", shortcut: store.preferences.copyAsListShortcut) {
                if !isEditingText {
                    _ = store.copySelected(asList: true)
                }
            }

            Button("Paste") {
                sendTextAction(#selector(NSText.paste(_:)))
            }
            .keyboardShortcut("v", modifiers: [.command])
        }

        CommandMenu("Copper") {
            Button("Show Copper") {
                NotificationCenter.default.post(name: .copperShowPanel, object: nil)
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()
            commandButton(
                "Toggle Done",
                shortcut: store.preferences.markDoneShortcut
            ) { store.toggleSelectedCompletion() }
            Button("Merge Notes") { store.mergeSelected() }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("Delete Selected Notes or Section") {
                route(.commandDelete) { _ = store.deleteCommandSelection() }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            Divider()
            Button("Clear Selection") {
                route(.escape) { _ = store.handleEscape() }
            }
        }
    }

    private var isEditingText: Bool {
        switch firstResponderKind {
        case .textEditor: return true
        case .other: return false
        }
    }

    private var firstResponderKind: CopperFirstResponderKind {
        guard let responder = NSApp.keyWindow?.firstResponder else { return .other }
        return responder is NSTextView || responder is NSTextField ? .textEditor : .other
    }

    private func route(_ command: CopperKeyCommand, copperAction: () -> Void) {
        switch CopperCommandRouting.destination(for: command, firstResponder: firstResponderKind) {
        case .copper:
            copperAction()
        case .ignored:
            break
        case .textEditor:
            switch command {
            case .plainDelete:
                // No Copper command is registered for plain Delete. The
                // native text responder keeps the event in its own path.
                break
            case .commandDelete:
                // Command-Delete is the native delete-to-beginning-of-line
                // action. It is deliberately never Copper task deletion when
                // an NSTextView/NSTextField is first responder.
                _ = sendTextAction(#selector(NSText.deleteToBeginningOfLine(_:)))
            case .undo:
                _ = sendTextAction(Selector(("undo:")))
            case .redo:
                _ = sendTextAction(Selector(("redo:")))
            case .escape:
                break
            }
        case .textEditorAndCopper:
            _ = store.handleEscape()
            _ = sendTextAction(#selector(NSResponder.cancelOperation(_:)))
        }
    }

    @discardableResult
    private func sendTextAction(_ action: Selector) -> Bool {
        guard isEditingText else { return false }
        return NSApp.sendAction(action, to: NSApp.keyWindow?.firstResponder, from: nil)
    }

    @ViewBuilder
    private func commandButton(
        _ title: String,
        shortcut rawShortcut: String,
        action: @escaping () -> Void
    ) -> some View {
        if let shortcut = CopperShortcut.parse(rawShortcut),
           let equivalent = shortcut.keyEquivalent {
            Button(title, action: action)
                .keyboardShortcut(equivalent, modifiers: shortcut.eventModifiers)
        } else {
            Button(title, action: action)
        }
    }
}

private extension CopperShortcut {
    var keyEquivalent: KeyEquivalent? {
        guard case let .key(key, _) = trigger else { return nil }
        switch key {
        case "SPACE": return .space
        case "ENTER": return .return
        case "ESCAPE": return .escape
        default:
            guard key.count == 1, let character = key.lowercased().first else { return nil }
            return KeyEquivalent(character)
        }
    }

    var eventModifiers: EventModifiers {
        guard case let .key(_, modifiers) = trigger else { return [] }
        var result: EventModifiers = []
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.control) { result.insert(.control) }
        return result
    }
}
