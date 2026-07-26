import AppKit

/// Thin draggable strip above the tab bar, in the window's `.fullSizeContentView` titlebar
/// region. Two jobs: (1) give the user a grab area to move the window (and breathing room above
/// the tab pills so dragging a tab never fights a window-move), and (2) show the active tab's
/// directory the way Ghostty does — a folder glyph + `· name`, centered. Purely chrome: clicks
/// fall through to window-drag (the traffic-light buttons live above this in the frame view).
@MainActor
final class WindowTitleStripView: NSView {
    private let folderIcon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let previewBadge = NSTextField(labelWithString: "")
    private let remoteBadge = NSButton(title: "Local", target: nil, action: nil)
    private let stack = NSStackView()
    /// Base left padding for the readout; the traffic-light inset is added on top while
    /// the sidebar is collapsed (the lights then sit over the strip's left edge).
    private var stackLeading: NSLayoutConstraint?
    private let basePadding: CGFloat = 14

    /// Height: enough to seat the path readout and clear the macOS traffic lights so the tab
    /// strip below never overlaps them (which is why the tab bar no longer needs a leading inset).
    static let height: CGFloat = 30

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        folderIcon.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")?
            .withSymbolConfiguration(config)
        folderIcon.imageScaling = .scaleProportionallyUpOrDown
        folderIcon.translatesAutoresizingMaskIntoConstraints = false

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.alignment = .left
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false

        previewBadge.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        previewBadge.alignment = .right
        previewBadge.lineBreakMode = .byTruncatingMiddle
        previewBadge.translatesAutoresizingMaskIntoConstraints = false
        previewBadge.isHidden = true

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(folderIcon)
        stack.addArrangedSubview(label)
        addSubview(stack)
        configureRemoteBadge()
        addSubview(remoteBadge)
        addSubview(previewBadge)

        let leading = stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: basePadding)
        stackLeading = leading
        NSLayoutConstraint.activate([
            leading,
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: remoteBadge.leadingAnchor, constant: -12),
            remoteBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            remoteBadge.trailingAnchor.constraint(equalTo: previewBadge.leadingAnchor, constant: -8),
            previewBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            previewBadge.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            folderIcon.widthAnchor.constraint(equalToConstant: 16),
            folderIcon.heightAnchor.constraint(equalToConstant: 16),
        ])
        configurePreviewBadge()
        refreshRemoteBadge()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(remoteHostDidChange),
            name: RemoteHostsService.activeHostDidChange,
            object: nil
        )
        applyColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let child buttons (remoteBadge) receive their own clicks.
        // Only claim the hit for dragging if no interactive subview is under the point.
        for subview in subviews.reversed() {
            let local = subview.convert(point, from: self)
            if let hit = subview.hitTest(local), hit is NSButton {
                return hit
            }
        }
        if let _ = super.hitTest(point) {
            return self
        }
        return nil
    }

    /// A drag anywhere on the strip moves the window (matches the empty tab-bar background).
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2,
           let controller = window?.windowController as? MainWindowController
        {
            controller.toggleVisibleFrameZoom(self)
            return
        }
        super.mouseUp(with: event)
    }

    /// Shift the readout right of the macOS traffic lights while the sidebar is collapsed
    /// (0 = sidebar visible; ~72 = collapsed). Driven by `MainSplitViewController` during
    /// the toggle so it slides in lockstep with the divider.
    func setLeadingInset(_ inset: CGFloat) {
        stackLeading?.constant = basePadding + inset
    }

    /// Show the active tab's directory as `· basename`, Ghostty-style. Empty cwd hides the readout
    /// (the strip stays as a drag handle).
    func setPath(_ cwd: String, gitBranch: String? = nil) {
        let name = KouenDesign.pathDisplayName(cwd)
        let hasBranch = !(gitBranch ?? "").isEmpty
        let hasPath = !name.isEmpty
        let hasContent = hasPath || hasBranch
        folderIcon.isHidden = !hasPath
        label.isHidden = !hasContent
        if hasBranch && hasPath {
            label.stringValue = "·  \(name)  (⎇ \(gitBranch!))"
        } else if hasBranch {
            label.stringValue = "·  ⎇ \(gitBranch!)"
        } else if hasPath {
            label.stringValue = "·  \(name)"
        } else {
            label.stringValue = ""
        }
        toolTip = hasPath ? KouenDesign.shortenPath(cwd) : nil
    }

    func applyColors() {
        KouenDesign.applyTabBarChrome(to: self)
        let c = KouenDesign.chrome
        folderIcon.contentTintColor = c.textSecondary
        label.textColor = c.textSecondary
        previewBadge.textColor = c.textTertiary
        remoteBadge.contentTintColor = c.textSecondary
        remoteBadge.layer?.backgroundColor = c.surfaceElevated.cgColor
        remoteBadge.layer?.borderColor = c.border.cgColor
    }

    private func configureRemoteBadge() {
        remoteBadge.bezelStyle = .shadowlessSquare
        remoteBadge.isBordered = false
        remoteBadge.font = .systemFont(ofSize: 11, weight: .medium)
        remoteBadge.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Remote")
        remoteBadge.imagePosition = .imageLeading
        remoteBadge.target = self
        remoteBadge.action = #selector(remoteBadgeClicked)
        remoteBadge.toolTip = "Remote daemon"
        remoteBadge.wantsLayer = true
        remoteBadge.layer?.cornerRadius = 6
        remoteBadge.layer?.cornerCurve = .continuous
        remoteBadge.layer?.borderWidth = 1
        remoteBadge.contentTintColor = .secondaryLabelColor
        remoteBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remoteBadge.heightAnchor.constraint(equalToConstant: 22),
            remoteBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
        ])
    }

    @objc private func remoteHostDidChange() {
        refreshRemoteBadge()
    }

    func refreshRemoteBadge() {
        if let active = RemoteHostsService.shared.activeHostName {
            remoteBadge.title = active
            remoteBadge.toolTip = "Connected to \(active). Click to disconnect."
            remoteBadge.contentTintColor = KouenChrome.current.accent
        } else {
            remoteBadge.title = "Local"
            remoteBadge.toolTip = "Using local daemon"
            remoteBadge.contentTintColor = KouenChrome.current.textSecondary
        }
    }

    @objc private func remoteBadgeClicked() {
        if RemoteHostsService.shared.activeHostName != nil {
            SessionCoordinator.shared.disconnectRemote()
        } else {
            SettingsWindowController.show(page: SettingsWindowController.pageRemote)
        }
    }

    private func configurePreviewBadge() {
        guard Bundle.main.bundleIdentifier == "com.vit129.kouen.preview",
              let label = Bundle.main.object(forInfoDictionaryKey: "KouenPreviewBuildLabel") as? String,
              !label.isEmpty
        else { return }
        previewBadge.stringValue = "PREVIEW · \(label)"
        if let builtAt = Bundle.main.object(forInfoDictionaryKey: "KouenPreviewBuiltAt") as? String {
            previewBadge.toolTip = "Built \(builtAt)"
        }
        previewBadge.isHidden = false
    }
}
