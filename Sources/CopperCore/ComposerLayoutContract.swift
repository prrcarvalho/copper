import Foundation

/// Small, testable layout contract shared by the bottom composer and its
/// narrow formal seam. The visual implementation remains in MainPanelView.
public enum CopperComposerLayout {
    public enum ControlVerticalAlignment: Equatable {
        case top
        case center
    }

    public static let placeholder = "Add a note or a prompt"
    public static let controlVerticalAlignment: ControlVerticalAlignment = .center
    public static let controlSize: CGFloat = 24
    public static let fieldLineLimit = 1...
    public static let minimumHeight: CGFloat = 29
    public static let maximumHeight: CGFloat = 112
    public static let textVerticalPadding: CGFloat = 12
}
