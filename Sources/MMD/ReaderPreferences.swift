import AppKit

extension Notification.Name {
    static let mmdReaderThemeDidChange = Notification.Name("com.sunmozong.mmd.reader-theme-did-change")
}

enum ReaderTheme: String, Sendable {
    case system
    case paper
}

@MainActor
enum ReaderThemeAppearance {
    static func readerBackground(for theme: ReaderTheme) -> NSColor {
        switch theme {
        case .system: .textBackgroundColor
        case .paper: NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.87, alpha: 1)
        }
    }

    static func sidebarBackground(for theme: ReaderTheme) -> NSColor {
        switch theme {
        case .system: .windowBackgroundColor
        case .paper: NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1)
        }
    }

    static func windowAppearance(for theme: ReaderTheme) -> NSAppearance? {
        switch theme {
        case .system: nil
        case .paper: NSAppearance(named: .aqua)
        }
    }
}

@MainActor
final class ReaderPreferences {
    static let shared = ReaderPreferences()

    private enum Key {
        static let fontSize = "reader.fontSize"
        static let theme = "reader.theme"
    }

    private let defaults = UserDefaults.standard

    var fontSize: CGFloat {
        get {
            let stored = defaults.double(forKey: Key.fontSize)
            return stored == 0 ? 16 : min(max(stored, 12), 28)
        }
        set {
            defaults.set(min(max(newValue, 12), 28), forKey: Key.fontSize)
        }
    }

    var theme: ReaderTheme {
        get { ReaderTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system }
        set {
            guard newValue != theme else { return }
            defaults.set(newValue.rawValue, forKey: Key.theme)
            NotificationCenter.default.post(name: .mmdReaderThemeDidChange, object: self)
        }
    }
}
