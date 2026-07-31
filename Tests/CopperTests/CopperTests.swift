import AppKit
@testable import CopperCore
import Foundation
import Testing

@Suite("Copper domain and capture", .serialized)
@MainActor
struct CopperTests {
    private func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CopperTests-\(name)-\(UUID().uuidString).json")
    }

    @Test("Production panel can accept keyboard focus without becoming main")
    func productionPanelFocusContract() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
    }

    @Test("Production panel keeps native drag, resize, close and minimize affordances")
    func productionPanelNativeShellContract() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )
        panel.setFrame(NSRect(x: -200, y: -100, width: 800, height: 900), display: false)
        let constraintsApplied = panel.applyCompanionConstraints(
            to: NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        panel.isMovableByWindowBackground = true

        #expect(panel.styleMask.contains(.titled))
        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.resizable))
        #expect(panel.styleMask.contains(.closable))
        #expect(panel.styleMask.contains(.miniaturizable))
        #expect(panel.isResizable)
        #expect(panel.isMovable)
        #expect(panel.isMovableByWindowBackground)
        #expect(constraintsApplied)
        #expect(panel.minSize == CopperWindowGeometry.minimumSize)
        #expect(panel.maxSize.width == 620)
        #expect(panel.maxSize.height == 876)
        #expect(panel.frame == NSRect(x: 0, y: 0, width: 620, height: 876))
    }

    @Test("Companion frame restoration clamps off-screen and oversized frames")
    func companionFrameRestorationClampsToVisibleScreen() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let firstLaunch = CopperWindowGeometry.centeredFrame(in: visible)
        #expect(firstLaunch.size == CopperWindowGeometry.initialSize)
        #expect(firstLaunch.midX == visible.midX)
        #expect(firstLaunch.midY == visible.midY)

        let restored = CopperWindowGeometry.clampedFrame(
            NSRect(x: -800, y: -500, width: 1400, height: 1400),
            to: visible
        )
        #expect(restored.size.width == 620)
        #expect(restored.size.height == 876)
        #expect(restored.minX == visible.minX)
        #expect(restored.minY == visible.minY)
        #expect(restored.maxX == visible.minX + 620)
        #expect(restored.maxY == visible.minY + 876)
    }

    @Test("Command-W close contract hides without destroying the panel")
    func companionCloseHidesPanel() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )
        panel.orderFront(nil)
        panel.performClose(nil)
        #expect(!panel.isVisible)
        panel.orderOut(nil)
    }

    @Test("Active section routes new notes and persists")
    func activeSectionRoutesNotesAndPersists() throws {
        let url = temporaryURL("active-section")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let first = store.addSection(title: "First")
        let second = store.addSection(title: "Second")
        store.setActiveSection(second.id)
        let note = try #require(store.addNote(markdown: "created in active section"))

        #expect(note.sectionID == second.id)
        #expect(first.id != second.id)

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.activeSectionID == second.id)
    }

    @Test("Successive prompts remain ordered and search filters their section")
    func successivePromptsAndSearch() throws {
        let url = temporaryURL("successive-search")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let queue = store.addSection(title: "Queue")
        _ = try #require(store.addNote(markdown: "First queued prompt"))
        _ = try #require(store.addNote(markdown: "Second queued prompt"))

        #expect(store.visibleNotes(for: queue).map(\.markdown) == [
            "First queued prompt",
            "Second queued prompt",
        ])
        store.searchText = "second"
        #expect(store.visibleNotes(for: queue).map(\.markdown) == ["Second queued prompt"])
        store.searchText = "missing"
        #expect(store.visibleNotes(for: queue).isEmpty)
    }

    @Test("Selected completion toggles both directions")
    func selectedCompletionIsReversible() throws {
        let url = temporaryURL("toggle")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "toggle me", sectionID: section.id))
        store.ensureSelected(note.id)

        store.toggleSelectedCompletion()
        #expect(store.notes.first?.isCompleted == true)
        store.toggleSelectedCompletion()
        #expect(store.notes.first?.isCompleted == false)
    }

    @Test("Focused card Space selects it and toggles completion")
    func focusedCardSpaceTogglesCompletion() throws {
        let url = temporaryURL("card-space")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "complete me", sectionID: section.id))

        #expect(store.handleCardSpace(noteID: note.id))
        #expect(store.selectedIDs == Set([note.id]))
        #expect(store.notes.first?.isCompleted == true)
        #expect(store.handleCardSpace(noteID: note.id))
        #expect(store.notes.first?.isCompleted == false)
        #expect(!store.handleCardSpace(noteID: UUID()))
    }

    @Test("Capture shortcut validates syntax, safety, conflicts, and reset")
    func captureShortcutValidation() throws {
        let doubleShift = try #require(CopperShortcut.parse("Shift + Shift"))
        #expect(doubleShift.trigger == .doubleShift)
        #expect(doubleShift.isSafeGlobalCapture)
        #expect(CopperShortcut.parse("Double Shift")?.trigger == .doubleShift)

        let commandShiftC = try #require(CopperShortcut.parse("⌘⇧C"))
        #expect(commandShiftC.canonical == "⌘⇧C")
        #expect(commandShiftC.isSafeGlobalCapture)
        #expect(CopperShortcut.parse("A")?.isSafeGlobalCapture == false)
        #expect(CopperShortcut.parse("⌥C")?.isSafeGlobalCapture == false)
        #expect(CopperShortcut.parse("⌃C")?.isSafeGlobalCapture == false)
        #expect(CopperShortcut.parse("⌘C")?.isSafeGlobalCapture == false)
        let voiceOverShortcut = try #require(CopperShortcut.parse("⌃⌥C"))
        #expect(voiceOverShortcut.usesVoiceOverModifier)
        #expect(!voiceOverShortcut.isSafeGlobalCapture)

        var preferences = CopperPreferences()
        preferences.captureShortcut = preferences.copyShortcut
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "A"
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "⌃⌥C"
        #expect(
            preferences.captureShortcutValidationMessage
                == "Control + Option is reserved for VoiceOver and may alter source-app input."
        )
        preferences.captureShortcut = "⌘⌃⇧C"
        #expect(preferences.captureShortcutValidationMessage == nil)
        preferences.captureShortcut = "not a shortcut with two keys"
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "Shift + Shift"
        #expect(preferences.captureShortcutValidationMessage == nil)

        let url = temporaryURL("shortcut-preferences")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        store.preferences.copyShortcut = "⌘⇧K"
        store.preferences.copyAsListShortcut = "⌘⇧L"
        store.preferences.markDoneShortcut = "⌘⇧D"
        store.save()
        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.preferences.copyShortcut == "⌘⇧K")
        #expect(reloaded.preferences.copyAsListShortcut == "⌘⇧L")
        #expect(reloaded.preferences.markDoneShortcut == "⌘⇧D")
    }

    @Test("Attributed capture converts emphasis and links with plain fallback")
    func markdownConversion() throws {
        let attributed = NSMutableAttributedString(string: "Bold and link")
        attributed.addAttribute(
            .font,
            value: NSFont.boldSystemFont(ofSize: 14),
            range: NSRange(location: 0, length: 4)
        )
        attributed.addAttribute(
            .link,
            value: try #require(URL(string: "https://example.com")),
            range: NSRange(location: 9, length: 4)
        )

        let markdown = try #require(MarkdownConverter.markdown(from: attributed))
        #expect(markdown.contains("**Bold**"))
        #expect(markdown.contains("[link](https://example.com)"))
        #expect(MarkdownConverter.markdown(from: "plain fallback") == "plain fallback")
        let literalPlain = "literal **not bold** [not a link] #1"
        let escapedPlain = try #require(MarkdownConverter.markdown(from: literalPlain))
        #expect(escapedPlain == "literal \\*\\*not bold\\*\\* \\[not a link\\] #1")
        #expect(MarkdownConverter.plainText(from: escapedPlain) == literalPlain)
        let plainBlocks = "# literal heading\n1. literal item\n- literal bullet"
        let escapedBlocks = try #require(MarkdownConverter.markdown(from: plainBlocks))
        #expect(escapedBlocks == "\\# literal heading\n1\\. literal item\n\\- literal bullet")
        #expect(MarkdownConverter.plainText(from: escapedBlocks) == plainBlocks)

        let accessibilityAttributed = NSMutableAttributedString(string: "AX Bold and AX Italic")
        accessibilityAttributed.addAttribute(
            .accessibilityFont,
            value: [
                NSAccessibility.FontAttributeKey.fontName: "Helvetica-Bold",
                .fontSize: 14,
            ],
            range: NSRange(location: 0, length: 7)
        )
        accessibilityAttributed.addAttribute(
            .accessibilityFont,
            value: [
                NSAccessibility.FontAttributeKey.fontName: "Helvetica-Oblique",
                .fontSize: 14,
            ],
            range: NSRange(location: 12, length: 9)
        )
        #expect(MarkdownConverter.markdown(from: accessibilityAttributed) == "**AX Bold** and *AX Italic*")

        let modernAccessibilityAttributed = NSAttributedString(
            string: "Modern bold",
            attributes: [
                .accessibilityFont: [
                    NSAccessibility.FontAttributeKey.fontSize: 24,
                    "AXFontBold": 1,
                ],
            ]
        )
        #expect(MarkdownConverter.markdown(from: modernAccessibilityAttributed) == "**Modern bold**")
    }

    @Test("One captured selection creates exactly one note in the active section")
    func captureCardinalityIsExactlyOne() throws {
        let url = temporaryURL("capture-cardinality")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let first = store.addSection(title: "First")
        let active = store.addSection(title: "Active")
        store.setActiveSection(active.id)
        let before = store.notes.count

        let note = try #require(store.capture(CapturedSelection(
            markdown: "**Exactly one** captured note",
            sourceFrame: NSRect(x: 20, y: 30, width: 140, height: 22)
        )))

        #expect(store.notes.count - before == 1)
        #expect(note.sectionID == active.id)
        #expect(note.sectionID != first.id)
        #expect(store.notes.filter { $0.id == note.id }.count == 1)
    }

    @Test("Copy and Copy as List preserve display order and list completion")
    func copyOperationsPreserveOrderAndCompletion() throws {
        let url = temporaryURL("copy")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let first = try #require(store.addNote(markdown: "**First** and *italic*", sectionID: section.id))
        let second = try #require(store.addNote(markdown: "[Second](https://example.com)", sectionID: section.id))
        store.toggleSelection(second.id)
        store.toggleSelection(first.id)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CopperTests-\(UUID().uuidString)"))

        #expect(store.copySelected(asList: false, to: pasteboard) == "**First** and *italic*\n\n[Second](https://example.com)")
        #expect(pasteboard.string(forType: .string) == "**First** and *italic*\n\n[Second](https://example.com)")
        #expect(store.notes.allSatisfy { !$0.isCompleted })
        #expect(store.toast?.message == "Copied")

        #expect(store.copySelected(asList: true, using: { _ in false }) == nil)
        #expect(store.notes.allSatisfy { !$0.isCompleted })
        #expect(store.toast?.message == "Could not copy")

        #expect(store.copySelected(asList: true, to: pasteboard) == "1. First and italic\n2. Second")
        #expect(pasteboard.string(forType: .string) == "1. First and italic\n2. Second")
        #expect(store.notes.allSatisfy { $0.isCompleted })
        #expect(store.toast?.message == "Copied as List")
    }

    @Test("Merge preserves visual order and survives relaunch")
    func mergePreservesOrderAndPersists() throws {
        let url = temporaryURL("merge-persistence")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let first = try #require(store.addNote(markdown: "first", sectionID: section.id))
        let second = try #require(store.addNote(markdown: "second", sectionID: section.id))
        store.toggleSelection(second.id)
        store.toggleSelection(first.id)
        store.mergeSelected()

        #expect(store.notes.count == 1)
        #expect(store.notes.first?.id == first.id)
        #expect(store.notes.first?.markdown == "first\n\nsecond")

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.notes.count == 1)
        #expect(reloaded.notes.first?.markdown == "first\n\nsecond")
    }

    @Test("Expand state stays separate from editing")
    func expandIsSeparateFromEditing() throws {
        let url = temporaryURL("expand")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "expand me", sectionID: section.id))
        store.expandedID = note.id

        #expect(store.expandedID == note.id)
        #expect(store.editingID == nil)
    }

    @Test("Edit in New Window requests a distinct editor without entering inline edit")
    func editInNewWindowIsDistinct() throws {
        let url = temporaryURL("new-window")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "edit separately", sectionID: section.id))
        store.expandedID = note.id
        var requestedID: UUID?
        store.openEditor = { requestedID = $0 }

        #expect(store.handleCardReturn(noteID: note.id, openInNewWindow: true))
        #expect(requestedID == note.id)
        #expect(store.editingID == nil)
        #expect(store.expandedID == note.id)

        #expect(store.handleCardReturn(noteID: note.id, openInNewWindow: false))
        #expect(store.editingID == note.id)
        #expect(requestedID == note.id)
    }

    @Test("Default double Shift fires once for one completed gesture")
    func defaultDoubleShiftFiresOnce() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor { callbackCount += 1 }
        let firstDown = try #require(shiftEvent(isDown: true, timestamp: 1))
        let firstUp = try #require(shiftEvent(isDown: false, timestamp: 1.1))
        let secondDown = try #require(shiftEvent(isDown: true, timestamp: 1.2))

        monitor.processForTesting(firstDown)
        monitor.processForTesting(firstUp)
        monitor.processForTesting(secondDown)
        monitor.processForTesting(secondDown)

        #expect(callbackCount == 1)
        monitor.stop()
    }

    @Test("Double Shift ignores gestures combined with another modifier")
    func defaultDoubleShiftRejectsConflictingModifiers() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor { callbackCount += 1 }
        let commandShiftDown = try #require(shiftEvent(
            isDown: true,
            timestamp: 1,
            modifiers: [.command, .shift]
        ))
        let commandShiftUp = try #require(shiftEvent(
            isDown: false,
            timestamp: 1.1,
            modifiers: [.command]
        ))

        monitor.processForTesting(commandShiftDown)
        monitor.processForTesting(commandShiftUp)
        monitor.processForTesting(commandShiftDown)

        #expect(callbackCount == 0)
        monitor.stop()
    }

    @Test("Repeated capture events fire once and are never reposted")
    func repeatedCaptureEventIsDeduplicated() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor(shortcut: "⌘⇧A") { callbackCount += 1 }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        ))

        monitor.processForTesting(event)
        monitor.processForTesting(event)
        #expect(callbackCount == 1)
        monitor.stop()
    }

    @Test("Updating capture shortcut replaces the prior match")
    func captureShortcutUpdateReconfiguresMatching() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor(shortcut: "⌘⇧A") { callbackCount += 1 }
        let aEvent = try #require(keyEvent(key: "a", keyCode: 0, timestamp: 1))
        let bEvent = try #require(keyEvent(key: "b", keyCode: 11, timestamp: 2))

        monitor.processForTesting(aEvent)
        monitor.update(shortcut: "⌘⇧B")
        monitor.processForTesting(aEvent)
        Thread.sleep(forTimeInterval: 0.5)
        monitor.processForTesting(bEvent)

        #expect(callbackCount == 2)
        monitor.stop()
    }

    @Test("Unsafe shortcut updates cannot replace a safe monitor configuration")
    func unsafeShortcutUpdateIsRejected() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor(shortcut: "⌘⇧A") { callbackCount += 1 }
        let aEvent = try #require(keyEvent(key: "a", keyCode: 0, timestamp: 1))
        let plainBEvent = try #require(keyEvent(
            key: "b",
            keyCode: 11,
            timestamp: 2,
            modifiers: []
        ))

        monitor.update(shortcut: "B")
        monitor.processForTesting(plainBEvent)
        monitor.processForTesting(aEvent)

        #expect(callbackCount == 1)
        monitor.stop()
    }

    @Test("Moving selected notes preserves their display order")
    func moveSelectedPreservesOrder() throws {
        let url = temporaryURL("move-order")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let source = store.addSection(title: "Source")
        let destination = store.addSection(title: "Destination")
        let first = try #require(store.addNote(markdown: "first", sectionID: source.id))
        let second = try #require(store.addNote(markdown: "second", sectionID: source.id))
        let third = try #require(store.addNote(markdown: "third", sectionID: source.id))
        store.toggleSelection(third.id)
        store.toggleSelection(first.id)
        store.toggleSelection(second.id)

        store.moveSelected(to: destination.id)

        #expect(store.orderedNotes.filter { $0.sectionID == destination.id }.map(\.markdown) == ["first", "second", "third"])
    }

    private func keyEvent(
        key: String,
        keyCode: UInt16,
        timestamp: TimeInterval,
        modifiers: NSEvent.ModifierFlags = [.command, .shift]
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )
    }

    private func shiftEvent(
        isDown: Bool,
        timestamp: TimeInterval,
        modifiers: NSEvent.ModifierFlags? = nil
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: modifiers ?? (isDown ? [.shift] : []),
            timestamp: timestamp,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 56
        )
    }
}
