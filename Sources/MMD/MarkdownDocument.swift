import AppKit
import UniformTypeIdentifiers

@objc(MarkdownDocument)
@MainActor
final class MarkdownDocument: NSDocument {
    static let readableContentTypes: [UTType] = [
        UTType(filenameExtension: "md") ?? .plainText,
        UTType(filenameExtension: "markdown") ?? .plainText,
    ]

    nonisolated(unsafe) private(set) var source = ""

    override class var autosavesInPlace: Bool { false }

    static func supports(url: URL) -> Bool {
        ["md", "markdown"].contains(url.pathExtension.lowercased())
    }

    override func read(from data: Data, ofType typeName: String) throws {
        source = try FileEncodingDetector.decode(data)
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(source.utf8)
    }

    override func makeWindowControllers() {
        let reader = ReaderViewController(
            source: source,
            baseURL: fileURL?.deletingLastPathComponent()
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = reader
        window.addTitlebarAccessoryViewController(reader.makeSidebarTitlebarAccessory())
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isRestorable = false
        window.minSize = NSSize(width: 600, height: 420)
        window.center()

        let controller = NSWindowController(window: window)
        addWindowController(controller)
        (NSApp.delegate as? AppDelegate)?.documentDidOpen()
    }

    override func showWindows() {
        super.showWindows()
        for controller in windowControllers {
            guard let window = controller.window else { continue }
            window.setContentSize(NSSize(width: 940, height: 720))
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
