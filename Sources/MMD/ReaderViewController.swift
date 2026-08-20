import AppKit

@MainActor
final class ReaderViewController: NSSplitViewController {
    private let source: String
    private let baseURL: URL?
    private let preferences = ReaderPreferences.shared
    private let tocController = TableOfContentsViewController()
    private let textView = ReaderTextView.make()
    private var sidebarItem: NSSplitViewItem?
    private var remoteImageTasks: [Task<Void, Never>] = []
    private var hasConfiguredInitialSidebarState = false

    var isSidebarCollapsed: Bool {
        sidebarItem?.isCollapsed ?? true
    }

    var sidebarBehavior: NSSplitViewItem.Behavior? {
        sidebarItem?.behavior
    }

    init(source: String, baseURL: URL?) {
        self.source = source
        self.baseURL = baseURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        remoteImageTasks.forEach { $0.cancel() }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
        renderDocument()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        applyTheme()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
    }

    @objc override func toggleSidebar(_ sender: Any?) {
        guard let sidebarItem else { return }
        sidebarItem.isCollapsed = !sidebarItem.isCollapsed
    }

    func makeSidebarTitlebarAccessory() -> NSTitlebarAccessoryViewController {
        let button = NSButton(
            image: NSImage(
                systemSymbolName: "sidebar.left",
                accessibilityDescription: "显示或隐藏目录"
            ) ?? NSImage(),
            target: self,
            action: #selector(toggleSidebar(_:))
        )
        button.frame = NSRect(x: 0, y: 0, width: 36, height: 28)
        button.bezelStyle = .accessoryBarAction
        button.imagePosition = .imageOnly
        button.toolTip = "显示或隐藏目录（⌘0）"
        button.setAccessibilityLabel("显示或隐藏目录")

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .left
        accessory.view = button
        return accessory
    }

    @objc func zoomIn(_ sender: Any?) {
        preferences.fontSize = preferences.fontSize + 1
        renderDocument(preservingPosition: true)
    }

    @objc func zoomOut(_ sender: Any?) {
        preferences.fontSize = preferences.fontSize - 1
        renderDocument(preservingPosition: true)
    }

    @objc func resetZoom(_ sender: Any?) {
        preferences.fontSize = 16
        renderDocument(preservingPosition: true)
    }

    @objc func togglePaperTheme(_ sender: Any?) {
        preferences.theme = preferences.theme == .system ? .paper : .system
        renderDocument(preservingPosition: true)
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true

        tocController.onSelectHeading = { [weak self] heading in
            self?.textView.setSelectedRange(NSRange(location: heading.range.location, length: 0))
            self?.textView.scrollRangeToVisible(heading.range)
            self?.view.window?.makeFirstResponder(self?.textView)
        }
        let sidebar = NSSplitViewItem(viewController: tocController)
        sidebar.minimumThickness = 160
        sidebar.maximumThickness = 320
        sidebar.preferredThicknessFraction = 0.23
        sidebar.canCollapse = true
        sidebarItem = sidebar
        addSplitViewItem(sidebar)

        let scrollView = ReaderScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        let readerController = NSViewController()
        readerController.view = scrollView
        let content = NSSplitViewItem(viewController: readerController)
        content.minimumThickness = 420
        addSplitViewItem(content)
    }

    private func renderDocument(preservingPosition: Bool = false) {
        remoteImageTasks.forEach { $0.cancel() }
        remoteImageTasks.removeAll()

        let previousLocation = preservingPosition ? textView.selectedRange().location : 0
        do {
            let rendered = try MarkdownRenderer.render(
                source: source,
                baseURL: baseURL,
                fontSize: preferences.fontSize,
                theme: preferences.theme
            )
            textView.textStorage?.setAttributedString(rendered.attributedString)
            applyTheme()
            tocController.update(headings: rendered.headings)
            if !hasConfiguredInitialSidebarState {
                sidebarItem?.isCollapsed = rendered.headings.count < 2
                hasConfiguredInitialSidebarState = true
            }

            let safeLocation = min(previousLocation, max(0, rendered.attributedString.length - 1))
            if preservingPosition, rendered.attributedString.length > 0 {
                textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
                textView.scrollRangeToVisible(NSRange(location: safeLocation, length: 0))
            }
            loadRemoteImages(rendered.remoteImages)
        } catch {
            let message = NSAttributedString(
                string: "Markdown 解析失败\n\n\(error.localizedDescription)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 15),
                    .foregroundColor: NSColor.systemRed,
                ]
            )
            textView.textStorage?.setAttributedString(message)
        }
    }

    private func applyTheme() {
        let color = ReaderThemeAppearance.readerBackground(for: preferences.theme)
        let sidebarColor = ReaderThemeAppearance.sidebarBackground(for: preferences.theme)
        view.window?.appearance = ReaderThemeAppearance.windowAppearance(for: preferences.theme)
        view.window?.backgroundColor = color
        textView.backgroundColor = color
        textView.enclosingScrollView?.backgroundColor = color
        tocController.apply(theme: preferences.theme)
        splitView.layer?.backgroundColor = sidebarColor.cgColor
        splitView.needsDisplay = true
    }

    private func loadRemoteImages(_ requests: [RemoteImageRequest]) {
        remoteImageTasks = requests.map { request in
            Task { [weak self, weak attachment = request.attachment] in
                do {
                    let (data, response) = try await URLSession.shared.data(from: request.url)
                    guard !Task.isCancelled,
                          let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode),
                          data.count <= 20 * 1_024 * 1_024,
                          let image = ImageDownsampler.image(data: data),
                          let attachment
                    else { return }
                    self?.replace(attachment: attachment, with: image)
                } catch {
                    // Keep the small placeholder when a remote image is unavailable.
                }
            }
        }
    }

    private func replace(attachment: MarkdownImageAttachment, with image: NSImage) {
        guard let storage = textView.textStorage else { return }
        let wholeRange = NSRange(location: 0, length: storage.length)
        var targetRange: NSRange?
        storage.enumerateAttribute(.attachment, in: wholeRange) { value, range, stop in
            if let current = value as? MarkdownImageAttachment, current === attachment {
                targetRange = range
                stop.pointee = true
            }
        }
        guard let targetRange else { return }

        attachment.setReaderImage(image)
        let replacement = NSAttributedString(attachment: attachment)
        storage.replaceCharacters(in: targetRange, with: replacement)
        textView.needsLayout = true
        textView.needsDisplay = true
    }
}
