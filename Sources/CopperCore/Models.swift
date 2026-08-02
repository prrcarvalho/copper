import AppKit
import ApplicationServices
import Combine
import Foundation

/// Shared geometry for the production companion panel.
///
/// The public Copper evidence only establishes a compact floating companion
/// window; these values are deliberately kept as explicit reconstruction
/// parameters rather than presented as hidden implementation facts.
public enum CopperWindowGeometry {
    public static let autosaveName = "CopperCompanionPanel"
    public static let minimumSize = NSSize(width: 320, height: 420)
    public static let initialSize = NSSize(width: 430, height: 760)
    public static let maximumWidth: CGFloat = 620

    public static func maximumSize(for visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: max(minimumSize.width, min(maximumWidth, visibleFrame.width - 16)),
            height: max(minimumSize.height, visibleFrame.height - 24)
        )
    }

    public static func centeredFrame(size: NSSize = initialSize, in visibleFrame: NSRect) -> NSRect {
        let maximum = maximumSize(for: visibleFrame)
        let width = min(max(size.width, minimumSize.width), maximum.width)
        let height = min(max(size.height, minimumSize.height), maximum.height)
        return NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    public static func clampedFrame(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        let maximum = maximumSize(for: visibleFrame)
        let width = min(max(frame.width, minimumSize.width), maximum.width)
        let height = min(max(frame.height, minimumSize.height), maximum.height)
        let x = min(
            max(frame.minX, visibleFrame.minX),
            visibleFrame.maxX - width
        )
        let y = min(
            max(frame.minY, visibleFrame.minY),
            visibleFrame.maxY - height
        )
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

/// A titled companion panel uses the normal AppKit window level so it behaves
/// like an ordinary macOS window when the user clicks it, selects Copper from
/// the Dock, or switches to it with Command-Tab. The production shell hides
/// the standard buttons, while the native style remains available for edge
/// resizing and the standard Command-W/Command-M actions.
@MainActor
public final class CopperPanel: NSPanel {
    public static let companionStyleMask: NSWindow.StyleMask = [
        .titled,
        .fullSizeContentView,
        .resizable,
        .closable,
        .miniaturizable,
    ]

    public override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        level = .normal
        isFloatingPanel = false
        collectionBehavior = []
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    /// Applies the shared companion geometry contract after AppKit/SwiftUI
    /// layout passes. Returning whether the frame changed keeps the shell's
    /// delegate callbacks small and makes clamping behaviour testable.
    @discardableResult
    public func applyCompanionConstraints(to visibleFrame: NSRect) -> Bool {
        let maximum = CopperWindowGeometry.maximumSize(for: visibleFrame)
        contentMinSize = CopperWindowGeometry.minimumSize
        contentMaxSize = maximum
        minSize = CopperWindowGeometry.minimumSize
        maxSize = maximum
        let clamped = CopperWindowGeometry.clampedFrame(frame, to: visibleFrame)
        guard clamped != frame else { return false }
        setFrame(clamped, display: true)
        return true
    }

    /// Copper's close command hides the companion but deliberately keeps the
    /// global capture monitor alive. Dock/Command-Tab/Command-0 can present it
    /// again without creating a second panel.
    public override func performClose(_ sender: Any?) {
        orderOut(sender)
    }
}

public struct CopperSection: Codable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, sortIndex: Int = 0) {
        self.id = id
        self.title = title
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public struct CopperNote: Codable, Hashable, Identifiable {
    public let id: UUID
    public var sectionID: UUID
    public var markdown: String
    public var isCompleted: Bool
    public var sortIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), sectionID: UUID, markdown: String, isCompleted: Bool = false, sortIndex: Int = 0) {
        self.id = id
        self.sectionID = sectionID
        self.markdown = markdown
        self.isCompleted = isCompleted
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public struct CopperPreferences: Codable, Equatable {
    public var captureShortcut = "Shift + Shift"
    public var copyShortcut = "⌘C"
    public var copyAsListShortcut = "⇧⌘C"
    public var markDoneShortcut = "Space"

    private enum CodingKeys: String, CodingKey {
        case captureShortcut, copyShortcut, copyAsListShortcut, markDoneShortcut
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        captureShortcut = try values.decodeIfPresent(String.self, forKey: .captureShortcut) ?? "Shift + Shift"
        copyShortcut = try values.decodeIfPresent(String.self, forKey: .copyShortcut) ?? "⌘C"
        copyAsListShortcut = try values.decodeIfPresent(String.self, forKey: .copyAsListShortcut) ?? "⇧⌘C"
        markDoneShortcut = try values.decodeIfPresent(String.self, forKey: .markDoneShortcut) ?? "Space"
    }

    public var captureShortcutValidationMessage: String? {
        guard let capture = CopperShortcut.parse(captureShortcut) else {
            return "Use Double Shift or a key combination such as ⌘⇧C."
        }
        if capture.usesVoiceOverModifier {
            return "Control + Option is reserved for VoiceOver and may alter source-app input."
        }
        guard capture.isSafeGlobalCapture else {
            return "Use Command with at least one additional modifier for global capture."
        }
        let otherShortcuts = [copyShortcut, copyAsListShortcut, markDoneShortcut].compactMap(CopperShortcut.parse)
        if otherShortcuts.contains(where: { $0 == capture }) {
            return "This shortcut conflicts with another Copper shortcut."
        }
        return nil
    }
}

public struct CopperDocument: Codable {
    public var sections: [CopperSection]
    public var notes: [CopperNote]
    public var preferences: CopperPreferences
    public var activeSectionID: UUID?

    private enum CodingKeys: String, CodingKey {
        case sections, notes, preferences, activeSectionID
    }

    public init(sections: [CopperSection], notes: [CopperNote], preferences: CopperPreferences, activeSectionID: UUID? = nil) {
        self.sections = sections
        self.notes = notes
        self.preferences = preferences
        self.activeSectionID = activeSectionID
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sections = try values.decode([CopperSection].self, forKey: .sections)
        notes = try values.decode([CopperNote].self, forKey: .notes)
        preferences = try values.decodeIfPresent(CopperPreferences.self, forKey: .preferences) ?? CopperPreferences()
        activeSectionID = try values.decodeIfPresent(UUID.self, forKey: .activeSectionID)
    }
}

public struct CopperShortcut: Equatable, Hashable {
    public enum Modifier: String, CaseIterable, Hashable {
        case command, shift, option, control
    }

    public enum Trigger: Equatable, Hashable {
        case doubleShift
        case key(String, modifiers: Set<Modifier>)
    }

    public let trigger: Trigger

    public static func parse(_ raw: String) -> CopperShortcut? {
        var normalized = raw.uppercased()
            .replacingOccurrences(of: "⌘", with: " COMMAND ")
            .replacingOccurrences(of: "⇧", with: " SHIFT ")
            .replacingOccurrences(of: "⌥", with: " OPTION ")
            .replacingOccurrences(of: "⌃", with: " CONTROL ")
            .replacingOccurrences(of: "+", with: " ")
        normalized = normalized.replacingOccurrences(of: "DOUBLESHIFT", with: "SHIFT SHIFT")
        let tokens = normalized.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard !tokens.isEmpty else { return nil }
        if (tokens.count == 2 && tokens.allSatisfy({ $0 == "SHIFT" }))
            || tokens == ["DOUBLE", "SHIFT"] {
            return CopperShortcut(trigger: .doubleShift)
        }

        var modifiers = Set<Modifier>()
        var key: String?
        for token in tokens {
            switch token {
            case "COMMAND", "CMD", "⌘": modifiers.insert(.command)
            case "SHIFT", "⇧": modifiers.insert(.shift)
            case "OPTION", "ALT", "⌥": modifiers.insert(.option)
            case "CONTROL", "CTRL", "⌃": modifiers.insert(.control)
            default:
                guard key == nil else { return nil }
                key = token == "RETURN" ? "ENTER" : token
            }
        }
        guard let key, !key.isEmpty else { return nil }
        return CopperShortcut(trigger: .key(key, modifiers: modifiers))
    }

    public var canonical: String {
        switch trigger {
        case .doubleShift:
            return "DOUBLESHIFT"
        case let .key(key, modifiers):
            let prefix = [Modifier.command, .shift, .option, .control]
                .filter { modifiers.contains($0) }
                .map { modifier in
                    switch modifier {
                    case .command: return "⌘"
                    case .shift: return "⇧"
                    case .option: return "⌥"
                    case .control: return "⌃"
                    }
                }
                .joined()
            return prefix + key
        }
    }

    /// A global monitor observes rather than consumes the source event. Require
    /// Command plus another modifier so the shortcut cannot insert an ordinary
    /// or Option-modified character into the source app. Control + Option is
    /// separately excluded because it is macOS's VoiceOver modifier.
    public var isSafeGlobalCapture: Bool {
        switch trigger {
        case .doubleShift:
            return true
        case let .key(_, modifiers):
            return modifiers.contains(.command)
                && modifiers.count >= 2
                && !usesVoiceOverModifier
        }
    }

    public var usesVoiceOverModifier: Bool {
        guard case let .key(_, modifiers) = trigger else { return false }
        return modifiers.contains(.control) && modifiers.contains(.option)
    }

    public func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, !event.isARepeat else { return false }
        guard case let .key(expectedKey, expectedModifiers) = trigger else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let actualModifiers: Set<Modifier> = Set([
            flags.contains(.command) ? .command : nil,
            flags.contains(.shift) ? .shift : nil,
            flags.contains(.option) ? .option : nil,
            flags.contains(.control) ? .control : nil
        ].compactMap { $0 })
        guard actualModifiers == expectedModifiers else { return false }
        if expectedKey == "SPACE" { return event.keyCode == 49 }
        if expectedKey == "ENTER" { return event.keyCode == 36 || event.keyCode == 76 }
        return event.charactersIgnoringModifiers?.uppercased() == expectedKey
    }
}

public enum CopperToastKind {
    case capture
    case copy
    case neutral
    case error
}

/// Explicit command intents used by Copper's menu/key routing. Plain Delete
/// is intentionally represented separately so it can never fall through to
/// task deletion when no text editor is active.
public enum CopperKeyCommand: Equatable {
    case plainDelete
    case commandDelete
    case undo
    case redo
    case escape
}

public enum CopperFirstResponderKind: Equatable {
    case textEditor
    case other
}

public enum CopperCommandDestination: Equatable {
    case copper
    case textEditor
    case textEditorAndCopper
    case ignored
}

public enum CopperCommandRouting {
    public static func destination(
        for command: CopperKeyCommand,
        firstResponder: CopperFirstResponderKind
    ) -> CopperCommandDestination {
        if firstResponder == .textEditor {
            switch command {
            case .plainDelete, .commandDelete, .undo, .redo:
                return .textEditor
            case .escape:
                return .textEditorAndCopper
            }
        }

        switch command {
        case .plainDelete:
            return .ignored
        case .commandDelete, .undo, .redo, .escape:
            return .copper
        }
    }
}

/// Window values shared by production and the non-focus-stealing UI-test
/// launch. Keeping these values in CopperCore gives the lifecycle contract a
/// deterministic seam without requiring a foreground AppKit test.
public enum CopperWindowLifecycleContract {
    public static let productionActivationPolicy: NSApplication.ActivationPolicy = .regular
    public static let backgroundUITestActivationPolicy: NSApplication.ActivationPolicy = .accessory
    public static let productionWindowLevel: NSWindow.Level = .normal
    public static let backgroundUITestWindowLevel: NSWindow.Level = .normal
    public static let productionCollectionBehavior: NSWindow.CollectionBehavior = []
    public static let backgroundUITestCollectionBehavior: NSWindow.CollectionBehavior = []
}

public struct CopperToast: Identifiable {
    public let id = UUID()
    public let message: String
    public let kind: CopperToastKind
    public init(message: String, kind: CopperToastKind) {
        self.message = message
        self.kind = kind
    }
}

@MainActor
public final class CopperStore: ObservableObject {
    @Published public private(set) var sections: [CopperSection] = []
    @Published public private(set) var notes: [CopperNote] = []
    @Published public var preferences = CopperPreferences()
    @Published public var searchText = ""
    @Published public private(set) var selectedIDs: Set<UUID> = []
    @Published public private(set) var focusedCardID: UUID? = nil
    @Published public private(set) var activeSectionID: UUID? = nil
    @Published public var expandedID: UUID? = nil
    @Published public var toast: CopperToast?

    public let fileURL: URL
    public var openEditor: ((UUID) -> Void)?

    private struct PersistentState: Equatable {
        var sections: [CopperSection]
        var notes: [CopperNote]
        var preferences: CopperPreferences
        var activeSectionID: UUID?
    }

    private struct HistoryEntry {
        let before: PersistentState
        let after: PersistentState
        let beforeSelection: Set<UUID>
        let afterSelection: Set<UUID>
    }

    private var undoStack: [HistoryEntry] = []
    private var redoStack: [HistoryEntry] = []

    public init(fileURL: URL? = nil, seedIfEmpty: Bool = true) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = appSupport.appendingPathComponent("Copper-Reconstruction", isDirectory: true)
                .appendingPathComponent("notes.json")
        }

        load()
        if sections.isEmpty && seedIfEmpty {
            seedDemoContent()
            save()
        }
        if activeSectionID == nil || !sections.contains(where: { $0.id == activeSectionID }) {
            activeSectionID = orderedSections.first?.id
        }
    }

    public var orderedSections: [CopperSection] {
        sections.sorted { $0.sortIndex < $1.sortIndex }
    }

    public var orderedNotes: [CopperNote] {
        notes.sorted(by: { noteA, noteB in
            if noteA.sectionID == noteB.sectionID { return noteA.sortIndex < noteB.sortIndex }
            let lhs = sections.first(where: { section in section.id == noteA.sectionID })?.sortIndex ?? 0
            let rhs = sections.first(where: { section in section.id == noteB.sectionID })?.sortIndex ?? 0
            return lhs == rhs ? noteA.createdAt < noteB.createdAt : lhs < rhs
        })
    }

    public func visibleNotes(for section: CopperSection) -> [CopperNote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return orderedNotes.filter { note in
            guard note.sectionID == section.id else { return false }
            guard !query.isEmpty else { return true }
            return note.markdown.lowercased().contains(query) || section.title.lowercased().contains(query)
        }
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    private var persistentState: PersistentState {
        PersistentState(
            sections: sections,
            notes: notes,
            preferences: preferences,
            activeSectionID: activeSectionID
        )
    }

    private var validNoteIDs: Set<UUID> {
        Set(notes.map(\.id))
    }

    private func performPersistentMutation(_ mutation: () -> Void) {
        let before = persistentState
        let beforeSelection = selectedIDs
        mutation()
        let after = persistentState
        guard before != after else { return }

        undoStack.append(HistoryEntry(
            before: before,
            after: after,
            beforeSelection: beforeSelection,
            afterSelection: selectedIDs.intersection(validNoteIDs)
        ))
        redoStack.removeAll()
        save()
    }

    private func restore(_ state: PersistentState, selection: Set<UUID>) {
        sections = state.sections
        notes = state.notes
        preferences = state.preferences
        activeSectionID = state.activeSectionID
        selectedIDs = selection.intersection(validNoteIDs)
        if let expandedID, !validNoteIDs.contains(expandedID) {
            self.expandedID = nil
        }
        // Focus is a live AppKit/SwiftUI concern, not part of an undo entry.
        // Clearing it also prevents an old focus ring from surviving a restore.
        focusedCardID = nil
        save()
    }

    @discardableResult
    public func undo() -> Bool {
        guard let entry = undoStack.popLast() else { return false }
        redoStack.append(entry)
        restore(entry.before, selection: entry.beforeSelection)
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let entry = redoStack.popLast() else { return false }
        undoStack.append(entry)
        restore(entry.after, selection: entry.afterSelection)
        return true
    }

    @discardableResult
    public func addNote(markdown: String, sectionID: UUID? = nil) -> CopperNote? {
        let cleaned = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if let sectionID, !sections.contains(where: { $0.id == sectionID }) {
            return nil
        }

        var note: CopperNote?
        performPersistentMutation {
            var destination = sectionID ?? activeSectionID ?? orderedSections.first?.id
            if destination == nil {
                let inbox = CopperSection(title: "INBOX", sortIndex: sections.count)
                sections.append(inbox)
                destination = inbox.id
            }
            guard let destination, sections.contains(where: { $0.id == destination }) else { return }
            activeSectionID = destination
            let index = notes.filter { $0.sectionID == destination }.map(\.sortIndex).max().map { $0 + 1 } ?? 0
            let created = CopperNote(sectionID: destination, markdown: cleaned, sortIndex: index)
            notes.append(created)
            note = created
        }
        return note
    }

    @discardableResult
    public func addSection(title: String) -> CopperSection {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var section: CopperSection?
        performPersistentMutation {
            let created = CopperSection(
                title: cleaned.isEmpty ? "UNTITLED" : cleaned.uppercased(),
                sortIndex: sections.count
            )
            sections.append(created)
            activeSectionID = created.id
            section = created
        }
        guard let section else {
            // The mutation closure always creates a section; keep the fallback
            // explicit so the return contract remains total if it changes.
            return CopperSection(title: "UNTITLED", sortIndex: sections.count)
        }
        return section
    }

    public func setActiveSection(_ sectionID: UUID) {
        guard sections.contains(where: { $0.id == sectionID }) else { return }
        performPersistentMutation {
            activeSectionID = sectionID
        }
    }

    @discardableResult
    public func deleteSection(_ sectionID: UUID) -> Bool {
        guard sections.contains(where: { $0.id == sectionID }) else { return false }

        let orderedSectionsBeforeDeletion = orderedSections
        guard let sectionIndex = orderedSectionsBeforeDeletion.firstIndex(where: { $0.id == sectionID }) else {
            return false
        }
        let fallbackSectionID: UUID?
        if sectionIndex + 1 < orderedSectionsBeforeDeletion.count {
            fallbackSectionID = orderedSectionsBeforeDeletion[sectionIndex + 1].id
        } else if sectionIndex > 0 {
            fallbackSectionID = orderedSectionsBeforeDeletion[sectionIndex - 1].id
        } else {
            fallbackSectionID = nil
        }
        let deletedNoteIDs = Set(notes.filter { $0.sectionID == sectionID }.map(\.id))

        performPersistentMutation {
            sections.removeAll { $0.id == sectionID }
            notes.removeAll { $0.sectionID == sectionID }
            selectedIDs.subtract(deletedNoteIDs)

            if let expandedID, deletedNoteIDs.contains(expandedID) {
                self.expandedID = nil
            }
            if let focusedCardID, deletedNoteIDs.contains(focusedCardID) {
                self.focusedCardID = nil
            }
            if activeSectionID == sectionID {
                activeSectionID = fallbackSectionID
            }
        }
        return true
    }

    public func updateNote(id: UUID, markdown: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        performPersistentMutation {
            notes[index].markdown = cleaned
            notes[index].updatedAt = Date()
        }
    }

    public func toggleCompleted(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        performPersistentMutation {
            notes[index].isCompleted.toggle()
            notes[index].updatedAt = Date()
        }
    }

    public func toggleSelection(_ id: UUID) {
        guard validNoteIDs.contains(id) else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    /// Testable domain endpoint used by a focused card's Space key handler.
    /// The SwiftUI view remains responsible only for routing the key event.
    @discardableResult
    public func handleCardSpace(noteID: UUID) -> Bool {
        guard notes.contains(where: { $0.id == noteID }) else { return false }
        ensureSelected(noteID)
        toggleSelectedCompletion()
        return true
    }

    @discardableResult
    public func handleCardReturn(noteID: UUID, openInNewWindow: Bool) -> Bool {
        guard notes.contains(where: { $0.id == noteID }) else { return false }
        ensureSelected(noteID)
        if openInNewWindow {
            return requestEditInNewWindow(noteID)
        }
        return openNoteDetail(noteID)
    }

    /// Opens a note in the in-app full-content editor.
    @discardableResult
    public func openNoteDetail(_ noteID: UUID) -> Bool {
        guard notes.contains(where: { $0.id == noteID }) else { return false }
        ensureSelected(noteID)
        expandedID = noteID
        return true
    }

    public func ensureSelected(_ id: UUID) {
        guard validNoteIDs.contains(id) else { return }
        if !selectedIDs.contains(id) { selectedIDs = [id] }
    }

    public func clearSelection() {
        selectedIDs.removeAll()
    }

    public func setFocusedCard(_ id: UUID?) {
        if let id, !validNoteIDs.contains(id) { return }
        focusedCardID = id
    }

    /// Clears the store-backed card state used for selection visuals. The
    /// caller still owns the actual AppKit/SwiftUI first responder, so this
    /// does not cancel or rewrite a text editor's undo/focus state.
    @discardableResult
    public func handleEscape() -> Bool {
        let changed = expandedID != nil || !selectedIDs.isEmpty || focusedCardID != nil
        expandedID = nil
        selectedIDs.removeAll()
        focusedCardID = nil
        return changed
    }

    public func deleteSelected() {
        let selectedIDs = selectedIDs.intersection(validNoteIDs)
        guard !selectedIDs.isEmpty else { return }

        performPersistentMutation {
            notes.removeAll { selectedIDs.contains($0.id) }
            self.selectedIDs.removeAll()
            if let expandedID, selectedIDs.contains(expandedID) {
                self.expandedID = nil
            }
            if let focusedCardID, selectedIDs.contains(focusedCardID) {
                self.focusedCardID = nil
            }
        }
    }

    @discardableResult
    public func deleteCommandSelection() -> Bool {
        if !selectedIDs.intersection(validNoteIDs).isEmpty {
            deleteSelected()
            return true
        }
        guard let activeSectionID else { return false }
        return deleteSection(activeSectionID)
    }

    public func markSelectedDone() {
        let selected = selectedIDs.intersection(validNoteIDs)
        guard !selected.isEmpty else { return }
        performPersistentMutation {
            for id in selected {
                guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
                notes[index].isCompleted = true
                notes[index].updatedAt = Date()
            }
        }
    }

    public func toggleSelectedCompletion() {
        let selected = selectedIDs.intersection(validNoteIDs)
        guard !selected.isEmpty else { return }
        performPersistentMutation {
            for id in selected {
                guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
                notes[index].isCompleted.toggle()
                notes[index].updatedAt = Date()
            }
        }
    }

    @discardableResult
    public func copySelected(asList: Bool, to pasteboard: NSPasteboard = .general) -> String? {
        copySelected(asList: asList) { output in
            let priorItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
                let snapshot = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        snapshot.setData(data, forType: type)
                    }
                }
                return snapshot
            } ?? []
            pasteboard.clearContents()
            guard pasteboard.setString(output, forType: .string) else {
                pasteboard.clearContents()
                if !priorItems.isEmpty {
                    _ = pasteboard.writeObjects(priorItems)
                }
                return false
            }
            return true
        }
    }

    @discardableResult
    func copySelected(asList: Bool, using writer: (String) -> Bool) -> String? {
        let selected = orderedNotes.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return nil }
        let output: String
        if asList {
            output = selected.enumerated().map { index, note in
                "\(index + 1). \(MarkdownConverter.plainText(from: note.markdown))"
            }.joined(separator: "\n")
        } else {
            output = selected.map { $0.markdown }.joined(separator: "\n\n")
        }
        guard writer(output) else {
            showToast("Could not copy", kind: .error)
            return nil
        }
        if asList {
            markSelectedDone()
            showToast("Copied as List", kind: .copy)
        } else {
            showToast("Copied", kind: .copy)
        }
        return output
    }

    public func mergeSelected() {
        let selected = orderedNotes.filter { selectedIDs.contains($0.id) }
        guard selected.count > 1, let first = selected.first, let firstIndex = notes.firstIndex(where: { $0.id == first.id }) else { return }
        performPersistentMutation {
            notes[firstIndex].markdown = selected.map(\.markdown).joined(separator: "\n\n")
            notes[firstIndex].updatedAt = Date()
            let removeIDs = Set(selected.dropFirst().map(\.id))
            notes.removeAll { removeIDs.contains($0.id) }
            selectedIDs = [first.id]
        }
    }

    public func moveSelected(to sectionID: UUID) {
        guard sections.contains(where: { $0.id == sectionID }) else { return }
        let nextIndex = notes.filter { $0.sectionID == sectionID }.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let selectedInDisplayOrder = orderedNotes.filter { selectedIDs.contains($0.id) }
        performPersistentMutation {
            for (offset, note) in selectedInDisplayOrder.enumerated() {
                let id = note.id
                guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
                notes[index].sectionID = sectionID
                notes[index].sortIndex = nextIndex + offset
                notes[index].updatedAt = Date()
            }
            activeSectionID = sectionID
        }
    }

    @discardableResult
    public func requestEditInNewWindow(_ noteID: UUID) -> Bool {
        guard notes.contains(where: { $0.id == noteID }), let openEditor else { return false }
        openEditor(noteID)
        return true
    }

    public func showToast(_ message: String, kind: CopperToastKind) {
        toast = CopperToast(message: message, kind: kind)
        let currentID = toast?.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self?.toast?.id == currentID { self?.toast = nil }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let document = try? JSONDecoder().decode(CopperDocument.self, from: data) else { return }
        sections = document.sections
        notes = document.notes
        preferences = document.preferences
        activeSectionID = document.activeSectionID
    }

    public func save() {
        let document = CopperDocument(sections: sections, notes: notes, preferences: preferences, activeSectionID: activeSectionID)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(document)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            showToast("Could not save notes", kind: .error)
        }
    }

    private func seedDemoContent() {
        let research = CopperSection(title: "RESEARCH", sortIndex: 0)
        let formats = CopperSection(title: "CONFIGURATION FORMATS", sortIndex: 1)
        sections = [research, formats]
        notes = [
            CopperNote(sectionID: research.id, markdown: "**Negation in inherited configs.** The moment a config can extend a base or preset, someone needs to *remove* an extension the...", sortIndex: 0),
            CopperNote(sectionID: formats.id, markdown: "Use TOML as the default declarative format, backed by a published schema", sortIndex: 0),
            CopperNote(sectionID: formats.id, markdown: "Keep the core configuration declarative even if you later add an optional TypeScript escape hatch", sortIndex: 1),
            CopperNote(sectionID: formats.id, markdown: "Three things worth locking down before it ships:", sortIndex: 2)
        ]
    }
}

public enum CapturedSelectionSource: String {
    case attributedRange
    case attributedTextMarker
    case plainTextMarker
    case plainSelectedText
}

public struct CapturedSelection {
    public let markdown: String
    public let sourceFrame: NSRect?
    public let source: CapturedSelectionSource
    public init(
        markdown: String,
        sourceFrame: NSRect?,
        source: CapturedSelectionSource = .plainSelectedText
    ) {
        self.markdown = markdown
        self.sourceFrame = sourceFrame
        self.source = source
    }
}

public extension CopperStore {
    /// The single domain ingestion point shared by production capture and the
    /// background diagnostic. One invocation can append at most one note.
    @discardableResult
    func capture(_ selection: CapturedSelection) -> CopperNote? {
        addNote(markdown: selection.markdown)
    }
}

public enum MarkdownConverter {
    public static func plainText(from markdown: String) -> String {
        guard let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return markdown
        }
        return String(attributed.characters)
    }

    public static func markdown(from value: Any) -> String? {
        if let attributed = value as? NSAttributedString {
            return markdown(from: attributed)
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : escapeMarkdownText(trimmed)
        }
        return nil
    }

    public static func markdown(from attributed: NSAttributedString) -> String? {
        guard attributed.length > 0 else { return nil }
        var result = ""
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attributes, range, _ in
            guard let substring = attributed.attributedSubstring(from: range).string as String? else { return }
            let text = substring.replacingOccurrences(of: "\u{00A0}", with: " ")
            guard !text.isEmpty else { return }
            var rendered = escapeMarkdownText(text)
            if let link = attributes[.link] as? URL {
                rendered = "[\(rendered)](\(link.absoluteString))"
            } else if let link = attributes[.link] as? String, !link.isEmpty {
                rendered = "[\(rendered)](\(link))"
            }
            var isBold = false
            var isItalic = false
            var isMonospaced = false
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                isBold = traits.contains(.bold)
                isItalic = traits.contains(.italic)
                isMonospaced = traits.contains(.monoSpace)
            }
            // AX attributed strings deliberately use Accessibility-specific
            // keys rather than AppKit's ordinary `.font` key. TextEdit and
            // other native apps expose a font dictionary whose PostScript name
            // carries the style on macOS versions before the explicit
            // AXFontBold/AXFontItalic attributes were introduced.
            if let fontInfo = attributes[.accessibilityFont] as? NSDictionary {
                let fontName = [NSAccessibility.FontAttributeKey.fontName, .visibleName]
                    .compactMap { fontInfo[$0] as? String }
                    .joined(separator: " ")
                    .lowercased()
                isBold = isBold || ["bold", "semibold", "demibold", "heavy", "black"]
                    .contains(where: fontName.contains)
                isItalic = isItalic || ["italic", "oblique"].contains(where: fontName.contains)
                isMonospaced = isMonospaced || ["mono", "menlo", "courier"].contains(where: fontName.contains)
                isBold = isBold || (fontInfo["AXFontBold"] as? NSNumber)?.boolValue == true
                isItalic = isItalic || (fontInfo["AXFontItalic"] as? NSNumber)?.boolValue == true
            }
            isBold = isBold || (attributes[NSAttributedString.Key("AXFontBold")] as? NSNumber)?.boolValue == true
            isItalic = isItalic || (attributes[NSAttributedString.Key("AXFontItalic")] as? NSNumber)?.boolValue == true

            if isBold && isItalic { rendered = "***\(rendered)***" }
            else if isBold { rendered = "**\(rendered)**" }
            else if isItalic { rendered = "*\(rendered)*" }
            else if isMonospaced { rendered = "`\(rendered)`" }
            result += rendered
        }
        let normalized = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    /// AX plain-string fallbacks contain literal user text, not Markdown. Escape
    /// inline delimiters and line-leading block markers so the preview and later
    /// plain-text output preserve the selected characters rather than treating
    /// them as authored Markdown.
    private static func escapeMarkdownText(_ text: String) -> String {
        let inlineDelimiters = Set("\\`*_[]<>")
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { substring in
            let line = String(substring)
            var escaped = String(line.flatMap { character -> [Character] in
                inlineDelimiters.contains(character) ? ["\\", character] : [character]
            })
            let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }.count
            let content = line.dropFirst(leadingWhitespace)
            if let first = content.first, "#>+-".contains(first) {
                escaped.insert("\\", at: escaped.index(escaped.startIndex, offsetBy: leadingWhitespace))
            } else {
                let digitCount = content.prefix { $0.isNumber }.count
                let suffix = content.dropFirst(digitCount)
                if digitCount > 0,
                   let marker = suffix.first,
                   marker == "." || marker == ")",
                   suffix.dropFirst().first?.isWhitespace == true {
                    escaped.insert(
                        "\\",
                        at: escaped.index(escaped.startIndex, offsetBy: leadingWhitespace + digitCount)
                    )
                }
            }
            return escaped
        }.joined(separator: "\n")
    }
}

public enum AccessibilityReader {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    public static func promptForTrustIfNeeded() {
        guard !isTrusted else { return }
        // Use the documented key value directly. The SDK declares its exported
        // constant as mutable C state, which is unnecessarily rejected by Swift
        // 6 strict-concurrency checking even though this dictionary is immutable.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func selectedText() -> String? {
        selectedSelection()?.markdown
    }

    public static func selectedSelection() -> CapturedSelection? {
        selectedSelection(from: AXUIElementCreateSystemWide())
    }

    /// Reads the focused selection from a specific running application. This is
    /// used only by the background capture diagnostic so it can inspect a source
    /// app without making Copper the focused application first.
    public static func selectedSelection(applicationIdentifier: String) -> CapturedSelection? {
        guard let root = applicationElement(applicationIdentifier) else { return nil }
        return selectedSelection(from: root)
    }

    /// Returns a small, JSON-safe probe of the focused AX element for a runtime
    /// diagnostic. It is intentionally read-only and helps distinguish an
    /// inaccessible browser selection from a TCC or focus failure.
    public static func selectionProbe(applicationIdentifier: String) -> [String: Any] {
        guard let root = applicationElement(applicationIdentifier) else {
            return ["applicationFound": false]
        }
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return ["applicationFound": true, "focusedElement": false]
        }
        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var namesValue: CFArray?
        var names: [String] = []
        if AXUIElementCopyAttributeNames(focusedElement, &namesValue) == .success,
           let namesValue {
            names = (namesValue as NSArray).compactMap { $0 as? String }.sorted()
        }
        var attributes: [String: String] = [:]
        for name in [
            kAXRoleAttribute as String,
            kAXSubroleAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXValueAttribute as String,
            kAXSelectedTextAttribute as String,
            kAXSelectedTextRangeAttribute as String,
        ] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(focusedElement, name as CFString, &value) == .success,
               let value {
                attributes[name] = String(describing: value)
            }
        }
        var rangeProbe: [String: Any] = [:]
        var selectedRangeValue: CFTypeRef?
        let selectedRangeStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )
        rangeProbe["status"] = selectedRangeStatus.rawValue
        if selectedRangeStatus == .success, let selectedRangeValue {
            var attributedValue: CFTypeRef?
            let attributedStatus = AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXAttributedStringForRangeParameterizedAttribute as CFString,
                selectedRangeValue,
                &attributedValue
            )
            rangeProbe["attributedStatus"] = attributedStatus.rawValue
            if let attributedValue {
                rangeProbe["attributedRuns"] = attributedRuns(from: attributedValue)
            }
        }
        var markerRangeValue: CFTypeRef?
        let markerStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        )
        var markerProbe: [String: Any] = ["status": markerStatus.rawValue]
        if markerStatus == .success, let markerRangeValue {
            markerProbe["typeID"] = CFGetTypeID(markerRangeValue)
            var attributedValue: CFTypeRef?
            let attributedStatus = AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXAttributedStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &attributedValue
            )
            markerProbe["attributedStatus"] = attributedStatus.rawValue
            var stringValue: CFTypeRef?
            let stringStatus = AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &stringValue
            )
            markerProbe["stringStatus"] = stringStatus.rawValue
            if let stringValue {
                markerProbe["stringValue"] = String(describing: stringValue)
            }
        }
        return [
            "applicationFound": true,
            "focusedElement": true,
            "attributeNames": names,
            "attributes": attributes,
            "selectedTextRange": rangeProbe,
            "selectedTextMarkerRange": markerProbe,
        ]
    }

    private static func attributedRuns(from value: CFTypeRef) -> [[String: Any]] {
        guard CFGetTypeID(value) == CFAttributedStringGetTypeID(),
              let attributed = (value as AnyObject) as? NSAttributedString else { return [] }
        var runs: [[String: Any]] = []
        attributed.enumerateAttributes(
            in: NSRange(location: 0, length: attributed.length),
            options: []
        ) { attributes, range, _ in
            runs.append([
                "location": range.location,
                "length": range.length,
                "text": attributed.attributedSubstring(from: range).string,
                "attributes": Dictionary(uniqueKeysWithValues: attributes.map {
                    ($0.key.rawValue, String(describing: $0.value))
                }),
            ])
        }
        return runs
    }

    private static func selectedSelection(from root: AXUIElement) -> CapturedSelection? {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)

        var frame: NSRect?
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute as CFString, &positionValue) == .success,
           AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let positionValue, let sizeValue,
           CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() {
            var position = CGPoint.zero
            var size = CGSize.zero
            if AXValueGetValue(unsafeBitCast(positionValue, to: AXValue.self), .cgPoint, &position),
               AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size) {
                frame = NSRect(origin: NSPoint(x: position.x, y: position.y), size: NSSize(width: size.width, height: size.height))
            }
        }

        var rangeValue: CFTypeRef?
        var attributedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeValue,
           AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXAttributedStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &attributedValue
           ) == .success,
           let attributedValue,
           let markdown = MarkdownConverter.markdown(from: attributedValue) {
            let selectionFrame = bounds(
                of: rangeValue,
                in: focusedElement,
                parameterizedAttribute: kAXBoundsForRangeParameterizedAttribute as CFString
            )
            return CapturedSelection(
                markdown: markdown,
                sourceFrame: selectionFrame ?? textMarkerBounds(in: focusedElement) ?? frame,
                source: .attributedRange
            )
        }

        // WebKit/Safari exposes selections as text-marker ranges rather than
        // NSRange values. Ask the focused element for the attributed form first
        // and fall back to its plain string form when rich attributes are absent.
        var markerRangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        ) == .success,
           let markerRangeValue {
            let selectionFrame = bounds(
                of: markerRangeValue,
                in: focusedElement,
                parameterizedAttribute: kAXBoundsForTextMarkerRangeParameterizedAttribute as CFString
            )
            var markerAttributedValue: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXAttributedStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &markerAttributedValue
            ) == .success,
               let markerAttributedValue,
               let markdown = MarkdownConverter.markdown(from: markerAttributedValue) {
                return CapturedSelection(
                    markdown: markdown,
                    sourceFrame: selectionFrame ?? frame,
                    source: .attributedTextMarker
                )
            }

            var markerStringValue: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXStringForTextMarkerRangeParameterizedAttribute as CFString,
                markerRangeValue,
                &markerStringValue
            ) == .success,
               let markerStringValue,
               let markdown = MarkdownConverter.markdown(from: markerStringValue) {
                return CapturedSelection(
                    markdown: markdown,
                    sourceFrame: selectionFrame ?? frame,
                    source: .plainTextMarker
                )
            }
        }

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
              let selectedValue,
              let markdown = MarkdownConverter.markdown(from: selectedValue) else { return nil }
        return CapturedSelection(
            markdown: markdown,
            sourceFrame: frame,
            source: .plainSelectedText
        )
    }

    private static func bounds(
        of rangeValue: CFTypeRef,
        in element: AXUIElement,
        parameterizedAttribute: CFString
    ) -> NSRect? {
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            parameterizedAttribute,
            rangeValue,
            &boundsValue
        ) == .success,
        let boundsValue,
        CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }

        var bounds = CGRect.zero
        guard AXValueGetValue(unsafeBitCast(boundsValue, to: AXValue.self), .cgRect, &bounds),
              !bounds.isNull,
              !bounds.isInfinite,
              !bounds.isEmpty,
              bounds.width > 1,
              bounds.height > 1 else { return nil }
        return NSRect(origin: bounds.origin, size: bounds.size)
    }

    private static func textMarkerBounds(in element: AXUIElement) -> NSRect? {
        var markerRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        ) == .success,
        let markerRangeValue else { return nil }
        return bounds(
            of: markerRangeValue,
            in: element,
            parameterizedAttribute: kAXBoundsForTextMarkerRangeParameterizedAttribute as CFString
        )
    }

    private static func applicationElement(_ applicationIdentifier: String) -> AXUIElement? {
        guard let application = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == applicationIdentifier && !$0.isTerminated
        }) else { return nil }
        return AXUIElementCreateApplication(application.processIdentifier)
    }
}

public final class GlobalCaptureMonitor {
    private var monitor: Any?
    private var shiftDown = false
    private var lastShiftDown = Date.distantPast
    private var lastTrigger = Date.distantPast
    private var shortcut: CopperShortcut
    private let onCapture: () -> Void

    public init(shortcut: String = "Shift + Shift", onCapture: @escaping () -> Void) {
        let parsed = CopperShortcut.parse(shortcut)
        self.shortcut = parsed?.isSafeGlobalCapture == true
            ? parsed!
            : CopperShortcut(trigger: .doubleShift)
        self.onCapture = onCapture
    }

    public func update(shortcut rawValue: String) {
        if let parsed = CopperShortcut.parse(rawValue), parsed.isSafeGlobalCapture {
            let wasRunning = monitor != nil
            if parsed == shortcut { return }
            stop()
            shortcut = parsed
            if wasRunning { start() }
        }
    }

    public func start() {
        guard monitor == nil else { return }
        let eventMask: NSEvent.EventTypeMask = {
            switch shortcut.trigger {
            case .doubleShift: return .flagsChanged
            case .key: return .keyDown
            }
        }()
        // AppKit global monitors are observational: unlike a local monitor,
        // this callback cannot consume or replace the event, and Copper never
        // posts a synthetic replacement.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        if case .key = shortcut.trigger {
            if shortcut.matches(event) { trigger() }
            return
        }
        let conflictingModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        if !event.modifierFlags.intersection(conflictingModifiers).isEmpty {
            shiftDown = event.modifierFlags.contains(.shift)
            lastShiftDown = .distantPast
            return
        }
        let isShiftDown = event.modifierFlags.contains(.shift)
        if isShiftDown && !shiftDown {
            let now = Date()
            if now.timeIntervalSince(lastShiftDown) < 0.65 {
                trigger()
                lastShiftDown = .distantPast
                shiftDown = isShiftDown
                return
            }
            lastShiftDown = now
        }
        shiftDown = isShiftDown
    }

    /// Test-only event injection. It invokes the same decision path without
    /// registering a system monitor or posting an event back to macOS.
    public func processForTesting(_ event: NSEvent) {
        handle(event)
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        shiftDown = false
        lastShiftDown = .distantPast
    }

    private func trigger() {
        let now = Date()
        guard now.timeIntervalSince(lastTrigger) > 0.45 else { return }
        lastTrigger = now
        onCapture()
    }

    deinit {
        stop()
    }
}
