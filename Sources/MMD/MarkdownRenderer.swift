import AppKit
import ImageIO
import Markdown

struct Heading: Equatable {
    let title: String
    let level: Int
    let range: NSRange
}

struct RemoteImageRequest {
    let url: URL
    let attachment: MarkdownImageAttachment
}

struct RenderedDocument {
    let attributedString: NSAttributedString
    let headings: [Heading]
    let remoteImages: [RemoteImageRequest]
}

private extension NSAttributedString.Key {
    static let mmdHeadingLevel = NSAttributedString.Key("com.sunmozong.mmd.heading-level")
    static let mmdInlineCode = NSAttributedString.Key("com.sunmozong.mmd.inline-code")
}

@MainActor
enum MarkdownRenderer {
    static func render(
        source: String,
        baseURL: URL?,
        fontSize: CGFloat,
        theme: ReaderTheme
    ) throws -> RenderedDocument {
        let document = Document(parsing: source)
        var renderer = MarkdownAttributedRenderer(
            baseURL: baseURL,
            fontSize: fontSize,
            palette: Palette(theme: theme)
        )
        let output = renderer.visit(document)
        return RenderedDocument(
            attributedString: output,
            headings: extractHeadings(from: output),
            remoteImages: renderer.remoteImages
        )
    }

    private static func extractHeadings(from output: NSAttributedString) -> [Heading] {
        let wholeRange = NSRange(location: 0, length: output.length)
        var headings: [Heading] = []
        output.enumerateAttribute(.mmdHeadingLevel, in: wholeRange) { value, range, _ in
            guard let level = value as? Int else { return }
            let title = (output.string as NSString)
                .substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            headings.append(Heading(title: title, level: level, range: range))
        }
        return headings
    }
}

@MainActor
private struct MarkdownAttributedRenderer: @preconcurrency MarkupVisitor {
    typealias Result = NSAttributedString

    let baseURL: URL?
    let fontSize: CGFloat
    let palette: Palette
    var remoteImages: [RemoteImageRequest] = []

    mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
        combinedChildren(of: markup)
    }

    mutating func visitDocument(_ document: Document) -> NSAttributedString {
        joinedChildren(of: document, separator: "\n\n")
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: paragraph))
        let paragraphStyle = bodyParagraphStyle()
        var hasInlineCode = false
        result.enumerateAttribute(.mmdInlineCode, in: result.wholeRange) { value, _, stop in
            if value != nil {
                hasInlineCode = true
                stop.pointee = true
            }
        }
        if result.string.contains("\n"), hasInlineCode {
            paragraphStyle.lineSpacing = max(8, fontSize * 0.5)
        }
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: result.wholeRange)
        return result
    }

    mutating func visitHeading(_ heading: Markdown.Heading) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: heading))
        let scale: CGFloat = switch heading.level {
        case 1: 1.9
        case 2: 1.55
        case 3: 1.3
        case 4: 1.15
        default: 1.05
        }
        let font = NSFont.systemFont(ofSize: fontSize * scale, weight: heading.level <= 2 ? .bold : .semibold)
        let paragraph = bodyParagraphStyle()
        paragraph.paragraphSpacingBefore = heading.level == 1 ? fontSize * 0.4 : fontSize * 0.8
        paragraph.paragraphSpacing = fontSize * 0.35
        paragraph.lineSpacing = fontSize * 0.12
        result.addAttributes(
            [
                .font: font,
                .foregroundColor: palette.text,
                .paragraphStyle: paragraph,
                .mmdHeadingLevel: heading.level,
            ],
            range: result.wholeRange
        )
        return result
    }

    mutating func visitText(_ text: Markdown.Text) -> NSAttributedString {
        plain(text.string)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
        plain(" ")
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
        plain("\n")
    }

    mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: strong))
        applyFontTraits(.boldFontMask, to: result)
        return result
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: emphasis))
        applyFontTraits(.italicFontMask, to: result)
        result.addAttribute(.obliqueness, value: 0.18, range: result.wholeRange)
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: strikethrough))
        result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: result.wholeRange)
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSAttributedString {
        NSAttributedString(
            string: inlineCode.code,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize * 0.92, weight: .regular),
                .foregroundColor: palette.codeText,
                .backgroundColor: palette.inlineCodeBackground,
                .mmdInlineCode: true,
            ]
        )
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSAttributedString {
        let paragraph = bodyParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 0

        let block = NSTextBlock()
        block.backgroundColor = palette.codeBackground
        block.setContentWidth(100, type: .percentageValueType)
        block.setWidth(14, type: .absoluteValueType, for: .padding, edge: .minX)
        block.setWidth(14, type: .absoluteValueType, for: .padding, edge: .maxX)
        block.setWidth(9, type: .absoluteValueType, for: .padding, edge: .minY)
        block.setWidth(9, type: .absoluteValueType, for: .padding, edge: .maxY)
        paragraph.textBlocks = [block]

        let language = codeBlock.language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let label = language?.isEmpty == false ? language! : "PLAIN TEXT"
        let result = NSMutableAttributedString(
            string: "\(label)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: max(10, fontSize * 0.68), weight: .semibold),
                .foregroundColor: palette.secondaryText,
                .kern: 0.5,
                .paragraphStyle: paragraph,
            ]
        )
        result.append(
            NSAttributedString(
                string: codeBlock.code.trimmingCharacters(in: .newlines),
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: fontSize * 0.9, weight: .regular),
                    .foregroundColor: palette.codeText,
                    .paragraphStyle: paragraph,
                ]
            )
        )
        return result
    }

    mutating func visitLink(_ link: Markdown.Link) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: combinedChildren(of: link))
        guard let destination = link.destination,
              let url = resolveURL(destination)
        else { return result }
        result.addAttributes(
            [
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ],
            range: result.wholeRange
        )
        return result
    }

    mutating func visitImage(_ image: Markdown.Image) -> NSAttributedString {
        let altText = combinedChildren(of: image).string
        guard let source = image.source, let url = resolveURL(source) else {
            return plain(altText)
        }

        let attachment = MarkdownImageAttachment(sourceURL: url)
        if url.isFileURL, let localImage = ImageDownsampler.image(at: url) {
            attachment.setReaderImage(localImage)
        } else {
            attachment.image = NSImage(systemSymbolName: "photo", accessibilityDescription: altText.isEmpty ? "图片" : altText)
            attachment.bounds = NSRect(x: 0, y: -4, width: 44, height: 44)
            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                remoteImages.append(RemoteImageRequest(url: url, attachment: attachment))
            }
        }
        return NSAttributedString(attachment: attachment)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: joinedChildren(of: blockQuote, separator: "\n"))
        let quoteBlock = NSTextBlock()
        quoteBlock.setContentWidth(100, type: .percentageValueType)
        quoteBlock.setBorderColor(palette.quoteBorder, for: .minX)
        quoteBlock.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        quoteBlock.setWidth(12, type: .absoluteValueType, for: .padding, edge: .minX)
        quoteBlock.setWidth(6, type: .absoluteValueType, for: .padding, edge: .minY)
        quoteBlock.setWidth(6, type: .absoluteValueType, for: .padding, edge: .maxY)

        var paragraphRanges: [(NSParagraphStyle?, NSRange)] = []
        result.enumerateAttribute(.paragraphStyle, in: result.wholeRange) { value, range, _ in
            paragraphRanges.append((value as? NSParagraphStyle, range))
        }
        for (existing, range) in paragraphRanges {
            let paragraph = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? bodyParagraphStyle()
            paragraph.textBlocks = [quoteBlock] + paragraph.textBlocks
            result.addAttributes(
                [
                    .foregroundColor: palette.secondaryText,
                    .paragraphStyle: paragraph,
                ],
                range: range
            )
        }
        return result
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
        renderList(unorderedList, orderedStart: nil, depth: 0)
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
        renderList(orderedList, orderedStart: Int(orderedList.startIndex), depth: 0)
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
        joinedChildren(of: listItem, separator: "\n")
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSAttributedString {
        let paragraph = bodyParagraphStyle()
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = fontSize * 0.7

        let divider = NSTextBlock()
        divider.setContentWidth(100, type: .percentageValueType)
        divider.setBorderColor(palette.divider, for: .minY)
        divider.setWidth(1, type: .absoluteValueType, for: .border, edge: .minY)
        divider.setWidth(5, type: .absoluteValueType, for: .padding, edge: .minY)
        divider.setWidth(5, type: .absoluteValueType, for: .padding, edge: .maxY)
        paragraph.textBlocks = [divider]
        return NSAttributedString(
            string: " ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 1),
                .foregroundColor: NSColor.clear,
                .paragraphStyle: paragraph,
            ]
        )
    }

    mutating func visitTable(_ table: Table) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyRows = Array(table.body.rows)
        let columnCount = max(1, table.maxColumnCount)
        let rowCount = bodyRows.count + 1
        let nativeTable = NSTextTable()
        nativeTable.numberOfColumns = columnCount
        // Collapsed borders are shared by adjacent cells. TextKit 2 can lay those
        // cells out in separate viewport fragments while scrolling, which makes
        // a shared edge briefly disappear until another redraw is triggered.
        // Keep every grid edge owned by exactly one cell instead.
        nativeTable.collapsesBorders = false
        nativeTable.hidesEmptyCells = false
        nativeTable.layoutAlgorithm = .fixedLayoutAlgorithm
        nativeTable.setContentWidth(100, type: .percentageValueType)

        appendTableRow(
            table.head,
            rowIndex: 0,
            isHeader: true,
            table: nativeTable,
            alignments: table.columnAlignments,
            rowCount: rowCount,
            columnCount: columnCount,
            to: result
        )
        for (offset, row) in bodyRows.enumerated() {
            appendTableRow(
                row,
                rowIndex: offset + 1,
                isHeader: false,
                table: nativeTable,
                alignments: table.columnAlignments,
                rowCount: rowCount,
                columnCount: columnCount,
                to: result
            )
        }
        return result
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> NSAttributedString {
        joinedChildren(of: tableHead, separator: "\t")
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> NSAttributedString {
        joinedChildren(of: tableBody, separator: "\n")
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> NSAttributedString {
        joinedChildren(of: tableRow, separator: "\t")
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> NSAttributedString {
        combinedChildren(of: tableCell)
    }

    private mutating func appendTableRow(
        _ row: Markup,
        rowIndex: Int,
        isHeader: Bool,
        table: NSTextTable,
        alignments: [Table.ColumnAlignment?],
        rowCount: Int,
        columnCount: Int,
        to result: NSMutableAttributedString
    ) {
        for (columnIndex, child) in row.children.enumerated() {
            guard let cell = child as? Table.Cell else { continue }
            if result.length > 0 {
                result.append(plain("\n"))
            }

            let content = NSMutableAttributedString(attributedString: visit(cell))
            if content.length == 0 {
                content.append(plain("\u{200B}"))
            }
            if isHeader {
                applyFontTraits(.boldFontMask, to: content)
            }

            let block = NSTextTableBlock(
                table: table,
                startingRow: rowIndex,
                rowSpan: 1,
                startingColumn: columnIndex,
                columnSpan: 1
            )
            block.backgroundColor = if isHeader {
                palette.tableHeaderBackground
            } else if rowIndex.isMultiple(of: 2) {
                palette.tableAlternateRowBackground
            } else {
                nil
            }
            // Each physical line has one stable owner: all cells own their left
            // and top edges; only the final column/row owns the outer right/bottom.
            // This avoids both overlapping 2 pt seams and fragment-dependent edges.
            block.setBorderColor(palette.tableBorder, for: .minX)
            block.setWidth(1, type: .absoluteValueType, for: .border, edge: .minX)
            block.setBorderColor(palette.tableBorder, for: .maxY)
            block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
            if columnIndex == columnCount - 1 {
                block.setBorderColor(palette.tableBorder, for: .maxX)
                block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxX)
            }
            if rowIndex == rowCount - 1 {
                block.setBorderColor(palette.tableBorder, for: .minY)
                block.setWidth(1, type: .absoluteValueType, for: .border, edge: .minY)
            }
            block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
            block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .maxX)
            block.setWidth(7, type: .absoluteValueType, for: .padding, edge: .minY)
            block.setWidth(7, type: .absoluteValueType, for: .padding, edge: .maxY)

            let paragraph = bodyParagraphStyle()
            paragraph.paragraphSpacing = 0
            paragraph.lineSpacing = max(2, fontSize * 0.18)
            if alignments.indices.contains(columnIndex) {
                paragraph.alignment = switch alignments[columnIndex] {
                case .left, nil: .left
                case .center: .center
                case .right: .right
                }
            }
            paragraph.textBlocks = [block]
            content.addAttribute(.paragraphStyle, value: paragraph, range: content.wholeRange)
            result.append(content)
        }
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> NSAttributedString {
        mutedCode(html.rawHTML)
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
        mutedCode(inlineHTML.rawHTML)
    }

    mutating func visitCustomInline(_ customInline: CustomInline) -> NSAttributedString {
        plain(customInline.plainText)
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> NSAttributedString {
        plain(symbolLink.plainText)
    }

    private mutating func renderList(_ list: Markup, orderedStart: Int?, depth: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (offset, child) in list.children.enumerated() {
            guard let item = child as? ListItem else { continue }
            if result.length > 0 { result.append(plain("\n")) }

            let itemContent = NSMutableAttributedString()
            if let checkbox = item.checkbox {
                itemContent.append(taskMarker(checked: checkbox == .checked))
            } else if let orderedStart {
                itemContent.append(plain("\(orderedStart + offset).  "))
            } else {
                let bullets = ["•", "◦", "▪︎"]
                itemContent.append(plain("\(bullets[depth % bullets.count])  "))
            }

            var nestedLists: [NSAttributedString] = []
            var hasPrimaryContent = false
            for itemChild in item.children {
                if let unordered = itemChild as? UnorderedList {
                    nestedLists.append(renderList(unordered, orderedStart: nil, depth: depth + 1))
                } else if let ordered = itemChild as? OrderedList {
                    nestedLists.append(
                        renderList(ordered, orderedStart: Int(ordered.startIndex), depth: depth + 1)
                    )
                } else {
                    if hasPrimaryContent { itemContent.append(plain("\n")) }
                    itemContent.append(visit(itemChild))
                    hasPrimaryContent = true
                }
            }

            let paragraph = bodyParagraphStyle()
            let baseIndent = CGFloat(depth) * 24
            paragraph.firstLineHeadIndent = 8 + baseIndent
            paragraph.headIndent = 28 + baseIndent
            paragraph.paragraphSpacing = 5
            itemContent.addAttribute(.paragraphStyle, value: paragraph, range: itemContent.wholeRange)
            result.append(itemContent)

            for nested in nestedLists {
                result.append(plain("\n"))
                result.append(nested)
            }
        }
        return result
    }

    private func taskMarker(checked: Bool) -> NSAttributedString {
        let attachment = NSTextAttachment()
        let symbolName = checked ? "checkmark.square.fill" : "square"
        let configuration = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        attachment.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: checked ? "已完成" : "未完成"
        )?.withSymbolConfiguration(configuration)
        attachment.bounds = NSRect(x: 0, y: -2, width: fontSize, height: fontSize)

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(plain("  "))
        return result
    }

    private mutating func combinedChildren(of markup: Markup) -> NSAttributedString {
        joinedChildren(of: markup, separator: "")
    }

    private mutating func joinedChildren(of markup: Markup, separator: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            if result.length > 0, !separator.isEmpty {
                result.append(plain(separator))
            }
            result.append(visit(child))
        }
        return result
    }

    private func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: palette.text,
            ]
        )
    }

    private func mutedCode(_ string: String) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize * 0.88, weight: .regular),
                .foregroundColor: palette.secondaryText,
                .backgroundColor: palette.inlineCodeBackground,
            ]
        )
    }

    private func bodyParagraphStyle() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(3, fontSize * 0.25)
        paragraph.paragraphSpacing = max(7, fontSize * 0.45)
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func applyFontTraits(_ traits: NSFontTraitMask, to output: NSMutableAttributedString) {
        output.enumerateAttribute(.font, in: output.wholeRange) { value, range, _ in
            let font = value as? NSFont ?? NSFont.systemFont(ofSize: fontSize)
            output.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: traits), range: range)
        }
    }

    private func resolveURL(_ value: String) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }
        if let baseURL {
            if let relative = URL(string: value, relativeTo: baseURL)?.absoluteURL {
                return relative
            }
            return baseURL.appendingPathComponent(value)
        }
        return URL(string: value)
    }
}

private extension NSAttributedString {
    var wholeRange: NSRange { NSRange(location: 0, length: length) }
}

final class MarkdownImageAttachment: NSTextAttachment {
    let sourceURL: URL

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        guard let url = coder.decodeObject(of: NSURL.self, forKey: "sourceURL") as URL? else { return nil }
        sourceURL = url
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(sourceURL as NSURL, forKey: "sourceURL")
    }

    func setReaderImage(_ image: NSImage) {
        self.image = image
        let maxWidth: CGFloat = 680
        let maxHeight: CGFloat = 520
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let scale = min(1, maxWidth / size.width, maxHeight / size.height)
        bounds = NSRect(x: 0, y: -5, width: size.width * scale, height: size.height * scale)
    }
}

enum ImageDownsampler {
    static func image(at url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(from: source)
    }

    static func image(data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return thumbnail(from: source)
    }

    private static func thumbnail(from source: CGImageSource) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_600,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

private struct Palette {
    let text: NSColor
    let secondaryText: NSColor
    let codeText: NSColor
    let codeBackground: NSColor
    let inlineCodeBackground: NSColor
    let tableHeaderBackground: NSColor
    let tableAlternateRowBackground: NSColor
    let tableBorder: NSColor
    let quoteBorder: NSColor
    let divider: NSColor

    init(theme: ReaderTheme) {
        switch theme {
        case .system:
            text = .labelColor
            secondaryText = .secondaryLabelColor
            codeText = .labelColor
            codeBackground = .quaternaryLabelColor.withAlphaComponent(0.14)
            inlineCodeBackground = .quaternaryLabelColor.withAlphaComponent(0.12)
            tableHeaderBackground = .quaternaryLabelColor.withAlphaComponent(0.10)
            tableAlternateRowBackground = .quaternaryLabelColor.withAlphaComponent(0.045)
            tableBorder = .separatorColor
            quoteBorder = .tertiaryLabelColor
            divider = .separatorColor
        case .paper:
            text = NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.12, alpha: 1)
            secondaryText = NSColor(calibratedRed: 0.42, green: 0.38, blue: 0.30, alpha: 1)
            codeText = NSColor(calibratedRed: 0.23, green: 0.20, blue: 0.15, alpha: 1)
            codeBackground = NSColor(calibratedRed: 0.89, green: 0.86, blue: 0.76, alpha: 1)
            inlineCodeBackground = NSColor(calibratedRed: 0.90, green: 0.87, blue: 0.79, alpha: 1)
            tableHeaderBackground = NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.79, alpha: 1)
            tableAlternateRowBackground = NSColor(calibratedRed: 0.945, green: 0.925, blue: 0.865, alpha: 1)
            tableBorder = NSColor(calibratedRed: 0.72, green: 0.68, blue: 0.58, alpha: 1)
            quoteBorder = NSColor(calibratedRed: 0.63, green: 0.57, blue: 0.45, alpha: 1)
            divider = NSColor(calibratedRed: 0.70, green: 0.65, blue: 0.54, alpha: 1)
        }
    }
}
