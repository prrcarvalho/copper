import AppKit
@testable import Copper
@testable import CopperCore
import Foundation
import SwiftUI
import Testing

@Suite("Copper domain and capture", .serialized)
@MainActor
struct CopperTests {
    private func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CopperTests-\(name)-\(UUID().uuidString).json")
    }

    @Test("Production drag strip stays outside the toolbar click band")
    func productionDragStripDoesNotCoverToolbar() {
        let content = CopperPanelContentView(hostingView: NSView())
        content.setFrameSize(CopperWindowGeometry.minimumSize)
        content.layout()

        let dragStrip = content.diagnosticDragStripFrame
        let toolbarProbe = NSPoint(
            x: content.bounds.midX,
            y: content.bounds.maxY - 62
        )
        let topDragProbe = NSPoint(
            x: content.bounds.midX,
            y: content.bounds.maxY - 4
        )

        #expect(dragStrip.maxY == content.bounds.maxY)
        #expect(dragStrip.height == 8)
        #expect(!(content.hitTest(toolbarProbe) is CopperDragStripView))
        #expect(content.hitTest(topDragProbe) is CopperDragStripView)
    }

    @Test("Production main-panel hosting view accepts its first mouse")
    func productionMainPanelHostingViewAcceptsFirstMouse() {
        let productionHost = CopperMainPanelHostingView(rootView: EmptyView())
        let unrelatedHost = NSHostingView(rootView: EmptyView())

        #expect(productionHost.acceptsFirstMouse(for: nil))
        #expect(!unrelatedHost.acceptsFirstMouse(for: nil))
    }

    @Test("Options hit target accepts and dispatches one first-mouse click")
    func optionsFirstMouseHitTargetDispatchesOneClick() throws {
        let target = CopperOptionsFirstMouseHitTargetView(
            frame: NSRect(x: 0, y: 0, width: 32, height: 32)
        )
        var activationCount = 0
        target.onActivate = { activationCount += 1 }

        #expect(target.acceptsFirstMouse(for: nil))

        let down = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 16, y: 16),
            modifierFlags: [],
            timestamp: 1,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        let up = try #require(NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 16, y: 16),
            modifierFlags: [],
            timestamp: 1.01,
            windowNumber: 0,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ))

        target.mouseDown(with: down)
        target.mouseUp(with: up)

        #expect(activationCount == 1)
    }

    @Test("Options activation is focus-independent and activation-only")
    func optionsActivationContract() {
        #expect(CopperOptionsInteractionContract.focusInteractions == .activate)
        #expect(CopperOptionsInteractionContract.isShowingOptions(afterActivationFrom: false))
        #expect(!CopperOptionsInteractionContract.isShowingOptions(afterActivationFrom: true))
    }

    @Test("Closing Options clears Search focus")
    func optionsDismissalClearsSearchFocus() {
        #expect(!CopperOptionsInteractionContract.searchFocused(afterOptionsDismissalFrom: true))
        #expect(!CopperOptionsInteractionContract.searchFocused(afterOptionsDismissalFrom: false))

        var resignCount = 0
        let nextFocus = CopperOptionsInteractionContract.clearSearchFocus(
            currentSearchFocused: true,
            resignFirstResponder: { resignCount += 1 }
        )
        #expect(!nextFocus)
        #expect(resignCount == 1)
    }

    @Test("Production panel is normal-level, activatable, and keyboard-focusable")
    func productionPanelFocusContract() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )
        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain)
        #expect(!panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .normal)
        #expect(!panel.isFloatingPanel)
        #expect(panel.collectionBehavior.isEmpty)
        #expect(!panel.isMovableByWindowBackground)
        #expect(CopperWindowLifecycleContract.productionActivationPolicy == .regular)
        #expect(CopperWindowLifecycleContract.backgroundUITestActivationPolicy == .accessory)
        #expect(CopperWindowLifecycleContract.productionWindowLevel == .normal)
        #expect(CopperWindowLifecycleContract.alwaysOnTopWindowLevel == .floating)
        #expect(CopperWindowLifecycleContract.windowLevel(alwaysOnTop: false) == .normal)
        #expect(CopperWindowLifecycleContract.windowLevel(alwaysOnTop: true) == .floating)
        #expect(CopperWindowLifecycleContract.backgroundUITestWindowLevel == .normal)
        #expect(CopperWindowLifecycleContract.productionCollectionBehavior.isEmpty)
        #expect(CopperWindowLifecycleContract.backgroundUITestCollectionBehavior.isEmpty)
    }

    @Test("Always-on-top changes only the panel level and can be reverted live")
    func productionPanelAlwaysOnTopLevelIsLiveAndReversible() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )

        #expect(panel.level == .normal)
        #expect(!panel.isFloatingPanel)
        #expect(panel.collectionBehavior.isEmpty)

        panel.applyAlwaysOnTop(true)
        #expect(panel.level == .floating)
        #expect(!panel.isFloatingPanel)
        #expect(panel.collectionBehavior.isEmpty)

        panel.applyAlwaysOnTop(false)
        #expect(panel.level == .normal)
        #expect(!panel.isFloatingPanel)
        #expect(panel.collectionBehavior.isEmpty)
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
        panel.isMovableByWindowBackground = false

        #expect(panel.styleMask.contains(.titled))
        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(!panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.resizable))
        #expect(panel.styleMask.contains(.closable))
        #expect(panel.styleMask.contains(.miniaturizable))
        #expect(panel.isResizable)
        #expect(panel.isMovable)
        #expect(!panel.isMovableByWindowBackground)
        #expect(constraintsApplied)
        #expect(panel.minSize == CopperWindowGeometry.minimumSize)
        #expect(panel.maxSize.width == 620)
        #expect(panel.maxSize.height == 876)
        #expect(panel.frame == NSRect(x: 0, y: 0, width: 620, height: 876))
    }

    @Test("Production Escape cancellation routes to Copper without minimizing")
    func productionEscapeCancellationRoutesToCopper() {
        let panel = CopperPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 760),
            styleMask: CopperPanel.companionStyleMask,
            backing: .buffered,
            defer: false
        )
        var cancellationCount = 0
        panel.cancelOperationHandler = { cancellationCount += 1 }
        panel.orderFront(nil)

        panel.cancelOperation(nil)

        #expect(cancellationCount == 1)
        #expect(!panel.isMiniaturized)
        panel.orderOut(nil)
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

    @Test("Capture toast is centred near the bottom of the active display")
    func captureToastUsesLowerCentrePlacement() {
        let visible = NSRect(x: 120, y: 80, width: 1440, height: 820)
        let toastSize = NSSize(width: 128, height: 38)

        let frame = CopperCaptureToastGeometry.frame(
            in: visible,
            size: toastSize
        )

        #expect(frame.midX == visible.midX)
        #expect(frame.minY == visible.minY + CopperCaptureToastGeometry.bottomInset)
        #expect(frame.maxY < visible.maxY)
    }

    @Test("Companion minimum is compact while preserving a scrollable queue and composer")
    func companionMinimumSizeIsCompact() {
        #expect(CopperWindowGeometry.minimumSize.width == 300)
        #expect(CopperWindowGeometry.minimumSize.height == 360)
        #expect(CopperWindowGeometry.minimumSize.width < 320)
        #expect(CopperWindowGeometry.minimumSize.height < 420)
        #expect(CopperComposerLayout.minimumHeight < CopperWindowGeometry.minimumSize.height)
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

    @Test("Empty production store stays empty after restart")
    func emptyProductionStoreStaysEmptyAfterRestart() {
        let url = temporaryURL("empty-production-store")
        defer { try? FileManager.default.removeItem(at: url) }

        let seededTestStore = CopperStore(fileURL: url, seedIfEmpty: true)
        #expect(!seededTestStore.notes.isEmpty)

        for section in seededTestStore.orderedSections {
            #expect(seededTestStore.deleteSection(section.id))
        }
        #expect(seededTestStore.sections.isEmpty)
        #expect(seededTestStore.notes.isEmpty)

        let reloadedProductionStore = CopperStore(fileURL: url)
        #expect(reloadedProductionStore.sections.isEmpty)
        #expect(reloadedProductionStore.notes.isEmpty)
    }

    @Test("Command deletion removes the active section and all of its prompts")
    func commandDeletionRemovesActiveSectionAndPrompts() throws {
        let url = temporaryURL("delete-section")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let first = store.addSection(title: "First")
        let active = store.addSection(title: "Active")
        let third = store.addSection(title: "Third")
        let deletedPrompt = try #require(store.addNote(markdown: "delete me", sectionID: active.id))
        let retainedPrompt = try #require(store.addNote(markdown: "keep me", sectionID: third.id))
        store.setActiveSection(active.id)
        store.setFocusedCard(deletedPrompt.id)
        store.expandedID = deletedPrompt.id

        #expect(store.deleteCommandSelection())
        #expect(store.sections.map(\.id) == [first.id, third.id])
        #expect(store.notes.map(\.id) == [retainedPrompt.id])
        #expect(store.activeSectionID == third.id)
        #expect(store.selectedIDs.isEmpty)
        #expect(store.focusedCardID == nil)
        #expect(store.expandedID == nil)

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.sections.map(\.id) == [first.id, third.id])
        #expect(reloaded.notes.map(\.markdown) == ["keep me"])
        #expect(reloaded.activeSectionID == third.id)

        #expect(store.undo())
        #expect(store.sections.map(\.id) == [first.id, active.id, third.id])
        #expect(store.notes.map(\.markdown) == ["delete me", "keep me"])
        #expect(store.activeSectionID == active.id)
        #expect(store.selectedIDs.isEmpty)

        #expect(store.redo())
        #expect(store.sections.map(\.id) == [first.id, third.id])
        #expect(store.notes.map(\.markdown) == ["keep me"])
        #expect(store.activeSectionID == third.id)
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

    @Test("Submitting a manual prompt saves it and restores composer focus")
    func promptSubmissionRestoresComposerFocus() throws {
        let url = temporaryURL("composer-submit-focus")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let result = CopperComposerInteractionContract.submit(
            draft: "continue testing",
            save: { markdown in store.addNote(markdown: markdown, sectionID: section.id) },
            createSection: { title in store.addSection(title: title) }
        )

        #expect(store.notes.map(\.markdown) == ["continue testing"])
        #expect(result.draft.isEmpty)
        #expect(result.composerIsFocused)
    }

    @Test("Composer section command creates a section instead of a note")
    func composerSectionCommandCreatesSection() throws {
        let url = temporaryURL("composer-section-command")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let result = CopperComposerInteractionContract.submit(
            draft: "# Research ideas",
            save: { markdown in store.addNote(markdown: markdown) },
            createSection: { title in store.addSection(title: title) }
        )

        #expect(store.sections.map(\.title) == ["RESEARCH IDEAS"])
        #expect(store.notes.isEmpty)
        #expect(store.activeSectionID == store.sections.first?.id)
        #expect(result.draft.isEmpty)
        #expect(result.composerIsFocused)
    }

    @Test("Composer only recognises a non-empty single-line hash heading")
    func composerSectionCommandParsing() {
        #expect(CopperComposerInteractionContract.sectionTitle(from: "# Research") == "Research")
        #expect(CopperComposerInteractionContract.sectionTitle(from: "  # Research  ") == "Research")
        #expect(CopperComposerInteractionContract.sectionTitle(from: "# ") == nil)
        #expect(CopperComposerInteractionContract.sectionTitle(from: "## Research") == nil)
        #expect(CopperComposerInteractionContract.sectionTitle(from: "# Research\nMore") == nil)
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

    @Test("Escape closes prompt detail and clears selection and card focus atomically")
    func escapeClearsSelectionAndCardFocus() throws {
        let url = temporaryURL("escape-selection")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "focus me", sectionID: section.id))
        store.ensureSelected(note.id)
        store.setFocusedCard(note.id)
        store.expandedID = note.id

        #expect(store.handleEscape())
        #expect(store.selectedIDs.isEmpty)
        #expect(store.focusedCardID == nil)
        #expect(store.expandedID == nil)
        #expect(!store.handleEscape())
    }

    @Test("Command deletion is a reversible multi-note transaction")
    func commandDeletionUndoRedoRestoresDeterministicNotesAndSelection() throws {
        let url = temporaryURL("delete-undo-redo")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let first = try #require(store.addNote(markdown: "first", sectionID: section.id))
        let second = try #require(store.addNote(markdown: "second", sectionID: section.id))
        let originalIDs = store.orderedNotes.map(\.id)
        let selected = Set([first.id, second.id])
        store.ensureSelected(first.id)
        store.toggleSelection(second.id)
        store.setFocusedCard(second.id)
        store.expandedID = first.id

        store.deleteSelected()

        #expect(store.notes.isEmpty)
        #expect(store.selectedIDs.isEmpty)
        #expect(store.focusedCardID == nil)
        #expect(store.expandedID == nil)
        #expect(store.canUndo)
        #expect(store.undo())
        #expect(store.orderedNotes.map(\.id) == originalIDs)
        #expect(store.selectedIDs == selected)
        #expect(store.notes.map(\.markdown) == ["first", "second"])
        #expect(store.focusedCardID == nil)

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.orderedNotes.map(\.id) == originalIDs)
        #expect(reloaded.orderedNotes.map(\.markdown) == ["first", "second"])

        #expect(store.canRedo)
        #expect(store.redo())
        #expect(store.notes.isEmpty)
        #expect(store.selectedIDs.isEmpty)
        #expect(!store.canRedo)
    }

    @Test("A divergent persistent action invalidates redo")
    func divergentActionInvalidatesRedo() throws {
        let url = temporaryURL("redo-invalidation")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "remove me", sectionID: section.id))
        store.ensureSelected(note.id)

        store.deleteSelected()
        #expect(store.undo())
        _ = store.addNote(markdown: "new branch", sectionID: section.id)

        #expect(!store.canRedo)
        #expect(!store.redo())
        #expect(store.orderedNotes.map(\.markdown) == ["remove me", "new branch"])
    }

    @Test("Text first responder keeps delete, undo, and redo on the native text route")
    func textFirstResponderRouting() {
        #expect(
            CopperCommandRouting.destination(for: .plainDelete, firstResponder: .textEditor)
                == .textEditor
        )
        #expect(
            CopperCommandRouting.destination(for: .commandDelete, firstResponder: .textEditor)
                == .textEditor
        )
        #expect(
            CopperCommandRouting.destination(for: .undo, firstResponder: .textEditor)
                == .textEditor
        )
        #expect(
            CopperCommandRouting.destination(for: .redo, firstResponder: .textEditor)
                == .textEditor
        )
        #expect(
            CopperCommandRouting.destination(
                for: .undo,
                firstResponder: .textEditor,
                copperUndoPreferred: true
            ) == .copper
        )
        #expect(
            CopperCommandRouting.destination(
                for: .redo,
                firstResponder: .textEditor,
                copperUndoPreferred: true
            ) == .copper
        )
        #expect(
            CopperCommandRouting.destination(for: .escape, firstResponder: .textEditor)
                == .textEditorAndCopper
        )
        #expect(
            CopperCommandRouting.destination(for: .plainDelete, firstResponder: .other)
                == .ignored
        )
        #expect(
            CopperCommandRouting.destination(for: .commandDelete, firstResponder: .other)
                == .copper
        )
        #expect(
            CopperCommandRouting.destination(for: .undo, firstResponder: .other)
                == .copper
        )
        #expect(
            CopperCommandRouting.destination(for: .redo, firstResponder: .other)
                == .copper
        )
        #expect(
            CopperCommandRouting.destination(for: .escape, firstResponder: .other)
                == .copper
        )
    }

    @Test("A just-completed Copper action wins undo routing while the composer remains focused")
    func copperActionWinsUndoRoutingFromTextEditor() throws {
        let url = temporaryURL("composer-undo-routing")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "created from composer", sectionID: section.id))

        let destination = CopperCommandRouting.destination(
            for: .undo,
            firstResponder: .textEditor,
            copperUndoPreferred: store.copperUndoPreferred && store.canUndo
        )
        #expect(destination == .copper)

        if destination == .copper {
            #expect(store.undo())
        }
        #expect(store.notes.isEmpty)
        #expect(store.canRedo)
        #expect(store.copperUndoPreferred)
        #expect(note.sectionID == section.id)
    }

    @Test("Text-editor Command-Delete routing cannot delete Copper tasks")
    func textCommandDeleteDoesNotDeleteTasks() throws {
        let url = temporaryURL("text-command-delete")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "keep me", sectionID: section.id))
        store.ensureSelected(note.id)

        let destination = CopperCommandRouting.destination(
            for: .commandDelete,
            firstResponder: .textEditor
        )
        if destination == .copper {
            store.deleteSelected()
        }

        #expect(destination == .textEditor)
        #expect(store.notes.map(\.id) == [note.id])
    }

    @Test("Escape clears Copper card state even while text editing remains the responder")
    func textEditorEscapeClearsCopperState() throws {
        let url = temporaryURL("text-escape")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "selected", sectionID: section.id))
        store.ensureSelected(note.id)
        store.setFocusedCard(note.id)

        let destination = CopperCommandRouting.destination(
            for: .escape,
            firstResponder: .textEditor
        )
        if destination == .textEditorAndCopper {
            _ = store.handleEscape()
        }

        #expect(destination == .textEditorAndCopper)
        #expect(store.selectedIDs.isEmpty)
        #expect(store.focusedCardID == nil)
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

    @Test("Always-on-top preference defaults off and persists")
    func alwaysOnTopPreferencePersists() {
        let url = temporaryURL("always-on-top-preferences")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(!store.preferences.alwaysOnTop)

        store.preferences.alwaysOnTop = true
        store.save()

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        #expect(reloaded.preferences.alwaysOnTop)
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

    @Test("Production capture pins selection lookup to the frontmost source app")
    func productionCapturePinsFrontmostSourceSelection() {
        let sourceSelection = CapturedSelection(
            markdown: "source application selection",
            sourceFrame: nil
        )
        let systemSelection = CapturedSelection(
            markdown: "system-wide selection",
            sourceFrame: nil
        )
        var requestedApplicationID: String?

        let selected = CopperCaptureSelectionRouting.resolve(
            preferredApplicationIdentifier: "com.apple.TextEdit",
            applicationSelection: { applicationIdentifier in
                requestedApplicationID = applicationIdentifier
                return sourceSelection
            },
            systemSelection: { systemSelection }
        )

        #expect(requestedApplicationID == "com.apple.TextEdit")
        #expect(selected?.markdown == sourceSelection.markdown)
    }

    @Test("Global capture snapshots the source app before the main-actor hop")
    func globalCaptureSnapshotsSourceApplication() throws {
        var capturedApplicationIdentifier: String?
        let monitor = GlobalCaptureMonitor(
            sourceApplicationIdentifierProvider: { "com.example.source" },
            onCaptureWithSource: { capturedApplicationIdentifier = $0 }
        )
        let firstDown = try #require(shiftEvent(isDown: true, timestamp: 1))
        let firstUp = try #require(shiftEvent(isDown: false, timestamp: 1.1))
        let secondDown = try #require(shiftEvent(isDown: true, timestamp: 1.2))

        monitor.processForTesting(firstDown)
        monitor.processForTesting(firstUp)
        monitor.processForTesting(secondDown)

        #expect(capturedApplicationIdentifier == "com.example.source")
        monitor.stop()
    }

    @Test("Clipboard fallback only accepts text written by the copy request")
    func clipboardFallbackRequiresPasteboardChange() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CopperTests-ClipboardFallback-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("before", forType: .string)
        let changeCountBefore = pasteboard.changeCount

        #expect(CopperClipboardSelectionFallback.changedText(
            from: pasteboard,
            changeCountBefore: changeCountBefore
        ) == nil)

        pasteboard.clearContents()
        pasteboard.setString("selected from an editor", forType: .string)
        #expect(CopperClipboardSelectionFallback.changedText(
            from: pasteboard,
            changeCountBefore: changeCountBefore
        ) == "selected from an editor")
    }

    @Test("AX child arrays bridge without unsafe pointer casts")
    func accessibilityChildrenBridgeSafely() {
        let children = [
            AXUIElementCreateSystemWide(),
            AXUIElementCreateSystemWide(),
        ] as NSArray

        let bridged = AccessibilityReader.axElements(from: children as CFTypeRef)

        #expect(bridged.count == 2)
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

    @Test("Open note detail selects a valid note and rejects unknown IDs")
    func openNoteDetailValidatesNoteID() throws {
        let url = temporaryURL("expand")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let section = store.addSection(title: "Queue")
        let note = try #require(store.addNote(markdown: "expand me", sectionID: section.id))

        #expect(store.openNoteDetail(note.id))
        #expect(store.expandedID == note.id)
        #expect(store.selectedIDs == Set([note.id]))
        #expect(!store.openNoteDetail(UUID()))
        #expect(store.expandedID == note.id)

        store.updateNote(id: note.id, markdown: "saved from popup")
        #expect(store.notes.first?.markdown == "saved from popup")
        #expect(store.canUndo)
        #expect(store.undo())
        #expect(store.notes.first?.markdown == "expand me")
        #expect(store.redo())
        #expect(store.notes.first?.markdown == "saved from popup")
    }

    @Test("Return opens prompt detail while Command-Return requests the separate editor")
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
        #expect(store.expandedID == note.id)

        #expect(store.handleCardReturn(noteID: note.id, openInNewWindow: false))
        #expect(store.expandedID == note.id)
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
