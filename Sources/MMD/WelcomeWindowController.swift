import AppKit

@MainActor
final class WelcomeWindowController: NSWindowController {
    private let preferences = ReaderPreferences.shared

    init(openAction: @escaping () -> Void, openURLs: @escaping ([URL]) -> Void) {
        let welcomeView = WelcomeView(openAction: openAction, openURLs: openURLs)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MMD"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isRestorable = false
        window.center()
        window.contentView = welcomeView
        super.init(window: window)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(readerThemeDidChange(_:)),
            name: .mmdReaderThemeDidChange,
            object: preferences
        )
        apply(theme: preferences.theme)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func showWindow(_ sender: Any?) {
        apply(theme: preferences.theme)
        super.showWindow(sender)
    }

    func apply(theme: ReaderTheme) {
        let background = ReaderThemeAppearance.readerBackground(for: theme)
        window?.appearance = ReaderThemeAppearance.windowAppearance(for: theme)
        window?.backgroundColor = background
        (window?.contentView as? WelcomeView)?.apply(theme: theme)
    }

    @objc private func readerThemeDidChange(_ notification: Notification) {
        apply(theme: preferences.theme)
    }
}

@MainActor
private final class WelcomeView: NSView {
    private let openAction: () -> Void
    private let openURLs: ([URL]) -> Void
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "MMD")
    private let subtitleLabel = NSTextField(labelWithString: "原生、轻量的 Markdown 阅读器")
    private let hintLabel = NSTextField(labelWithString: "拖入 .md 文件，或选择文件打开")
    private let openButton = NSButton()
    private var theme: ReaderTheme = .system

    init(openAction: @escaping () -> Void, openURLs: @escaping ([URL]) -> Void) {
        self.openAction = openAction
        self.openURLs = openURLs
        super.init(frame: .zero)
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggedMarkdownURLs(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = draggedMarkdownURLs(from: sender)
        guard !urls.isEmpty else { return false }
        openURLs(urls)
        return true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        apply(theme: theme)
    }

    @objc private func didClickOpen(_ sender: Any?) {
        openAction()
    }

    private func buildContent() {
        icon.image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "Markdown 文档")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 52, weight: .light)

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.alignment = .center

        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.alignment = .center

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.alignment = .center

        openButton.title = "打开 Markdown…"
        openButton.target = self
        openButton.action = #selector(didClickOpen(_:))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [icon, titleLabel, subtitleLabel, hintLabel, openButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(18, after: subtitleLabel)
        stack.setCustomSpacing(22, after: hintLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -36),
        ])
    }

    func apply(theme: ReaderTheme) {
        self.theme = theme
        appearance = ReaderThemeAppearance.windowAppearance(for: theme)
        let background = ReaderThemeAppearance.readerBackground(for: theme)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = background.cgColor
        }
        titleLabel.textColor = .labelColor
        subtitleLabel.textColor = .secondaryLabelColor
        hintLabel.textColor = .tertiaryLabelColor
        icon.contentTintColor = theme == .paper
            ? NSColor(calibratedRed: 0.34, green: 0.31, blue: 0.23, alpha: 1)
            : .secondaryLabelColor
        needsDisplay = true
    }

    private func draggedMarkdownURLs(from sender: NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self])?
            .compactMap { $0 as? URL }
            .filter { MarkdownDocument.supports(url: $0) } ?? []
    }
}
