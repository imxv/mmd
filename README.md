<div align="center">

# MMD

### Read Markdown. Nothing else gets in the way.

A tiny, native Markdown reader for macOS — built with AppKit and TextKit, without WebView.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![Native AppKit](https://img.shields.io/badge/UI-Native_AppKit-0A84FF)](https://developer.apple.com/documentation/appkit)
[![No WebView](https://img.shields.io/badge/WebView-none-34C759)](#why-mmd)

**English** · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

</div>

---

## Why MMD?

MMD is made for people who want to **open a Markdown file and start reading immediately**. It uses native macOS text rendering instead of embedding a browser, keeping the experience fast, focused, and lightweight.

- **Truly native** — AppKit, TextKit 2, and standard macOS windows, menus, selection, copying, links, and search
- **Small by design** — the verified Universal 2 app bundle is approximately **2.7 MB**
- **Reading-first** — a collapsible table of contents, adjustable text size, and system or paper themes
- **Local-friendly** — open files from Finder, the Open panel, or drag and drop; relative local images work as expected
- **No browser shell** — no WebView and no JavaScript runtime

## Highlights

| Native reading | Markdown support | Everyday convenience |
| --- | --- | --- |
| TextKit 2 layout | Headings and emphasis | Finder and Open panel |
| Select, copy, find, and open links | Lists and task lists | Drag and drop |
| System and paper themes | Tables, quotes, and rules | Collapsible table of contents |
| Adjustable font size | Code blocks and inline code | Local and remote images |

MMD reads UTF-8, UTF-8 with BOM, and UTF-16 documents. It supports `.md` and `.markdown` files.

> [!NOTE]
> MMD is currently an early-stage, read-only reader. HTML blocks, Mermaid, LaTeX, and code syntax highlighting are not implemented yet.

## Quick Start

### Requirements

- macOS 13 Ventura or later
- Xcode with Command Line Tools

### Build and open

```bash
git clone https://github.com/imxv/mmd.git
cd mmd
swift test
./scripts/build_app.sh
open dist/MMD.app
```

The default build targets Apple Silicon. To create a Universal 2 app for both Apple Silicon and Intel Macs:

```bash
MMD_UNIVERSAL=1 ./scripts/build_app.sh
```

The build script creates `dist/MMD.app`, strips debug symbols, and applies an ad-hoc signature. A public distribution still requires Developer ID signing and Apple notarization.

## Using MMD

1. Open MMD and choose a Markdown file, or drag one onto the welcome window.
2. Use the table of contents to jump between headings.
3. Adjust text size or switch between the system and paper themes from the **View** menu.

Useful shortcuts:

| Action | Shortcut |
| --- | --- |
| Open a document | <kbd>⌘ O</kbd> |
| Find in document | <kbd>⌘ F</kbd> |
| Show or hide the table of contents | <kbd>⌘ 0</kbd> |
| Increase / decrease text size | <kbd>⌘ +</kbd> / <kbd>⌘ −</kbd> |
| Toggle the paper theme | <kbd>⌥ ⌘ T</kbd> |

## Under the Hood

MMD is a Swift Package executable built with:

- **AppKit** for the application and native document windows
- **TextKit 2** for text layout and interaction
- **swift-markdown / cmark-gfm** for Markdown parsing
- **Foundation and ImageIO** for file decoding and image loading

There are no third-party runtime frameworks. Parser license notices are copied into the app bundle during packaging.

## Development

Run the test suite:

```bash
swift test
```

Create a release app bundle:

```bash
./scripts/build_app.sh
```

Contributions and focused bug reports are welcome. Please include your macOS version, Mac architecture, and a minimal Markdown sample when reporting rendering issues.

---

<div align="center">

Built for quiet, native reading on macOS.

</div>
