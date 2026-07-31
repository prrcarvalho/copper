import AppKit
import Foundation

@main
@MainActor
struct CopperSmoke {
    static func main() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("copper-smoke-\(UUID().uuidString)")
            .appendingPathComponent("notes.json")
        let store = CopperStore(fileURL: url, seedIfEmpty: false)
        let research = store.addSection(title: "Research")
        let queue = store.addSection(title: "Queue")
        let first = store.addNote(markdown: "First prompt", sectionID: research.id)!
        let second = store.addNote(markdown: "**Second** prompt", sectionID: research.id)!

        store.toggleSelection(first.id)
        store.toggleSelection(second.id)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("CopperSmoke-\(UUID().uuidString)"))
        precondition(store.copySelected(asList: true, to: pasteboard) == "1. First prompt\n2. Second prompt")
        precondition(store.notes.allSatisfy(\.isCompleted))

        store.searchText = "first"
        precondition(store.visibleNotes(for: research).count == 1)
        store.searchText = ""
        store.mergeSelected()
        precondition(store.notes.count == 1)
        store.moveSelected(to: queue.id)
        precondition(store.notes.first?.sectionID == queue.id)
        store.updateNote(id: first.id, markdown: "Edited prompt")
        precondition(store.notes.first?.markdown == "Edited prompt")

        let reloaded = CopperStore(fileURL: url, seedIfEmpty: false)
        precondition(reloaded.notes.count == 1)
        precondition(reloaded.notes.first?.sectionID == queue.id)
        precondition(reloaded.notes.first?.markdown == "Edited prompt")
        print("CopperSmoke: passed copy, completion, search, edit, merge, move, and persistence")
    }
}
