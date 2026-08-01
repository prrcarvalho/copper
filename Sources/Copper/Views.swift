import AppKit
import CopperCore
import SwiftUI

private struct CopperForceReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CopperForceDifferentiateWithoutColorKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CopperForceHighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var copperForceReduceMotion: Bool {
        get { self[CopperForceReduceMotionKey.self] }
        set { self[CopperForceReduceMotionKey.self] = newValue }
    }

    var copperForceDifferentiateWithoutColor: Bool {
        get { self[CopperForceDifferentiateWithoutColorKey.self] }
        set { self[CopperForceDifferentiateWithoutColorKey.self] = newValue }
    }

    var copperForceHighContrast: Bool {
        get { self[CopperForceHighContrastKey.self] }
        set { self[CopperForceHighContrastKey.self] = newValue }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

final class CopperDragStripView: NSView {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        moveWindow(to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        if let window, dragStartMouseLocation != nil, dragStartWindowOrigin != nil {
            // Computer Use and some AppKit event paths can deliver the final
            // pointer position without an intermediate mouseDragged event.
            // Apply the accumulated delta on mouse-up as a safe native fallback.
            moveWindow(to: NSEvent.mouseLocation)
            window.saveFrame(usingName: CopperWindowGeometry.autosaveName)
        }
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func moveWindow(to currentMouseLocation: NSPoint) {
        guard let window, let dragStartMouseLocation, let dragStartWindowOrigin else { return }
        window.setFrameOrigin(NSPoint(
            x: dragStartWindowOrigin.x + currentMouseLocation.x - dragStartMouseLocation.x,
            y: dragStartWindowOrigin.y + currentMouseLocation.y - dragStartMouseLocation.y
        ))
    }

    override var isOpaque: Bool { false }
}

/// AppKit wrapper used by the production panel. Keeping the transparent drag
/// strip outside NSHostingView avoids SwiftUI hit-testing differences between
/// a nonactivating panel and a regular window.
@MainActor
final class CopperPanelContentView: NSView {
    private let hostingView: NSView
    private let dragStrip = CopperDragStripView()

    init(hostingView: NSView) {
        self.hostingView = hostingView
        super.init(frame: .zero)
        wantsLayer = true
        hostingView.autoresizingMask = [.width, .height]
        dragStrip.autoresizingMask = [.width, .minYMargin]
        dragStrip.wantsLayer = true
        dragStrip.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hostingView)
        addSubview(dragStrip)
    }

    required init?(coder: NSCoder) {
        nil
    }

    var diagnosticDragStripFrame: NSRect { dragStrip.frame }

    override func layout() {
        super.layout()
        hostingView.frame = bounds
        dragStrip.frame = NSRect(
            x: bounds.minX,
            y: bounds.maxY - 66,
            width: bounds.width,
            height: 8
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if dragStrip.frame.contains(point) {
            return dragStrip
        }
        return super.hitTest(point)
    }
}

struct MainPanelView: View {
    @ObservedObject var store: CopperStore
    @State private var newSectionTitle = ""
    @State private var isAddingSection = false
    @State private var isShowingSettings = false
    @State private var draft = ""
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.copperForceReduceMotion) private var forceReduceMotion

    private var reduceMotion: Bool { systemReduceMotion || forceReduceMotion }

    var body: some View {
        ZStack(alignment: .bottom) {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.35)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if store.orderedSections.allSatisfy({ store.visibleNotes(for: $0).isEmpty }) {
                            EmptyQueueView(isSearching: !store.searchText.isEmpty)
                        } else {
                            ForEach(store.orderedSections) { section in
                                let visible = store.visibleNotes(for: section)
                                if !visible.isEmpty || store.searchText.isEmpty {
                                    sectionView(section, notes: visible)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 122)
                }
                .scrollIndicators(.hidden)

                Divider().opacity(0.35)
                composer
            }

            if let toast = store.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 102)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.48), lineWidth: 1)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(store: store)
        }
        .alert("New section", isPresented: $isAddingSection) {
            TextField("Section name", text: $newSectionTitle)
            Button("Cancel", role: .cancel) { newSectionTitle = "" }
            Button("Create") {
                _ = store.addSection(title: newSectionTitle)
                newSectionTitle = ""
            }
        } message: {
            Text("Group related notes under a short uppercase title.")
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.toast?.id)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .accessibilityLabel("Search notes")
            }
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(Color.white.opacity(0.56), in: Capsule())

            Menu {
                Button("New Section") { isAddingSection = true }
                Button("Settings") { isShowingSettings = true }
                Divider()
                Button("Clear Selection") { store.clearSelection() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.56), in: Circle())
                    .contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .focusable(true)
            .accessibilityLabel("Options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func sectionView(_ section: CopperSection, notes: [CopperNote]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.setActiveSection(section.id)
            } label: {
                HStack(spacing: 10) {
                    Text(section.title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.15)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.primary.opacity(store.activeSectionID == section.id ? 0.25 : 0.13))
                        .frame(height: store.activeSectionID == section.id ? 2 : 1)
                }
            }
            .buttonStyle(.plain)
            .focusable(true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Section \(section.title)")
            .accessibilityValue(store.activeSectionID == section.id ? "Active" : "Inactive")

            ForEach(notes) { note in
                NoteCard(note: note, store: store)
            }
        }
    }

    private var composer: some View {
        let controlAlignment: VerticalAlignment =
            CopperComposerLayout.controlVerticalAlignment == .center ? .center : .top

        return HStack(alignment: controlAlignment, spacing: 12) {
            Button {
                composerFocused = true
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.75))
                    .frame(
                        width: CopperComposerLayout.controlSize,
                        height: CopperComposerLayout.controlSize
                    )
            }
            .buttonStyle(.plain)
            .focusable(true)
            .accessibilityLabel("Focus composer")

            TextField(
                CopperComposerLayout.placeholder,
                text: $draft,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.body)
            .lineLimit(CopperComposerLayout.fieldLineLimit)
            .padding(.vertical, 6)
            .focused($composerFocused)
            .onSubmit(commitDraft)
            .accessibilityLabel("Add a note or a prompt")
            .accessibilityAction(named: "Add note") { commitDraft() }
        }
        .padding(14)
        .background(Color.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(
                    composerFocused ? Color.accentColor : Color.white.opacity(0.42),
                    lineWidth: composerFocused ? 2.5 : 1
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func commitDraft() {
        _ = store.addNote(markdown: draft)
        draft = ""
        composerFocused = false
    }
}

struct NoteCard: View {
    let note: CopperNote
    @ObservedObject var store: CopperStore
    @FocusState private var cardFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemDifferentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.copperForceReduceMotion) private var forceReduceMotion
    @Environment(\.copperForceDifferentiateWithoutColor) private var forceDifferentiateWithoutColor
    @Environment(\.copperForceHighContrast) private var forceHighContrast

    private var isSelected: Bool { store.selectedIDs.contains(note.id) }
    private var reduceMotion: Bool { systemReduceMotion || forceReduceMotion }
    private var emphasizeSelectionWithoutColor: Bool {
        systemDifferentiateWithoutColor
            || forceDifferentiateWithoutColor
            || systemContrast == .increased
            || forceHighContrast
    }

    var body: some View {
        if store.editingID == note.id {
            InlineEditorCard(note: note, store: store)
        } else if store.expandedID == note.id {
            expandedCard
        } else {
            regularCard
        }
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expanded note")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Collapse") { store.expandedID = nil }
                    .buttonStyle(.borderless)
            }
            MarkdownPreview(markdown: note.markdown, lineLimit: nil)
                .foregroundStyle(note.isCompleted ? .secondary : .primary)
                .strikethrough(note.isCompleted, color: .secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.accentColor.opacity(0.72), lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expanded note")
    }

    private var regularCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleCompleted(note.id)
            } label: {
                Image(systemName: note.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(note.isCompleted ? Color.accentColor : Color.secondary.opacity(0.75))
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isCompleted ? "Mark note as not done" : "Mark note as done")
            .accessibilityValue(note.isCompleted ? "Completed" : "Not completed")

            MarkdownPreview(markdown: note.markdown)
                .foregroundStyle(note.isCompleted ? .secondary : .primary)
                .strikethrough(note.isCompleted, color: .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(
                emphasizeSelectionWithoutColor ? 0.94 : (note.isCompleted ? 0.40 : 0.76)
            ),
            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.accentColor
                        : (cardFocused ? Color.accentColor.opacity(0.68) : Color.white.opacity(0.42)),
                    lineWidth: isSelected
                        ? (emphasizeSelectionWithoutColor ? 3 : 2.5)
                        : (cardFocused ? 2 : 1)
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .onTapGesture { store.toggleSelection(note.id) }
        .focusable(true)
        .focused($cardFocused)
        // Keep the card in the keyboard/accessibility focus system, but own
        // the visual focus ring so Escape can clear card focus independently
        // from the store-backed selection outline.
        .focusEffectDisabled()
        .onChange(of: cardFocused) { _, isFocused in
            if isFocused {
                store.setFocusedCard(note.id)
            } else if store.focusedCardID == note.id {
                store.setFocusedCard(nil)
            }
        }
        .onChange(of: store.focusedCardID) { _, focusedID in
            if focusedID != note.id, cardFocused {
                cardFocused = false
            }
        }
        .onKeyPress(keys: [.space], action: handleSpaceKey)
        .onKeyPress(keys: [.delete], action: handleDeleteKey)
        .onKeyPress(keys: [.escape], action: handleEscapeKey)
        .onKeyPress(keys: [.return], action: handleReturnKey)
        // The card itself exposes the note label/value and every semantic
        // action. Ignore its visual check/text children so VoiceOver does not
        // announce each note three times in sequence.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MarkdownConverter.plainText(from: note.markdown))
        .accessibilityValue(
            "\(note.isCompleted ? "Completed" : "Not completed"), \(isSelected ? "selected" : "not selected")"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityActions {
            Button(isSelected ? "Deselect" : "Select") {
                store.toggleSelection(note.id)
            }
            Button(note.isCompleted ? "Mark as not done" : "Mark as done") {
                store.toggleCompleted(note.id)
            }
            Button("Copy") {
                store.ensureSelected(note.id)
                _ = store.copySelected(asList: false)
            }
            Button("Copy as List") {
                store.ensureSelected(note.id)
                _ = store.copySelected(asList: true)
            }
            if store.selectedIDs.count <= 1 {
                Button("Expand") {
                    store.ensureSelected(note.id)
                    store.expandedID = note.id
                }
            }
            Button("Edit") {
                _ = store.handleCardReturn(noteID: note.id, openInNewWindow: false)
            }
            Button("Edit in New Window") {
                _ = store.handleCardReturn(noteID: note.id, openInNewWindow: true)
            }
            if store.selectedIDs.count > 1 {
                Button("Merge Notes") {
                    store.ensureSelected(note.id)
                    store.mergeSelected()
                }
            }
            ForEach(store.orderedSections) { destination in
                Button("Move to \(destination.title)") {
                    store.ensureSelected(note.id)
                    store.moveSelected(to: destination.id)
                }
            }
        }
        .contextMenu { contextMenu }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isSelected)
    }

    private func handleSpaceKey(_ keyPress: KeyPress) -> KeyPress.Result {
        let modifiers = keyPress.modifiers
        if modifiers == .command {
            store.toggleSelection(note.id)
        } else if modifiers.isEmpty {
            store.handleCardSpace(noteID: note.id)
        } else {
            return .ignored
        }
        return .handled
    }

    private func handleDeleteKey(_ keyPress: KeyPress) -> KeyPress.Result {
        guard keyPress.modifiers == .command else { return .ignored }
        store.deleteSelected()
        return .handled
    }

    private func handleEscapeKey(_ keyPress: KeyPress) -> KeyPress.Result {
        guard keyPress.modifiers.isEmpty else { return .ignored }
        _ = store.handleEscape()
        return .handled
    }

    private func handleReturnKey(_ keyPress: KeyPress) -> KeyPress.Result {
        let modifiers = keyPress.modifiers
        let commandOnly = modifiers == .command
        guard modifiers.isEmpty || commandOnly else { return .ignored }
        _ = store.handleCardReturn(noteID: note.id, openInNewWindow: commandOnly)
        return .handled
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy") {
            store.ensureSelected(note.id)
            _ = store.copySelected(asList: false)
        }
        .keyboardShortcut("c", modifiers: [.command])

        Button("Copy as List") {
            store.ensureSelected(note.id)
            _ = store.copySelected(asList: true)
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Divider()

        Button("Mark as Done") {
            store.ensureSelected(note.id)
            store.markSelectedDone()
        }
        .keyboardShortcut(.space, modifiers: [])

        Button("Expand") {
            store.ensureSelected(note.id)
            store.expandedID = note.id
        }
        .disabled(store.selectedIDs.count > 1 && !store.selectedIDs.isEmpty)

        Divider()

        Button("Edit") {
            store.ensureSelected(note.id)
            store.editingID = note.id
        }
        .keyboardShortcut(.return, modifiers: [])

        Button("Edit in New Window") {
            store.ensureSelected(note.id)
            store.requestEditInNewWindow(note.id)
        }
        .keyboardShortcut(.return, modifiers: [.command])

        Button("Merge Notes") {
            store.ensureSelected(note.id)
            store.mergeSelected()
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])

        Menu("Move to") {
            ForEach(store.orderedSections) { destination in
                Button(destination.title) {
                    store.ensureSelected(note.id)
                    store.moveSelected(to: destination.id)
                }
            }
        }
    }
}

struct InlineEditorCard: View {
    let note: CopperNote
    @ObservedObject var store: CopperStore
    @State private var draft: String

    init(note: CopperNote, store: CopperStore) {
        self.note = note
        self.store = store
        _draft = State(initialValue: note.markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 88, maxHeight: 150)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
                .accessibilityLabel("Edit note")

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { store.editingID = nil }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save") {
                    store.updateNote(id: note.id, markdown: draft)
                    store.editingID = nil
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editing note")
    }
}

struct MarkdownPreview: View {
    let markdown: String
    var lineLimit: Int? = 4

    var body: some View {
        Group {
            if let attributed = try? AttributedString(markdown: markdown) {
                Text(attributed)
            } else {
                Text(markdown)
            }
        }
        .font(.body)
        .lineSpacing(2)
        .lineLimit(lineLimit)
        .multilineTextAlignment(.leading)
    }
}

struct EmptyQueueView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isSearching ? "magnifyingglass" : "tray")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.secondary)
            Text(isSearching ? "No matching notes" : "Your queue is empty")
                .font(.headline)
            Text(isSearching ? "Try another search." : "Capture text or add a prompt below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .accessibilityElement(children: .combine)
    }
}

struct ToastView: View {
    let toast: CopperToast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
            Text(toast.message)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(backgroundColor, in: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .accessibilityAddTraits(.isStaticText)
    }

    private var iconName: String {
        switch toast.kind {
        case .capture: return "bolt.fill"
        case .copy: return "checkmark.circle.fill"
        case .neutral: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var foregroundColor: Color {
        toast.kind == .capture ? .white : .primary
    }

    private var backgroundColor: Color {
        toast.kind == .capture ? .black.opacity(0.88) : Color.white.opacity(0.88)
    }
}

struct EditorView: View {
    @ObservedObject var store: CopperStore
    let noteID: UUID
    @State private var draft: String
    @Environment(\.dismiss) private var dismiss

    init(store: CopperStore, noteID: UUID) {
        self.store = store
        self.noteID = noteID
        _draft = State(initialValue: store.notes.first(where: { $0.id == noteID })?.markdown ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit note")
                .font(.title3.weight(.semibold))
            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    store.updateNote(id: noteID, markdown: draft)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(24)
        .frame(minWidth: 470, minHeight: 300)
    }
}

struct SettingsView: View {
    @ObservedObject var store: CopperStore
    @Environment(\.dismiss) private var dismiss
    @State private var captureShortcutDraft: String

    init(store: CopperStore) {
        self.store = store
        _captureShortcutDraft = State(initialValue: store.preferences.captureShortcut)
    }

    private var captureValidationMessage: String? {
        var candidate = store.preferences
        candidate.captureShortcut = captureShortcutDraft
        return candidate.captureShortcutValidationMessage
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Form {
                Section("Capture") {
                    TextField("Capture shortcut", text: $captureShortcutDraft)
                    if let captureValidationMessage {
                        Label(captureValidationMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Text("Double Shift or a key combination captures the selected text from the active app when Accessibility access is available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset") {
                            captureShortcutDraft = "Shift + Shift"
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Keyboard") {
                    TextField("Copy", text: $store.preferences.copyShortcut)
                    TextField("Copy as List", text: $store.preferences.copyAsListShortcut)
                    TextField("Mark as Done", text: $store.preferences.markDoneShortcut)
                }

                Section("Privacy") {
                    Label("Notes stay on this Mac", systemImage: "lock.shield")
                    Label("The native app sends no analytics, note telemetry, uploads, crash reports, or sync traffic", systemImage: "eye.slash")
                    Label(AccessibilityReader.isTrusted ? "Accessibility access is available" : "Accessibility access is required for capture", systemImage: AccessibilityReader.isTrusted ? "checkmark.circle" : "exclamationmark.triangle")
                }
            }
            .formStyle(.grouped)
            .padding(20)

            HStack {
                Spacer()
                Button("Done") {
                    guard captureValidationMessage == nil else { return }
                    store.preferences.captureShortcut = captureShortcutDraft
                    store.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(captureValidationMessage != nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(width: 500, height: 410)
        .onDisappear { store.save() }
    }
}
