@testable import CopperCore
import Testing

@Suite("Copper composer layout", .serialized)
@MainActor
struct ComposerLayoutTests {
    @Test("Composer keeps the accepted inline placeholder and centered control contract")
    func composerLayoutContract() {
        #expect(CopperComposerLayout.placeholder == "Add a note or a prompt")
        #expect(CopperComposerLayout.controlVerticalAlignment == .center)
        #expect(CopperComposerLayout.controlSize == 24)
        #expect(CopperComposerLayout.fieldLineLimit == 1...5)
    }
}
