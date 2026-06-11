import AppKit

@MainActor
final class CompletionPopupView: NSView {
    private let background = HarnessOverlayBackground()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    
    private var candidates: [String] = []
    private var selectedIndex: Int = 0
    
    var onConfirm: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = HarnessDesign.Radius.overlay
        layer?.cornerCurve = .continuous
        
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        background.contentView.addSubview(scrollView)
        
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 1
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
        ])
        
        scrollView.documentView = documentView
        
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
    }
    
    func update(candidates: [String]) {
        self.candidates = candidates
        self.selectedIndex = 0
        rebuildRows()
    }
    
    private func rebuildRows() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, candidate) in candidates.enumerated() {
            let row = CompletionRowView(text: candidate, isSelected: index == selectedIndex)
            row.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(row)
            
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            row.onClick = { [weak self] in
                guard let self else { return }
                self.selectedIndex = index
                self.confirmSelection()
            }
        }
        
        if selectedIndex < stackView.arrangedSubviews.count {
            let selectedView = stackView.arrangedSubviews[selectedIndex]
            let rect = selectedView.frame
            scrollView.contentView.scroll(to: rect.origin)
        }
    }
    
    func moveSelection(down: Bool) -> Bool {
        guard !candidates.isEmpty else { return false }
        if down {
            selectedIndex = (selectedIndex + 1) % candidates.count
        } else {
            selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
        }
        rebuildRows()
        return true
    }
    
    func confirmSelection() {
        guard selectedIndex >= 0 && selectedIndex < candidates.count else { return }
        onConfirm?(candidates[selectedIndex])
    }
}

@MainActor
private final class CompletionRowView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { applyChrome() } }
    private let isSelected: Bool
    
    var onClick: (() -> Void)?
    
    init(text: String, isSelected: Bool) {
        self.isSelected = isSelected
        super.init(frame: .zero)
        setup(text: text)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup(text: String) {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        
        label.stringValue = text
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        applyChrome()
    }
    
    private func applyChrome() {
        let c = HarnessDesign.chrome
        if isSelected {
            layer?.backgroundColor = c.accent.withAlphaComponent(0.25).cgColor
            label.textColor = c.textPrimary
        } else if isHovered {
            layer?.backgroundColor = c.textPrimary.withAlphaComponent(0.08).cgColor
            label.textColor = c.textPrimary
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            label.textColor = c.textSecondary
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
