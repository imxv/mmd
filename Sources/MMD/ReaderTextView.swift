import AppKit

@MainActor
enum ReaderTextView {
    static func make() -> NSTextView {
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        return textView
    }
}

final class ReaderScrollView: NSScrollView {
    private let preferredContentWidth: CGFloat = 780

    override func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        // TextKit 2 lays out only the viewport. Explicitly invalidate that small
        // visible region so native table edges are repainted as fragments enter it.
        documentView?.setNeedsDisplay(clipView.documentVisibleRect)
    }

    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let horizontal = max(28, (contentView.bounds.width - preferredContentWidth) / 2)
        let desired = NSSize(width: horizontal, height: 38)
        if textView.textContainerInset != desired {
            textView.textContainerInset = desired
        }
    }
}
