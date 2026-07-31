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

        let commandShiftC = try #require(CopperShortcut.parse("⌘⇧C"))
        #expect(commandShiftC.canonical == "⌘⇧C")
        #expect(commandShiftC.isSafeGlobalCapture)
        #expect(CopperShortcut.parse("A")?.isSafeGlobalCapture == false)

        var preferences = CopperPreferences()
        preferences.captureShortcut = preferences.copyShortcut
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "A"
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "not a shortcut with two keys"
        #expect(preferences.captureShortcutValidationMessage != nil)
        preferences.captureShortcut = "Shift + Shift"
        #expect(preferences.captureShortcutValidationMessage == nil)
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

    @Test("Repeated capture events fire once and are never reposted")
    func repeatedCaptureEventIsDeduplicated() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor(shortcut: "⌘A") { callbackCount += 1 }
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
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
        let monitor = GlobalCaptureMonitor(shortcut: "⌘A") { callbackCount += 1 }
        let aEvent = try #require(keyEvent(key: "a", keyCode: 0, timestamp: 1))
        let bEvent = try #require(keyEvent(key: "b", keyCode: 11, timestamp: 2))

        monitor.processForTesting(aEvent)
        monitor.update(shortcut: "⌘B")
        monitor.processForTesting(aEvent)
        Thread.sleep(forTimeInterval: 0.5)
        monitor.processForTesting(bEvent)

        #expect(callbackCount == 2)
        monitor.stop()
    }

    @Test("Unsafe shortcut updates cannot replace a safe monitor configuration")
    func unsafeShortcutUpdateIsRejected() throws {
        var callbackCount = 0
        let monitor = GlobalCaptureMonitor(shortcut: "⌘A") { callbackCount += 1 }
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
        modifiers: NSEvent.ModifierFlags = [.command]
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
}
