import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcomeWindowController: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.makeMainMenu(delegate: self)

        if NSDocumentController.shared.documents.isEmpty {
            showWelcomeWindow()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let markdownURLs = urls.filter { MarkdownDocument.supports(url: $0) }
        guard !markdownURLs.isEmpty else { return }

        for url in markdownURLs {
            if let existing = NSDocumentController.shared.documents.first(where: { $0.fileURL == url }) {
                existing.showWindows()
                closeWelcomeWindow()
                continue
            }

            do {
                let document = try MarkdownDocument(contentsOf: url, ofType: "Markdown")
                NSDocumentController.shared.addDocument(document)
                document.makeWindowControllers()
                document.showWindows()
                closeWelcomeWindow()
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = MarkdownDocument.readableContentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "打开"

        guard panel.runModal() == .OK else { return }
        application(NSApp, open: panel.urls)
    }

    @objc func showWelcome(_ sender: Any?) {
        showWelcomeWindow()
    }

    func documentDidOpen() {
        closeWelcomeWindow()
    }

    private func showWelcomeWindow() {
        if welcomeWindowController == nil {
            welcomeWindowController = WelcomeWindowController(
                openAction: { [weak self] in self?.openDocument(nil) },
                openURLs: { [weak self] urls in
                    guard let self else { return }
                    self.application(NSApp, open: urls)
                }
            )
        }
        welcomeWindowController?.showWindow(nil)
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func closeWelcomeWindow() {
        welcomeWindowController?.close()
        welcomeWindowController = nil
    }
}

private enum MainMenuBuilder {
    @MainActor
    static func makeMainMenu(delegate: AppDelegate) -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        appItem.submenu = makeApplicationMenu()

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        fileItem.submenu = makeFileMenu(delegate: delegate)

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        editItem.submenu = makeEditMenu()

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        viewItem.submenu = makeViewMenu()

        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = makeWindowMenu()
        windowItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    @MainActor
    private static func makeApplicationMenu() -> NSMenu {
        let menu = NSMenu(title: "MMD")
        menu.addItem(withTitle: "关于 MMD", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "隐藏 MMD", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "全部显示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 MMD", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @MainActor
    private static func makeFileMenu(delegate: AppDelegate) -> NSMenu {
        let menu = NSMenu(title: "文件")
        let open = menu.addItem(withTitle: "打开…", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        open.target = delegate
        let welcome = menu.addItem(withTitle: "打开欢迎页", action: #selector(AppDelegate.showWelcome(_:)), keyEquivalent: "")
        welcome.target = delegate
        menu.addItem(.separator())
        menu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    @MainActor
    private static func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: "编辑")
        menu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(.separator())

        let find = menu.addItem(withTitle: "查找…", action: #selector(NSTextView.performTextFinderAction(_:)), keyEquivalent: "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        let next = menu.addItem(withTitle: "查找下一个", action: #selector(NSTextView.performTextFinderAction(_:)), keyEquivalent: "g")
        next.tag = NSTextFinder.Action.nextMatch.rawValue
        let previous = menu.addItem(withTitle: "查找上一个", action: #selector(NSTextView.performTextFinderAction(_:)), keyEquivalent: "g")
        previous.keyEquivalentModifierMask = [.command, .shift]
        previous.tag = NSTextFinder.Action.previousMatch.rawValue
        return menu
    }

    @MainActor
    private static func makeViewMenu() -> NSMenu {
        let menu = NSMenu(title: "显示")
        menu.addItem(withTitle: "显示/隐藏目录", action: #selector(ReaderViewController.toggleSidebar(_:)), keyEquivalent: "0")
        menu.addItem(.separator())
        menu.addItem(withTitle: "放大文字", action: #selector(ReaderViewController.zoomIn(_:)), keyEquivalent: "+")
        menu.addItem(withTitle: "缩小文字", action: #selector(ReaderViewController.zoomOut(_:)), keyEquivalent: "-")
        menu.addItem(withTitle: "实际大小", action: #selector(ReaderViewController.resetZoom(_:)), keyEquivalent: "0")
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(.separator())
        menu.addItem(withTitle: "切换纸张主题", action: #selector(ReaderViewController.togglePaperTheme(_:)), keyEquivalent: "t")
        menu.items.last?.keyEquivalentModifierMask = [.command, .option]
        return menu
    }

    @MainActor
    private static func makeWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "窗口")
        menu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "前置全部窗口", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        return menu
    }
}
