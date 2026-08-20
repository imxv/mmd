import AppKit
import Testing
@testable import MMD

@MainActor
struct MarkdownRendererTests {
    @Test func rendersStructureLinksAndCode() throws {
        let source = """
        # 标题

        一段 **粗体** 和 [链接](https://example.com)。

        ## 代码

        ```swift
        let answer = 42
        ```

        | 名称 | 值 |
        | --- | --- |
        | A | B |
        """

        let result = try MarkdownRenderer.render(
            source: source,
            baseURL: nil,
            fontSize: 16,
            theme: .system
        )

        #expect(result.headings.map(\.title) == ["标题", "代码"])
        #expect(result.headings.map(\.level) == [1, 2])
        #expect(result.attributedString.string.contains("let answer = 42"))
        #expect(result.attributedString.string.contains("标题\n\n一段"))
        #expect(result.attributedString.string.contains("名称\n值\nA\nB"))

        let text = result.attributedString.string as NSString
        let linkRange = text.range(of: "链接")
        let link = result.attributedString.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL
        #expect(link?.absoluteString == "https://example.com")

        let codeRange = text.range(of: "let answer = 42")
        let codeFont = result.attributedString.attribute(.font, at: codeRange.location, effectiveRange: nil) as? NSFont
        #expect(codeFont?.isFixedPitch == true)

        let codeBackground = result.attributedString.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil)
        let codeParagraph = result.attributedString.attribute(
            .paragraphStyle,
            at: codeRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(codeBackground == nil)
        #expect(codeParagraph?.textBlocks.count == 1)
        #expect(codeParagraph?.textBlocks.first?.backgroundColor != nil)
        #expect(codeParagraph?.textBlocks.first?.contentWidth == 100)
        #expect(codeParagraph?.textBlocks.first?.contentWidthValueType == .percentageValueType)
        #expect(codeParagraph?.textBlocks.first?.width(for: .padding, edge: .minX) == 14)
        #expect(codeParagraph?.textBlocks.first?.width(for: .padding, edge: .maxX) == 14)
    }

    @Test func resolvesRelativeImageAndCreatesAttachment() throws {
        let baseURL = URL(fileURLWithPath: "/tmp/mmd-test", isDirectory: true)
        let result = try MarkdownRenderer.render(
            source: "![说明](images/demo.png)",
            baseURL: baseURL,
            fontSize: 16,
            theme: .paper
        )

        #expect(result.attributedString.string == "\u{FFFC}")
        let attachment = result.attributedString.attribute(.attachment, at: 0, effectiveRange: nil) as? MarkdownImageAttachment
        #expect(attachment?.sourceURL.path == "/tmp/mmd-test/images/demo.png")
    }

    @Test func rendersTableAsBorderedNativeGrid() throws {
        let result = try MarkdownRenderer.render(
            source: """
            | 名称 | 数量 |
            | :--- | ---: |
            | 苹果 | 2 |
            """,
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        var blocks: [NSTextTableBlock] = []
        result.attributedString.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: result.attributedString.length)
        ) { value, _, _ in
            guard let paragraph = value as? NSParagraphStyle else { return }
            blocks.append(contentsOf: paragraph.textBlocks.compactMap { $0 as? NSTextTableBlock })
        }

        #expect(blocks.count == 4)
        #expect(blocks.allSatisfy { $0.table.numberOfColumns == 2 })
        #expect(blocks.allSatisfy { !$0.table.collapsesBorders })
        #expect(blocks.allSatisfy { $0.width(for: .border, edge: .minX) == 1 })
        #expect(blocks.allSatisfy { $0.width(for: .border, edge: .maxY) == 1 })
        #expect(blocks.allSatisfy { $0.borderColor(for: .minX) != nil })
        #expect(blocks.allSatisfy { $0.borderColor(for: .maxY) != nil })
        #expect(blocks.filter { $0.startingColumn == 1 }.allSatisfy {
            $0.width(for: .border, edge: .maxX) == 1
        })
        #expect(blocks.filter { $0.startingColumn == 0 }.allSatisfy {
            $0.width(for: .border, edge: .maxX) == 0
        })
        #expect(blocks.filter { $0.startingRow == 1 }.allSatisfy {
            $0.width(for: .border, edge: .minY) == 1
        })
        #expect(blocks.filter { $0.startingRow == 0 }.allSatisfy {
            $0.width(for: .border, edge: .minY) == 0
        })
        #expect(blocks[0].backgroundColor != nil)

        let text = result.attributedString.string as NSString
        let quantityRange = text.range(of: "2")
        let quantityParagraph = result.attributedString.attribute(
            .paragraphStyle,
            at: quantityRange.location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(quantityParagraph?.alignment == .right)
    }

    @Test func thematicBreakUsesFullWidthNativeRule() throws {
        let result = try MarkdownRenderer.render(
            source: "上方\n\n---\n\n下方",
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        let blocks = textBlocks(in: result.attributedString)
        let divider = blocks.first { $0.width(for: .border, edge: .minY) == 1 }
        #expect(divider?.contentWidth == 100)
        #expect(divider?.contentWidthValueType == .percentageValueType)
        #expect(divider?.borderColor(for: .minY) != nil)
    }

    @Test func emphasisForcesVisibleObliqueness() throws {
        let result = try MarkdownRenderer.render(
            source: "普通 *中文斜体* 普通",
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        let range = (result.attributedString.string as NSString).range(of: "中文斜体")
        let obliqueness = result.attributedString.attribute(
            .obliqueness,
            at: range.location,
            effectiveRange: nil
        ) as? CGFloat
        #expect(obliqueness == 0.18)
    }

    @Test func multilineInlineCodeHasVerticalSeparation() throws {
        let result = try MarkdownRenderer.render(
            source: "`第一行`  \n`第二行`",
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        let paragraph = result.attributedString.attribute(
            .paragraphStyle,
            at: 0,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(paragraph?.lineSpacing ?? 0 >= 8)
        let backgrounds = backgroundRanges(in: result.attributedString)
        #expect(backgrounds.count == 2)
    }

    @Test func blockQuoteHasContinuousLeadingRule() throws {
        let result = try MarkdownRenderer.render(
            source: "> 第一段\n>\n> 第二段",
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        let blocks = textBlocks(in: result.attributedString)
        let quote = blocks.first { $0.width(for: .border, edge: .minX) == 3 }
        #expect(quote?.contentWidth == 100)
        #expect(quote?.borderColor(for: .minX) != nil)
    }

    @Test func unorderedAndNestedListsKeepVisibleHierarchy() throws {
        let result = try MarkdownRenderer.render(
            source: """
            - 一级项目
                - 二级项目
                    - 三级项目

            1. 外层步骤
                1. 嵌套步骤

            * 星号项目

            + 加号项目
            """,
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        #expect(result.attributedString.string.contains("•  一级项目"))
        #expect(result.attributedString.string.contains("◦  二级项目"))
        #expect(result.attributedString.string.contains("▪︎  三级项目"))
        #expect(result.attributedString.string.contains("1.  嵌套步骤"))
        #expect(result.attributedString.string.contains("•  星号项目"))
        #expect(result.attributedString.string.contains("•  加号项目"))

        let text = result.attributedString.string as NSString
        let firstParagraph = result.attributedString.attribute(
            .paragraphStyle,
            at: text.range(of: "一级项目").location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        let nestedParagraph = result.attributedString.attribute(
            .paragraphStyle,
            at: text.range(of: "二级项目").location,
            effectiveRange: nil
        ) as? NSParagraphStyle
        #expect(firstParagraph?.headIndent == 28)
        #expect(nestedParagraph?.headIndent == 52)
    }

    @Test func taskCheckboxesUseEqualSizedAttachments() throws {
        let result = try MarkdownRenderer.render(
            source: "- [x] 已完成\n- [ ] 未完成",
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        var attachments: [NSTextAttachment] = []
        result.attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: result.attributedString.length)
        ) { value, _, _ in
            if let attachment = value as? NSTextAttachment {
                attachments.append(attachment)
            }
        }
        #expect(attachments.count == 2)
        #expect(attachments[0].bounds.size == attachments[1].bounds.size)
        #expect(attachments[0].bounds.size == NSSize(width: 16, height: 16))
    }

    @Test func codeBlocksExposeLanguageAndPlainTextLabels() throws {
        let result = try MarkdownRenderer.render(
            source: """
            ```swift
            let value = 1
            ```

            ~~~json
            {"value": 1}
            ~~~

                indented code
            """,
            baseURL: nil,
            fontSize: 16,
            theme: .paper
        )

        #expect(result.attributedString.string.contains("SWIFT\nlet value = 1"))
        #expect(result.attributedString.string.contains("JSON\n{\"value\": 1}"))
        #expect(result.attributedString.string.contains("PLAIN TEXT\nindented code"))
    }

    @Test func usesTextKit2ForReaderView() {
        let textView = ReaderTextView.make()
        #expect(textView.textLayoutManager != nil)
    }

    @Test func paperThemeUpdatesSidebarAppearance() {
        let toc = TableOfContentsViewController()
        _ = toc.view
        toc.apply(theme: .paper)

        let scrollView = toc.view as? NSScrollView
        #expect(scrollView?.drawsBackground == true)
        #expect(scrollView?.backgroundColor.isEqual(ReaderThemeAppearance.sidebarBackground(for: .paper)) == true)
        #expect(toc.view.appearance?.name == .aqua)
    }

    @Test func welcomePageUsesReaderThemeAppearance() {
        let welcome = WelcomeWindowController(openAction: {}, openURLs: { _ in })

        welcome.apply(theme: .paper)
        #expect(welcome.window?.appearance?.name == .aqua)
        #expect(welcome.window?.backgroundColor.isEqual(
            ReaderThemeAppearance.readerBackground(for: .paper)
        ) == true)

        welcome.apply(theme: .system)
        #expect(welcome.window?.appearance == nil)
        #expect(welcome.window?.backgroundColor.isEqual(
            ReaderThemeAppearance.readerBackground(for: .system)
        ) == true)
    }

    @Test func sidebarCanCollapseAndStaysCollapsedAcrossThemeChanges() {
        let preferences = ReaderPreferences.shared
        let originalTheme = preferences.theme
        defer { preferences.theme = originalTheme }

        let reader = ReaderViewController(
            source: "# 第一章\n\n正文\n\n## 第二章\n\n正文",
            baseURL: nil
        )
        _ = reader.view
        #expect(reader.sidebarBehavior == .default)
        #expect(reader.isSidebarCollapsed == false)

        reader.toggleSidebar(nil)
        #expect(reader.isSidebarCollapsed == true)

        reader.togglePaperTheme(nil)
        #expect(reader.isSidebarCollapsed == true)

        let accessory = reader.makeSidebarTitlebarAccessory()
        let button = accessory.view as? NSButton
        #expect(accessory.layoutAttribute == .left)
        #expect(button?.target === reader)
        #expect(button?.action == #selector(ReaderViewController.toggleSidebar(_:)))
        #expect(button?.isEnabled == true)
    }

    private func textBlocks(in string: NSAttributedString) -> [NSTextBlock] {
        var blocks: [NSTextBlock] = []
        string.enumerateAttribute(
            .paragraphStyle,
            in: NSRange(location: 0, length: string.length)
        ) { value, _, _ in
            guard let paragraph = value as? NSParagraphStyle else { return }
            blocks.append(contentsOf: paragraph.textBlocks)
        }
        return blocks
    }

    private func backgroundRanges(in string: NSAttributedString) -> [NSRange] {
        var ranges: [NSRange] = []
        string.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: string.length)
        ) { value, range, _ in
            if value != nil { ranges.append(range) }
        }
        return ranges
    }
}
