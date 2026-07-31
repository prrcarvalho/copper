import AppKit
import ApplicationServices
import Combine
import Foundation

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

public struct CopperPreferences: Codable {
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
        guard capture.isSafeGlobalCapture else {
            return "Global capture shortcuts must include Command, Option, Control, or Shift."
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
        if tokens.count == 2, tokens.allSatisfy({ $0 == "SHIFT" }) {
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

    /// A global key-down monitor must never bind an ordinary unmodified key,
    /// otherwise normal typing could trigger captures system-wide.
    public var isSafeGlobalCapture: Bool {
        switch trigger {
        case .doubleShift:
            return true
        case let .key(_, modifiers):
            return !modifiers.isEmpty
        }
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
    @Published public private(set) var activeSectionID: UUID? = nil
    @Published public var expandedID: UUID? = nil
    @Published public var editingID: UUID? = nil
    @Published public var toast: CopperToast?

    public let fileURL: URL
    public var openEditor: ((UUID) -> Void)?

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

    @discardableResult
    public func addNote(markdown: String, sectionID: UUID? = nil) -> CopperNote? {
        let cleaned = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let destination = sectionID ?? activeSectionID ?? orderedSections.first?.id ?? addSection(title: "INBOX").id
        guard sections.contains(where: { $0.id == destination }) else { return nil }
        activeSectionID = destination
        let index = notes.filter { $0.sectionID == destination }.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let note = CopperNote(sectionID: destination, markdown: cleaned, sortIndex: index)
        notes.append(note)
        save()
        return note
    }

    @discardableResult
    public func addSection(title: String) -> CopperSection {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = CopperSection(title: cleaned.isEmpty ? "UNTITLED" : cleaned.uppercased(), sortIndex: sections.count)
        sections.append(section)
        activeSectionID = section.id
        save()
        return section
    }

    public func setActiveSection(_ sectionID: UUID) {
        guard sections.contains(where: { $0.id == sectionID }) else { return }
        activeSectionID = sectionID
        save()
    }

    public func updateNote(id: UUID, markdown: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        notes[index].markdown = cleaned
        notes[index].updatedAt = Date()
        editingID = nil
        save()
    }

    public func toggleCompleted(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isCompleted.toggle()
        notes[index].updatedAt = Date()
        save()
    }

    public func toggleSelection(_ id: UUID) {
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

    public func ensureSelected(_ id: UUID) {
        if !selectedIDs.contains(id) {
            selectedIDs = [id]
        }
    }

    public func clearSelection() {
        selectedIDs.removeAll()
    }

    public func markSelectedDone() {
        for id in selectedIDs {
            guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
            notes[index].isCompleted = true
            notes[index].updatedAt = Date()
        }
        save()
    }

    public func toggleSelectedCompletion() {
        let selected = selectedIDs
        guard !selected.isEmpty else { return }
        for id in selected {
            guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
            notes[index].isCompleted.toggle()
            notes[index].updatedAt = Date()
        }
        save()
    }

    @discardableResult
    public func copySelected(asList: Bool) -> String? {
        let selected = orderedNotes.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return nil }
        let output: String
        if asList {
            output = selected.enumerated().map { index, note in
                "\(index + 1). \(plainText(note.markdown))"
            }.joined(separator: "\n")
        } else {
            output = selected.map { $0.markdown }.joined(separator: "\n\n")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
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
        notes[firstIndex].markdown = selected.map(\.markdown).joined(separator: "\n\n")
        notes[firstIndex].updatedAt = Date()
        let removeIDs = Set(selected.dropFirst().map(\.id))
        notes.removeAll { removeIDs.contains($0.id) }
        selectedIDs = [first.id]
        save()
    }

    public func moveSelected(to sectionID: UUID) {
        guard sections.contains(where: { $0.id == sectionID }) else { return }
        let nextIndex = notes.filter { $0.sectionID == sectionID }.map(\.sortIndex).max().map { $0 + 1 } ?? 0
        let selectedInDisplayOrder = orderedNotes.filter { selectedIDs.contains($0.id) }
        for (offset, note) in selectedInDisplayOrder.enumerated() {
            let id = note.id
            guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
            notes[index].sectionID = sectionID
            notes[index].sortIndex = nextIndex + offset
            notes[index].updatedAt = Date()
        }
        activeSectionID = sectionID
        save()
    }

    public func showToast(_ message: String, kind: CopperToastKind) {
        toast = CopperToast(message: message, kind: kind)
        let currentID = toast?.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self?.toast?.id == currentID { self?.toast = nil }
        }
    }

    private func plainText(_ markdown: String) -> String {
        markdown.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
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

public struct CapturedSelection {
    public let markdown: String
    public let sourceFrame: NSRect?
    public init(markdown: String, sourceFrame: NSRect?) {
        self.markdown = markdown
        self.sourceFrame = sourceFrame
    }
}

public enum MarkdownConverter {
    public static func markdown(from value: Any) -> String? {
        if let attributed = value as? NSAttributedString {
            return markdown(from: attributed)
        }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
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
            var rendered = text
            if let link = attributes[.link] as? URL {
                rendered = "[\(rendered)](\(link.absoluteString))"
            } else if let link = attributes[.link] as? String, !link.isEmpty {
                rendered = "[\(rendered)](\(link))"
            }
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                let isBold = traits.contains(.bold)
                let isItalic = traits.contains(.italic)
                if isBold && isItalic { rendered = "***\(rendered)***" }
                else if isBold { rendered = "**\(rendered)**" }
                else if isItalic { rendered = "*\(rendered)*" }
                else if font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
                    rendered = "`\(rendered)`"
                }
            }
            result += rendered
        }
        let normalized = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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
            "selectedTextMarkerRange": markerProbe,
        ]
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
            return CapturedSelection(markdown: markdown, sourceFrame: selectionFrame ?? frame)
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
                return CapturedSelection(markdown: markdown, sourceFrame: selectionFrame ?? frame)
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
                return CapturedSelection(markdown: markdown, sourceFrame: selectionFrame ?? frame)
            }
        }

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
              let selectedValue,
              let markdown = MarkdownConverter.markdown(from: selectedValue) else { return nil }
        return CapturedSelection(markdown: markdown, sourceFrame: frame)
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
              !bounds.isInfinite else { return nil }
        return NSRect(origin: bounds.origin, size: bounds.size)
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
        monitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        if case .key = shortcut.trigger {
            if shortcut.matches(event) { trigger() }
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
