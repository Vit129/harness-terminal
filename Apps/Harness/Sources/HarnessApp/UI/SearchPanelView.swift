import AppKit
import HarnessCore

// MARK: - Model

@MainActor
struct SearchResult {
    let filePath: String
    let fileName: String
    let isDirectory: Bool
    let lineNumber: Int?      // nil for filename-only matches
    let snippet: String?      // line content for content matches
    let matchRange: NSRange?  // range within snippet for highlighting
}

// MARK: - SearchPanelView

/// Sidebar panel for Find & Search: supports file-name fuzzy search and
/// content grep with regex/case-sensitive toggles.
@MainActor
final class SearchPanelView: NSView, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    enum SearchMode { case fileName, content }

    // MARK: UI

    private let searchField = NSTextField()
    private let searchIcon = NSImageView()
    private let searchContainer = NSView()
    private let modeToggle = NSSegmentedControl(labels: ["Name", "Content"], trackingMode: .selectOne, target: nil, action: nil)
    private let regexButton = NSButton(title: ".*", target: nil, action: nil)
    private let caseButton = NSButton(title: "Aa", target: nil, action: nil)
    private let resultTable = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")

    // MARK: State

    private var results: [SearchResult] = []
    private var searchMode: SearchMode = .content
    private var useRegex = false
    private var caseSensitive = false
    private var rootPath: String = NSHomeDirectory()
    private var searchTask: Process?
    private var debounceItem: DispatchWorkItem?

    /// Called when user clicks a file result — open file at path (and optionally line).
    var onOpenFile: ((String, Int?) -> Void)?

    // MARK: Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Public

    func updateRoot(path: String) {
        guard path != rootPath else { return }
        rootPath = path
        runSearch()
    }

    // MARK: Setup

    private func setup() {
        setupSearchField()
        setupToggles()
        setupResultTable()
        setupStatusLabel()
    }

    private func setupSearchField() {
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 6
        searchContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        addSubview(searchContainer)

        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = .secondaryLabelColor
        searchContainer.addSubview(searchIcon)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.placeholderString = "Search files…"
        searchField.font = .systemFont(ofSize: 12)
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            searchContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            searchContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            searchContainer.heightAnchor.constraint(equalToConstant: 26),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 6),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 14),
            searchIcon.heightAnchor.constraint(equalToConstant: 14),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 4),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -6),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
        ])
    }

    private func setupToggles() {
        modeToggle.translatesAutoresizingMaskIntoConstraints = false
        modeToggle.selectedSegment = 1  // default: content search
        modeToggle.segmentStyle = .rounded
        modeToggle.controlSize = .small
        modeToggle.target = self
        modeToggle.action = #selector(modeChanged)
        addSubview(modeToggle)

        for btn in [regexButton, caseButton] {
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.setButtonType(.toggle)
            btn.bezelStyle = .inline
            btn.controlSize = .small
            btn.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            btn.target = self
        }
        regexButton.action = #selector(regexToggled)
        caseButton.action = #selector(caseToggled)
        regexButton.toolTip = "Use Regular Expression"
        caseButton.toolTip = "Match Case"
        addSubview(regexButton)
        addSubview(caseButton)

        NSLayoutConstraint.activate([
            modeToggle.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 6),
            modeToggle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),

            regexButton.centerYAnchor.constraint(equalTo: modeToggle.centerYAnchor),
            regexButton.trailingAnchor.constraint(equalTo: caseButton.leadingAnchor, constant: -4),

            caseButton.centerYAnchor.constraint(equalTo: modeToggle.centerYAnchor),
            caseButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }

    private func setupResultTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.resizingMask = .autoresizingMask
        resultTable.addTableColumn(column)
        resultTable.headerView = nil
        resultTable.dataSource = self
        resultTable.delegate = self
        resultTable.rowHeight = 36
        resultTable.style = .plain
        resultTable.backgroundColor = .clear
        resultTable.intercellSpacing = NSSize(width: 0, height: 1)
        resultTable.target = self
        resultTable.doubleAction = #selector(resultDoubleClicked)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = resultTable
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: modeToggle.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 10)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.alignment = .center
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    // MARK: Actions

    @objc private func modeChanged() {
        searchMode = modeToggle.selectedSegment == 0 ? .fileName : .content
        searchField.placeholderString = searchMode == .fileName ? "File name…" : "Search in files…"
        runSearch()
    }

    @objc private func regexToggled() {
        useRegex = regexButton.state == .on
        runSearch()
    }

    @objc private func caseToggled() {
        caseSensitive = caseButton.state == .on
        runSearch()
    }

    @objc private func resultDoubleClicked() {
        let row = resultTable.clickedRow
        guard row >= 0, row < results.count else { return }
        let r = results[row]
        guard !r.isDirectory else { return }
        onOpenFile?(r.filePath, r.lineNumber)
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.runSearch()
        }
        debounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: item)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            // Enter: open first result
            if !results.isEmpty {
                let r = results[0]
                if !r.isDirectory {
                    onOpenFile?(r.filePath, r.lineNumber)
                }
            }
            return true
        }
        return false
    }

    // MARK: Search Logic

    private func runSearch() {
        searchTask?.terminate()
        searchTask = nil

        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            statusLabel.stringValue = ""
            resultTable.reloadData()
            return
        }

        switch searchMode {
        case .fileName:
            runFileNameSearch(query: query)
        case .content:
            runContentSearch(query: query)
        }
    }

    // MARK: File Name Search (fuzzy)

    private func runFileNameSearch(query: String) {
        let root = rootPath
        let regex = useRegex
        let caseSens = caseSensitive

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var matches: [SearchResult] = []
            let rootURL = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL
            let rootPath = rootURL.path
            let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let url = enumerator?.nextObject() as? URL {
                let standardizedURL = url.standardizedFileURL
                let name = standardizedURL.lastPathComponent
                let isDirectory = (try? standardizedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDirectory, Self.excludedSearchDirectoryNames.contains(name) {
                    enumerator?.skipDescendants()
                    continue
                }

                let relativePath = standardizedURL.path.hasPrefix(rootPrefix)
                    ? String(standardizedURL.path.dropFirst(rootPrefix.count))
                    : standardizedURL.path

                let matched: Bool
                if regex {
                    matched = (try? NSRegularExpression(pattern: query, options: caseSens ? [] : .caseInsensitive))
                        .map {
                            $0.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil ||
                                $0.firstMatch(in: relativePath, range: NSRange(relativePath.startIndex..., in: relativePath)) != nil
                        } ?? false
                } else {
                    matched = Self.spotlightMatch(query: query, name: name, relativePath: relativePath, caseSensitive: caseSens)
                }

                if matched {
                    matches.append(SearchResult(
                        filePath: standardizedURL.path,
                        fileName: relativePath,
                        isDirectory: isDirectory,
                        lineNumber: nil,
                        snippet: nil,
                        matchRange: nil
                    ))
                }
                if matches.count >= 200 { break }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.results = matches
                self.statusLabel.stringValue = "\(matches.count) item\(matches.count == 1 ? "" : "s")"
                self.resultTable.reloadData()
            }
        }
    }

    nonisolated private static let excludedSearchDirectoryNames: Set<String> = [
        ".git",
        "node_modules",
        ".build",
        "DerivedData",
    ]

    /// Spotlight-style name search over basename and project-relative path.
    nonisolated static func spotlightMatch(
        query: String,
        name: String,
        relativePath: String,
        caseSensitive: Bool
    ) -> Bool {
        let matcher = SpotlightNameMatcher(query: query, caseSensitive: caseSensitive)
        return matcher.matches(name: name, relativePath: relativePath)
    }

    nonisolated private struct SpotlightNameMatcher {
        let wholeQuery: String
        let tokens: [String]
        let caseSensitive: Bool

        init(query: String, caseSensitive: Bool) {
            self.caseSensitive = caseSensitive
            wholeQuery = Self.normalized(query, caseSensitive: caseSensitive)
            tokens = wholeQuery
                .split(whereSeparator: Self.isTokenSeparator)
                .map(String.init)
                .filter { !$0.isEmpty }
        }

        func matches(name: String, relativePath: String) -> Bool {
            let haystacks = [
                Self.normalized(name, caseSensitive: caseSensitive),
                Self.normalized(relativePath, caseSensitive: caseSensitive),
            ]
            if !wholeQuery.isEmpty, haystacks.contains(where: { $0.contains(wholeQuery) }) {
                return true
            }
            guard !tokens.isEmpty else { return false }
            return tokens.allSatisfy { token in
                haystacks.contains { $0.contains(token) }
            }
        }

        private static func normalized(_ value: String, caseSensitive: Bool) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if caseSensitive { return trimmed }
            return trimmed
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
        }

        private static func isTokenSeparator(_ character: Character) -> Bool {
            character.isWhitespace || character == "/" || character == "." || character == "-" || character == "_"
        }
    }

    // MARK: Content Search (grep)

    private func runContentSearch(query: String) {
        let root = rootPath
        let regex = useRegex
        let caseSens = caseSensitive

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
            var args = ["-rn", "--include=*"]
            if !caseSens { args.append("-i") }
            if !regex { args.append("-F") }  // fixed string (literal)
            args.append("--")
            args.append(query)
            args.append(root)
            proc.arguments = args
            proc.currentDirectoryURL = URL(fileURLWithPath: root)

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            DispatchQueue.main.async { self?.searchTask = proc }

            do { try proc.run() } catch { return }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else { return }

            var matches: [SearchResult] = []
            let lines = output.components(separatedBy: "\n")
            for line in lines.prefix(500) {
                // Format: /path/to/file:linenum:content
                guard let firstColon = line.firstIndex(of: ":") else { continue }
                let filePath = String(line[..<firstColon])
                let rest = line[line.index(after: firstColon)...]
                guard let secondColon = rest.firstIndex(of: ":") else { continue }
                let lineNumStr = String(rest[..<secondColon])
                guard let lineNum = Int(lineNumStr) else { continue }
                let snippet = String(rest[rest.index(after: secondColon)...])
                    .trimmingCharacters(in: .whitespaces)

                let relativePath = filePath.hasPrefix(root)
                    ? String(filePath.dropFirst(root.count + 1))
                    : filePath

                matches.append(SearchResult(
                    filePath: filePath,
                    fileName: relativePath,
                    isDirectory: false,
                    lineNumber: lineNum,
                    snippet: String(snippet.prefix(200)),
                    matchRange: nil
                ))
                if matches.count >= 200 { break }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.results = matches
                self.statusLabel.stringValue = "\(matches.count) result\(matches.count == 1 ? "" : "s")"
                self.resultTable.reloadData()
            }
        }
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    // MARK: NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < results.count else { return nil }
        let r = results[row]

        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("SearchCell"), owner: nil) as? SearchResultCellView
            ?? SearchResultCellView()
        cell.identifier = NSUserInterfaceItemIdentifier("SearchCell")
        cell.configure(result: r)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = resultTable.selectedRow
        guard row >= 0, row < results.count else { return }
        let r = results[row]
        guard !r.isDirectory else { return }
        onOpenFile?(r.filePath, r.lineNumber)
    }
}

// MARK: - Result Cell

@MainActor
private final class SearchResultCellView: NSTableCellView {
    private let fileLabel = NSTextField(labelWithString: "")
    private let snippetLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupLabels() {
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        fileLabel.font = .systemFont(ofSize: 11, weight: .medium)
        fileLabel.textColor = .labelColor
        fileLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(fileLabel)

        snippetLabel.translatesAutoresizingMaskIntoConstraints = false
        snippetLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        snippetLabel.textColor = .secondaryLabelColor
        snippetLabel.lineBreakMode = .byTruncatingTail
        addSubview(snippetLabel)

        NSLayoutConstraint.activate([
            fileLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            fileLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            fileLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),

            snippetLabel.topAnchor.constraint(equalTo: fileLabel.bottomAnchor, constant: 1),
            snippetLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            snippetLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
    }

    func configure(result: SearchResult) {
        if let lineNum = result.lineNumber {
            fileLabel.stringValue = "\(result.fileName):\(lineNum)"
        } else {
            fileLabel.stringValue = result.fileName
        }
        snippetLabel.stringValue = result.snippet ?? (result.isDirectory ? "Folder" : "")
        snippetLabel.isHidden = result.snippet == nil && !result.isDirectory
    }
}
