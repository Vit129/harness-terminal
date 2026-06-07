import AppKit
import HarnessCore

/// Simple tab strip for the file editor panel. Shows open file tabs with close buttons.
@MainActor
final class FileEditorTabBarView: NSView {
    var onSelect: ((FileTabID) -> Void)?
    var onClose: ((FileTabID) -> Void)?

    private let scrollView = NSScrollView()
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.borderColor = HarnessDesign.chrome.border.cgColor
        layer?.borderWidth = 0
        // Bottom border only
        let border = CALayer()
        border.backgroundColor = HarnessDesign.chrome.border.cgColor
        border.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        layer?.addSublayer(border)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        addSubview(scrollView)

        stack.orientation = .horizontal
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func reload(tabs: [FileTabManager.FileTab], activeID: FileTabID?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tab in tabs {
            let pill = FileTabPill(id: tab.id, title: tab.title, isActive: tab.id == activeID)
            pill.onSelect = { [weak self] id in self?.onSelect?(id) }
            pill.onClose = { [weak self] id in self?.onClose?(id) }
            stack.addArrangedSubview(pill)
        }
    }
}

@MainActor
private final class FileTabPill: NSView {
    let id: FileTabID
    var onSelect: ((FileTabID) -> Void)?
    var onClose: ((FileTabID) -> Void)?
    private weak var closeButton: NSButton?

    init(id: FileTabID, title: String, isActive: Bool) {
        self.id = id
        super.init(frame: .zero)
        wantsLayer = true
        let c = HarnessDesign.chrome
        layer?.cornerRadius = 5
        layer?.backgroundColor = isActive ? c.rowSelectedFill.cgColor : NSColor.white.withAlphaComponent(0.05).cgColor
        if isActive { layer?.borderColor = c.accent.withAlphaComponent(0.5).cgColor; layer?.borderWidth = 1 }

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: isActive ? .semibold : .medium)
        label.textColor = isActive ? c.textPrimary : c.textSecondary
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false

        let close = NSButton(title: "", target: self, action: #selector(closeTapped))
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .bold))
        close.imagePosition = .imageOnly
        close.isBordered = false
        close.contentTintColor = c.textSecondary
        close.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(close)
        self.closeButton = close
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: close.leadingAnchor, constant: -4),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 14),
            close.heightAnchor.constraint(equalToConstant: 14),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            widthAnchor.constraint(lessThanOrEqualToConstant: 160),
            heightAnchor.constraint(equalToConstant: 26),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let btn = closeButton, btn.frame.contains(loc) {
            return // let the button handle it
        }
        onSelect?(id)
    }

    @objc private func closeTapped() { onClose?(id) }
}
