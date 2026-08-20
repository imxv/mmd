import AppKit

@MainActor
final class TableOfContentsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onSelectHeading: ((Heading) -> Void)?

    private let tableView = NSTableView()
    private var headings: [Heading] = []
    private var theme: ReaderTheme = .system

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("heading"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.backgroundColor = ReaderThemeAppearance.sidebarBackground(for: theme)
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        view = scrollView
        apply(theme: theme)
    }

    func update(headings: [Heading]) {
        self.headings = headings
        tableView.reloadData()
    }

    func apply(theme: ReaderTheme) {
        self.theme = theme
        _ = view

        let background = ReaderThemeAppearance.sidebarBackground(for: theme)
        let appearance = ReaderThemeAppearance.windowAppearance(for: theme)
        view.appearance = appearance
        view.wantsLayer = true
        view.layer?.cornerRadius = 0
        view.layer?.backgroundColor = background.cgColor
        if let scrollView = view as? NSScrollView {
            scrollView.drawsBackground = true
            scrollView.backgroundColor = background
        }
        tableView.backgroundColor = background
        tableView.reloadData()
        view.needsDisplay = true
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        headings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TOCHeadingCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TOCCellView ?? TOCCellView()
        cell.identifier = identifier

        let label: NSTextField
        if let existing = cell.textField {
            label = existing
        } else {
            label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.textField = label
            cell.addSubview(label)
            cell.leadingConstraint = label.leadingAnchor.constraint(equalTo: cell.leadingAnchor)
            NSLayoutConstraint.activate([
                cell.leadingConstraint!,
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        let heading = headings[row]
        label.stringValue = heading.title
        label.font = heading.level == 1 ? .systemFont(ofSize: 13, weight: .semibold) : .systemFont(ofSize: 12.5)
        label.textColor = heading.level <= 2 ? .labelColor : .secondaryLabelColor
        label.alignment = .left
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cell.leadingConstraint?.constant = CGFloat(max(0, heading.level - 1)) * 10
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard headings.indices.contains(row) else { return }
        onSelectHeading?(headings[row])
    }
}

private final class TOCCellView: NSTableCellView {
    var leadingConstraint: NSLayoutConstraint?
}
