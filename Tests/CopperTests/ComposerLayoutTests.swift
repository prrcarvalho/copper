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
        #expect(CopperComposerLayout.fieldLineLimit.lowerBound == 1)
        #expect(CopperComposerLayout.fieldLineLimit.contains(12))
        #expect(CopperComposerLayout.minimumHeight > 0)
        #expect(CopperComposerLayout.maximumHeight > CopperComposerLayout.minimumHeight)
        #expect(CopperComposerLayout.textVerticalPadding > 0)
        #expect(CopperComposerLayout.controlAlignment(for: CopperComposerLayout.minimumHeight) == .center)
        #expect(CopperComposerLayout.controlAlignment(for: CopperComposerLayout.maximumHeight) == .top)
    }
}
