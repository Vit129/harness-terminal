import AppKit
import WebKit
import KouenCore

@MainActor
public final class BrowserPaneView: NSView {
    public let paneID: PaneID
    public private(set) var webView: WKWebView

    // MARK: - Tab Model

    struct BrowserTab {
        let id: UUID
        let webView: WKWebView
        var title: String
    }

    private var tabs: [BrowserTab] = []
    private var activeTabIndex: Int = 0
    private var activeTab: BrowserTab? { tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex] : nil }
    private var consoleLogs: [String] = []
    private var pendingLogLines: [String] = []
    private var logWriteScheduled = false
    private var compositorKickInFlight = false

    private let tabBar = NSView()
    private let tabBarStack = NSStackView()
    private let newTabButton = NSButton()

    private let toolbar = NSView()
    private let backButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private let forwardButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    internal let reloadStopButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    internal let urlTextField = NSTextField()
    internal let closePaneButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    internal let viewSourceButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    internal let darkModeButton = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private var isWebDarkModeForced = false
    /// Called when user taps the close (×) button in the toolbar.
    public var onClosePaneRequested: (() -> Void)?
    /// Called when user taps "View Source" while showing a local .html/.htm file:// URL.
    public var onViewSourceRequested: ((URL) -> Void)?

    internal let errorBanner = NSView()
    internal let errorLabel = NSTextField(labelWithString: "")
    internal let errorDismissButton = NSButton()
    internal var errorBannerHeightConstraint: NSLayoutConstraint?

    private var retryTimer: Timer?
    private var retryCount = 0
    private static let maxRetries = 10  // 10 × 3s = 30s then auto-close

    private var loadStates: [LoadCompletionState] = []
    private let progressLine = BrowserProgressLine()
    private var progressObservation: NSKeyValueObservation?

    // WKWebView's default UA drops the "Version/x.y Safari/605.1.15" suffix real Safari
    // sends, which Google/Apple OAuth's embedded-webview detection keys on (disallowed_useragent).
    // ponytail: hardcoded to the Safari version installed at dev time (26.5) — rots as WebKit
    // updates; bump when OAuth starts failing again or a newer Safari version ships.
    static let desktopSafariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"

    // ponytail: minimal allowlist of known OAuth/SSO authorization hosts. Kouen's own debug
    // script injection (console capture, network capture, scroll-fix) must not run here —
    // console/fetch/XHR overrides are exactly the "read every keystroke / intercept session"
    // capability Google's embedded-webview policy warns about, even though Kouen's intent is
    // only local debugging. Deliberately narrow: whole-domain identity hosts only (their
    // entire surface is auth), not broad app domains like github.com/facebook.com where a
    // wildcard would also kill debugging on unrelated pages. Extend if a new provider's login
    // page needs the same protection.
    private static let oauthOriginBlocklist = ["accounts.google.com", "appleid.apple.com"]

    private static var oauthGuardJS: String {
        let hosts = oauthOriginBlocklist.map { "'\($0)'" }.joined(separator: ", ")
        return "if ([\(hosts)].indexOf(location.hostname) !== -1) return;"
    }

    public convenience init(url: URL, paneID: PaneID = UUID()) {
        let web: WKWebView
        if let warmed = BrowserPaneRegistry.shared.dequeueWarmedWebView() {
            web = warmed
        } else {
            let config = WKWebViewConfiguration()
            config.limitsNavigationsToAppBoundDomains = false
            web = WKWebView(frame: .zero, configuration: config)
            web.allowsMagnification = true
            web.allowsBackForwardNavigationGestures = true
            web.customUserAgent = Self.desktopSafariUserAgent
#if DEBUG
            web.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        }
        self.init(url: url, paneID: paneID, webView: web)
    }

    internal init(url: URL, paneID: PaneID, webView: WKWebView) {
        self.paneID = paneID
        self.webView = webView

        super.init(frame: .zero)
        wantsLayer = true

        // Create first tab
        let firstTab = BrowserTab(id: UUID(), webView: webView, title: "New Tab")
        tabs.append(firstTab)

        let tempDir = NSTemporaryDirectory()
        let logPath = (tempDir as NSString).appendingPathComponent("kouen-browser-\(paneID.uuidString).log")
        try? "".write(toFile: logPath, atomically: true, encoding: .utf8)

        setupConsoleLogRedirection(for: webView)
        setupNetworkCapture(for: webView)

        setupUI()
        setupTabBar()
        setupConstraints()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        BrowserPaneRegistry.shared.register(self)
        setupProgressObservation()

        let resolvedURL: URL
        if let savedURLString = UserDefaults.standard.string(forKey: "browserPane.\(paneID.uuidString).url"),
           let savedURL = URL(string: savedURLString) {
            resolvedURL = savedURL
        } else {
            resolvedURL = url
        }

        navigate(to: resolvedURL)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        let uuid = paneID.uuidString
        NSLog("[BrowserPane] deinit \(uuid)")
    }

    override public func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        // When the browser pane is reattached after a pane tree rebuild, WKWebView
        // may show a blank/pink frame until the next draw cycle. Force a
        // display to ensure the web content process repaints.
        if superview != nil, window != nil {
            webView.setNeedsDisplay(webView.bounds)
            // Also nudge the web content process by evaluating a trivial script
            // — this is the most reliable way to wake WKWebView's compositor.
            webView.evaluateJavaScript("void(0)") { _, _ in }
        }
    }

    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            cancelRetry()
            // Defer unregister: during pane tree rebuilds, the view is briefly detached
            // then re-attached in the same runloop cycle. Only unregister if still
            // windowless after the rebuild completes.
            let id = paneID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if BrowserPaneRegistry.shared.get(id)?.window == nil {
                    BrowserPaneRegistry.shared.unregister(id)
                }
            }
        }
    }

    private func setupUI() {
        // Toolbar styling — translucent Liquid Glass backdrop matching backgroundOpacity setting
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        KouenDesign.applyTabBarChrome(to: toolbar)

        // WebKit transparency configuration — prevents initial white background paint/flash
        webView.setValue(false, forKey: "drawsBackground")
        webView.setValue(NSColor.clear, forKey: "underPageBackgroundColor")

        let border = NSView()
        border.wantsLayer = true
        border.layer?.backgroundColor = KouenDesign.chrome.border.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(border)
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Buttons configuration
        configureNavigationButton(backButton, symbolName: "chevron.left", action: #selector(backClicked))
        backButton.setAccessibilityIdentifier("browser-back-button")
        configureNavigationButton(forwardButton, symbolName: "chevron.right", action: #selector(forwardClicked))
        forwardButton.setAccessibilityIdentifier("browser-forward-button")
        configureNavigationButton(reloadStopButton, symbolName: "arrow.clockwise", action: #selector(reloadStopClicked))
        reloadStopButton.setAccessibilityIdentifier("browser-reload-button")
        configureNavigationButton(closePaneButton, symbolName: "xmark", action: #selector(closePaneClicked))
        closePaneButton.setAccessibilityIdentifier("browser-close-button")
        closePaneButton.toolTip = "Close Browser Pane"

        for btn in [backButton, forwardButton, reloadStopButton, closePaneButton, viewSourceButton, darkModeButton] {
            btn.setContentHuggingPriority(.required, for: .horizontal)
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        configureNavigationButton(viewSourceButton, symbolName: "chevron.left.slash.chevron.right", action: #selector(viewSourceClicked))
        viewSourceButton.setAccessibilityIdentifier("browser-view-source-button")
        viewSourceButton.toolTip = "View Source"
        viewSourceButton.isHidden = true

        configureNavigationButton(darkModeButton, symbolName: "doc.on.doc", action: #selector(copyURLClicked))
        darkModeButton.setAccessibilityIdentifier("browser-copy-url-button")
        darkModeButton.toolTip = "Copy URL"

        // URL Text Field container & configuration
        let urlContainer = NSView()
        urlContainer.translatesAutoresizingMaskIntoConstraints = false
        urlContainer.wantsLayer = true
        urlContainer.layer?.cornerRadius = 6
        urlContainer.layer?.cornerCurve = .continuous
        urlContainer.layer?.backgroundColor = KouenDesign.chrome.surfaceElevated.cgColor
        urlContainer.layer?.borderColor = KouenDesign.chrome.borderStrong.cgColor
        urlContainer.layer?.borderWidth = 1

        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.isEditable = true
        urlTextField.drawsBackground = false
        urlTextField.textColor = KouenDesign.chrome.textPrimary
        urlTextField.isBezeled = false
        urlTextField.isBordered = false
        urlTextField.focusRingType = .none
        urlTextField.target = self
        urlTextField.action = #selector(urlEntered(_:))
        urlTextField.alignment = .left
        urlTextField.font = NSFont.systemFont(ofSize: KouenDesign.FontSize.chromeBody)
        urlTextField.setAccessibilityIdentifier("browser-url-text-field")

        urlContainer.addSubview(urlTextField)

        // Web View container background — solid dark canvas behind web content so wallpaper doesn't leak through
        wantsLayer = true
        layer?.backgroundColor = KouenChrome.current.terminalBackground.cgColor

        NSLayoutConstraint.activate([
            urlTextField.leadingAnchor.constraint(equalTo: urlContainer.leadingAnchor, constant: 8),
            urlTextField.trailingAnchor.constraint(equalTo: urlContainer.trailingAnchor, constant: -8),
            urlTextField.centerYAnchor.constraint(equalTo: urlContainer.centerYAnchor),
        ])

        // Two equal-priority flexible spacers straddling the url field center it in the
        // remaining space between the nav-button group (left) and the action-button group
        // (right), instead of pinning it to either edge.
        let leadingSpacer = NSView()
        leadingSpacer.translatesAutoresizingMaskIntoConstraints = false
        leadingSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        leadingSpacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        let trailingSpacer = NSView()
        trailingSpacer.translatesAutoresizingMaskIntoConstraints = false
        trailingSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        trailingSpacer.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        let toolbarStack = NSStackView(views: [backButton, forwardButton, reloadStopButton, leadingSpacer, urlContainer, trailingSpacer, viewSourceButton, darkModeButton, closePaneButton])
        toolbarStack.orientation = .horizontal
        toolbarStack.spacing = 6
        toolbarStack.edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 8)
        toolbarStack.alignment = .centerY
        toolbarStack.distribution = .fill
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(toolbarStack)

        urlContainer.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        urlContainer.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 24),
            forwardButton.widthAnchor.constraint(equalToConstant: 24),
            reloadStopButton.widthAnchor.constraint(equalToConstant: 24),
            darkModeButton.widthAnchor.constraint(equalToConstant: 24),
            closePaneButton.widthAnchor.constraint(equalToConstant: 24),
            urlContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            urlContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            toolbarStack.topAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbarStack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor),
            urlContainer.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Default Web Browser to Dark Mode on start
        applyWebDarkMode()

        // Error Banner configuration
        errorBanner.wantsLayer = true
        errorBanner.layer?.backgroundColor = KouenDesign.chrome.danger.withAlphaComponent(0.15).cgColor
        errorBanner.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textColor = KouenDesign.chrome.danger
        errorLabel.font = NSFont.systemFont(ofSize: KouenDesign.FontSize.chromeSmall)
        errorLabel.lineBreakMode = .byTruncatingTail
        errorBanner.addSubview(errorLabel)

        errorDismissButton.translatesAutoresizingMaskIntoConstraints = false
        errorDismissButton.title = ""
        errorDismissButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Dismiss")
        errorDismissButton.bezelStyle = .rounded
        errorDismissButton.target = self
        errorDismissButton.action = #selector(dismissErrorBanner)
        errorDismissButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        errorDismissButton.heightAnchor.constraint(equalToConstant: 16).isActive = true
        errorBanner.addSubview(errorDismissButton)

        NSLayoutConstraint.activate([
            errorLabel.leadingAnchor.constraint(equalTo: errorBanner.leadingAnchor, constant: 8),
            errorLabel.centerYAnchor.constraint(equalTo: errorBanner.centerYAnchor),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: errorDismissButton.leadingAnchor, constant: -8),

            errorDismissButton.trailingAnchor.constraint(equalTo: errorBanner.trailingAnchor, constant: -8),
            errorDismissButton.centerYAnchor.constraint(equalTo: errorBanner.centerYAnchor)
        ])

        webView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupTabBar() {
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.wantsLayer = true
        KouenDesign.applyTabBarChrome(to: tabBar)

        tabBarStack.orientation = .horizontal
        tabBarStack.spacing = 1
        tabBarStack.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabBarStack)

        newTabButton.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
        newTabButton.isBordered = false
        newTabButton.target = self
        newTabButton.action = #selector(addNewTab)
        tabBarStack.addArrangedSubview(newTabButton)

        NSLayoutConstraint.activate([
            tabBarStack.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 2),
            tabBarStack.trailingAnchor.constraint(lessThanOrEqualTo: tabBar.trailingAnchor, constant: -8),
            tabBarStack.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
        ])

        refreshTabBar()
    }
    private func refreshTabBar() {
        // Remove existing tab views (keep newTabButton)
        for view in tabBarStack.arrangedSubviews where view !== newTabButton {
            tabBarStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        // Add tab buttons
        for (i, tab) in tabs.enumerated() {
            let btn = BrowserTabButton(
                title: tab.title,
                isActive: i == activeTabIndex,
                onSelect: { [weak self] in self?.selectTab(at: i) },
                onClose: { [weak self] in self?.closeTab(at: i) }
            )
            tabBarStack.insertArrangedSubview(btn, at: i)
        }
        // Always show tab bar (like Chrome/Safari)
        tabBar.isHidden = false
    }

    @objc private func addNewTab() {
        let home = SessionCoordinator.shared.settings.browserHomePage
        createTab(url: URL(string: home) ?? URL(string: "https://www.google.com")!)
    }

    @objc private func toggleWebDarkMode() {
        isWebDarkModeForced.toggle()
        applyWebDarkMode()
        let mode = isWebDarkModeForced ? "Force Dark Mode ON" : "Force Dark Mode OFF"
        Toast.show(mode, in: self)
    }

    private func applyWebDarkMode() {
        darkModeButton.contentTintColor = isWebDarkModeForced ? KouenDesign.chrome.accent : KouenDesign.chrome.textSecondary
        if #available(macOS 10.14, *) {
            webView.appearance = isWebDarkModeForced ? NSAppearance(named: .darkAqua) : nil
        }
        let script = """
        (function() {
            var id = 'kouen-force-dark-mode-style';
            var existing = document.getElementById(id);
            if (\(isWebDarkModeForced ? "true" : "false")) {
                if (!existing) {
                    var style = document.createElement('style');
                    style.id = id;
                    style.innerHTML = `
                        html, body { filter: invert(0.94) hue-rotate(180deg) !important; background-color: #121212 !important; }
                        img, video, iframe, canvas, svg, picture, [style*="background-image"] { filter: invert(1.06) hue-rotate(180deg) !important; }
                    `;
                    (document.head || document.documentElement).appendChild(style);
                }
            } else {
                if (existing) existing.remove();
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    @discardableResult
    func createTab(url: URL, configuration: WKWebViewConfiguration? = nil, skipLoad: Bool = false) -> WKWebView {
        let isFreshConfiguration = configuration == nil
        let config = configuration ?? WKWebViewConfiguration()
        if isFreshConfiguration { config.limitsNavigationsToAppBoundDomains = false }
        let newWeb = WKWebView(frame: webView.frame, configuration: config)
        newWeb.appearance = isWebDarkModeForced ? NSAppearance(named: .darkAqua) : nil
        newWeb.navigationDelegate = self
        newWeb.uiDelegate = self
        newWeb.translatesAutoresizingMaskIntoConstraints = false
        newWeb.customUserAgent = Self.desktopSafariUserAgent

        let darkModeUserScript = WKUserScript(
            source: """
            (function() {
                function inject() {
                    var id = 'kouen-force-dark-mode-style';
                    if (!document.getElementById(id)) {
                        var style = document.createElement('style');
                        style.id = id;
                        style.innerHTML = `
                            html, body { filter: invert(0.94) hue-rotate(180deg) !important; background-color: #121212 !important; }
                            img, video, iframe, canvas, svg, picture, [style*="background-image"] { filter: invert(1.06) hue-rotate(180deg) !important; }
                        `;
                        (document.head || document.documentElement).appendChild(style);
                    }
                }
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', inject);
                }
                inject();
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        if isWebDarkModeForced {
            config.userContentController.addUserScript(darkModeUserScript)
        }

        // A reused configuration (popup/window.open via createWebViewWith) shares its
        // WKUserContentController with the opener tab, which already has these handlers
        // registered — adding "kouenConsoleLog" a second time throws and crashes the app.
        // The injected scripts stay active for the new tab either way since they live on
        // the shared controller, so skipping re-setup here loses nothing.
        if isFreshConfiguration {
            setupConsoleLogRedirection(for: newWeb)
            setupNetworkCapture(for: newWeb)
        }

        let tab = BrowserTab(id: UUID(), webView: newWeb, title: "New Tab")
        tabs.append(tab)
        selectTab(at: tabs.count - 1)
        // skipLoad: true for the createWebViewWith (window.open) path — WKWebView
        // auto-loads navigationAction.request into the view once we return it from that
        // delegate method. Calling .load() ourselves here starts a second, disconnected
        // navigation that severs window.opener (breaks postMessage-based OAuth handoffs).
        if !skipLoad {
            if url.isFileURL {
                newWeb.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                newWeb.load(URLRequest(url: url))
            }
        }
        return newWeb
    }

    private var mainStack: NSStackView!

    private func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        let oldWeb = webView
        activeTabIndex = index
        let newWeb = tabs[index].webView

        if oldWeb !== newWeb {
            // Swap webView in the stack
            if let stackIndex = mainStack.arrangedSubviews.firstIndex(of: oldWeb) {
                mainStack.removeArrangedSubview(oldWeb)
                oldWeb.removeFromSuperview()
                newWeb.translatesAutoresizingMaskIntoConstraints = false
                mainStack.insertArrangedSubview(newWeb, at: stackIndex)
            }
            webView = newWeb
            setupProgressObservation()
        }
        urlTextField.stringValue = newWeb.url?.absoluteString ?? ""
        updateViewSourceButtonVisibility(for: newWeb.url)
        refreshTabBar()
    }

    private func closeTab(at index: Int) {
        NSLog("BROWSER_DEBUG: closeTab(at: %d), tabs.count=%d", index, tabs.count)
        guard tabs.count > 1 else {
            // Last tab — close the entire browser pane
            SessionCoordinator.shared.splitPaneCoordinator.closeBrowserPane(paneID: paneID)
            return
        }
        tabs[index].webView.removeFromSuperview()
        tabs.remove(at: index)
        let newIndex = min(activeTabIndex, tabs.count - 1)
        selectTab(at: newIndex)
    }

    private func setupConstraints() {
        progressLine.translatesAutoresizingMaskIntoConstraints = false
        let mainStack = NSStackView(views: [tabBar, toolbar, progressLine, errorBanner, webView])
        mainStack.orientation = .vertical
        mainStack.spacing = 0
        mainStack.alignment = .width
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        self.mainStack = mainStack

        let errorConstraint = errorBanner.heightAnchor.constraint(equalToConstant: 0)
        errorBannerHeightConstraint = errorConstraint
        errorBanner.isHidden = true

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            // `mainStack.alignment = .width` alone doesn't reliably hold tabBar/toolbar to
            // the full pane width — they were observed shrinking to content size and
            // drifting off the left edge (NSStackView width-alignment constraints lose out
            // to the row's own internal layout). Pin explicitly instead of relying on it.
            tabBar.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            toolbar.leadingAnchor.constraint(equalTo: mainStack.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            tabBar.heightAnchor.constraint(equalToConstant: 28),
            toolbar.heightAnchor.constraint(equalToConstant: 32),
            progressLine.heightAnchor.constraint(equalToConstant: 2),
            errorConstraint
        ])
    }

    private func setupProgressObservation() {
        progressObservation = webView.observe(\.estimatedProgress, options: []) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.progressLine.setProgress(wv.estimatedProgress, isLoading: wv.isLoading)
            }
        }
    }

    private func setupConsoleLogRedirection(for webView: WKWebView) {
        let js = """
        (function() {
            \(Self.oauthGuardJS)
            if (window.__kouenConsoleRedirected) return;
            window.__kouenConsoleRedirected = true;
            var levels = ['log', 'info', 'warn', 'error', 'debug'];
            levels.forEach(function(level) {
                var original = console[level];
                console[level] = function() {
                    if (original) {
                        original.apply(console, arguments);
                    }
                    var args = Array.prototype.slice.call(arguments);
                    var msg = args.map(function(arg) {
                        if (typeof arg === 'object') {
                            try { return JSON.stringify(arg); } catch(e) { return String(arg); }
                        }
                        return String(arg);
                    }).join(' ');
                    try {
                        window.webkit.messageHandlers.kouenConsoleLog.postMessage({
                            level: level,
                            message: msg
                        });
                    } catch(e) {}
                };
            });
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let controller0 = webView.configuration.userContentController
        controller0.addUserScript(userScript)
        controller0.add(WeakScriptMessageHandler(self), name: "kouenConsoleLog")

        // Nested cross-origin iframe (e.g. a claude.ai artifact embed) doesn't get a
        // scrolling-tree node built at initial layout, so wheel scroll silently does
        // nothing until a relayout forces a commit (see kickCompositorRelayout). This
        // in-frame script fires that native relayout on the user's first pointer move
        // over the frame — before they scroll — so the node is committed by the time the
        // first wheel arrives. JS only *signals*; the native side does the fix.
        var kickJS = """
        (function() {
            \(Self.oauthGuardJS)
            if (window.self === window.top) return;   // nested frames only
            if (window.__kouenKickBound) return;
            window.__kouenKickBound = true;
            function kick() {
                try { window.webkit.messageHandlers.kouenCompositorKick.postMessage(1); } catch (e) {}
            }
            // Preemptive: fire as the pointer first crosses the frame, before the scroll.
            // Backstop: the first real wheel gets its own guaranteed shot, so a pre-scroll
            // hover can't consume the one chance that matters. Two one-shots — bounded, no
            // perpetual flicker on continued hovering.
            window.addEventListener('pointermove', kick, { capture: true, passive: true, once: true });
            window.addEventListener('wheel', kick, { capture: true, passive: true, once: true });
        })();
        """
        #if DEBUG
        // Proves from the log file alone whether the kick worked: for each wheel in a
        // nested frame it records the nearest scrollable ancestor's scrollTop before and
        // after the native scroll. moved=false before the kick lands, moved=true after.
        kickJS += """
        (function() {
            \(Self.oauthGuardJS)
            if (window.self === window.top || window.__kouenScrollProbe) return;
            window.__kouenScrollProbe = true;
            window.addEventListener('wheel', function(e) {
                var el = e.target;
                while (el && el.nodeType === 1) {
                    var oy = getComputedStyle(el).overflowY;
                    if ((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight + 1) break;
                    el = el.parentElement;
                }
                var sc = el || document.scrollingElement || document.documentElement;
                var before = sc.scrollTop;
                requestAnimationFrame(function() {
                    console.log('kouen.scrollprobe dy=' + Math.round(e.deltaY) +
                        ' before=' + before + ' after=' + sc.scrollTop +
                        ' moved=' + (sc.scrollTop !== before));
                });
            }, { capture: true, passive: true });
        })();
        """
        #endif
        controller0.addUserScript(WKUserScript(source: kickJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        controller0.add(WeakScriptMessageHandler(self), name: "kouenCompositorKick")
    }

    // WebKit's async scrolling thread doesn't build a scrolling-tree node for a nested
    // cross-origin iframe's scrollable content at initial layout, so wheel scrolling (which
    // runs through the scrolling thread) does nothing — while dragging the scrollbar works,
    // since that path runs in the web process where the RenderLayer *is* scrollable. A scale
    // change forces a scrolling-tree commit that builds the node; that's why a manual pinch
    // fixes it. Real Safari and the top-level document don't need this — only nested frames.
    // We replicate the pinch at the AppKit level: nudge magnification, then revert once the
    // commit has run so the zoom is imperceptible. Triggered by the in-frame script above on
    // the user's first pointer move over the frame (see setupConsoleLogRedirection), so it
    // fires only when a nested frame exists and its content is laid out — not on a blind
    // timer. P35 investigation, 2026-07-06, see agent-memory/knowledge/ui/browser-pane.md.
    private func kickCompositorRelayout(for webView: WKWebView) {
        guard webView.allowsMagnification, !compositorKickInFlight else { return }
        compositorKickInFlight = true
        let current = webView.magnification
        // Delta must clear WebKit's internal rounding so the scale change is actually
        // applied (a sub-pixel nudge can be coalesced into a no-op that never commits).
        webView.setMagnification(current + 0.01, centeredAt: .zero)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak webView] in
            webView?.setMagnification(current, centeredAt: .zero)
            self?.compositorKickInFlight = false
        }
    }

    private func setupNetworkCapture(for webView: WKWebView) {
        let js = """
        (function() {
            \(Self.oauthGuardJS)
            if (window.__kouenNetworkCaptured) return;
            window.__kouenNetworkCaptured = true;
            window.__kouenNetwork = [];
            window.__kouenNetworkSeq = 0;
            // Cap the ring so a long-lived polling/streaming page can't grow this array without
            // bound (each entry holds up to 2 KB request + 4 KB response). Mirrors the console cap.
            var __cap = function() { while (window.__kouenNetwork.length > 500) window.__kouenNetwork.shift(); };
            var _fetch = window.fetch;
            window.fetch = function(input, init) {
                var url = typeof input === 'string' ? input : (input.url || String(input));
                var method = (init && init.method) || (typeof input === 'object' && input.method) || 'GET';
                var reqBody = (init && init.body) ? String(init.body).slice(0, 2000) : null;
                var t0 = Date.now();
                var entry = { id: 'r' + (++window.__kouenNetworkSeq), url: url, method: method, requestBody: reqBody, timestamp: t0 / 1000 };
                window.__kouenNetwork.push(entry); __cap();
                return _fetch.apply(this, arguments).then(function(res) {
                    entry.status = res.status;
                    entry.duration = (Date.now() - t0) / 1000;
                    var clone = res.clone();
                    clone.text().then(function(body) { entry.responseBody = body.slice(0, 4000); }).catch(function(){});
                    return res;
                }).catch(function(e) { entry.status = 0; throw e; });
            };
            var _open = XMLHttpRequest.prototype.open;
            var _send = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function(method, url) {
                this.__kouenMethod = method;
                this.__kouenUrl = url;
                this.__kouenT0 = Date.now();
                return _open.apply(this, arguments);
            };
            XMLHttpRequest.prototype.send = function(body) {
                var entry = { id: 'r' + (++window.__kouenNetworkSeq), url: this.__kouenUrl || '', method: this.__kouenMethod || 'GET', requestBody: body ? String(body).slice(0, 2000) : null, timestamp: (this.__kouenT0 || Date.now()) / 1000 };
                window.__kouenNetwork.push(entry); __cap();
                this.addEventListener('load', function() {
                    entry.status = this.status;
                    entry.duration = (Date.now() - (this.__kouenT0 || Date.now())) / 1000;
                    entry.responseBody = this.responseText ? this.responseText.slice(0, 4000) : null;
                });
                return _send.apply(this, arguments);
            };
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(userScript)
    }

    public func cookies() async -> [BrowserCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let result = cookies.map { c in
                    BrowserCookie(
                        name: c.name,
                        value: c.value,
                        domain: c.domain,
                        path: c.path,
                        expires: c.expiresDate?.timeIntervalSince1970,
                        isSecure: c.isSecure,
                        isHTTPOnly: c.isHTTPOnly
                    )
                }
                continuation.resume(returning: result)
            }
        }
    }

    public func storage(type: String) async throws -> [String: String] {
        let store = type == "session" ? "sessionStorage" : "localStorage"
        let json = try await evaluateJS("""
        (function(){
          var result={};
          var s=window[\(store == "localStorage" ? "'localStorage'" : "'sessionStorage'")];
          for(var i=0;i<s.length;i++){var k=s.key(i);result[k]=s.getItem(k);}
          return JSON.stringify(result);
        })()
        """)
        guard let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    public func networkRequests() async throws -> [BrowserNetworkEntry] {
        let json = try await evaluateJS("JSON.stringify(window.__kouenNetwork || [])")
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([BrowserNetworkEntry].self, from: data)) ?? []
    }

    private func configureNavigationButton(_ button: SoftIconButton, symbolName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setSymbol(symbolName, accessibilityDescription: nil, pointSize: 11, weight: .medium)
        button.target = self
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 20).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
    }

    // MARK: - Actions

    @objc private func closePaneClicked() {
        NSLog("BROWSER_DEBUG: closePaneClicked, onClosePaneRequested=%d", onClosePaneRequested != nil ? 1 : 0)
        if let cb = onClosePaneRequested {
            cb()
        } else {
            // Fallback: remove from pane tree via coordinator
            SessionCoordinator.shared.splitPaneCoordinator.closeBrowserPane(paneID: paneID)
        }
    }

    @objc private func viewSourceClicked() {
        guard let url = webView.url, url.isFileURL else { return }
        onViewSourceRequested?(url)
    }

    @objc private func copyURLClicked() {
        guard let url = webView.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        Toast.show("URL copied", in: self)
    }

    /// Local .html/.htm files can round-trip to the file editor via `onViewSourceRequested`;
    /// every other URL (http/https, about:blank) has no source file to show.
    private func updateViewSourceButtonVisibility(for url: URL?) {
        let ext = url?.pathExtension.lowercased() ?? ""
        viewSourceButton.isHidden = !(url?.isFileURL == true && (ext == "html" || ext == "htm"))
    }

    @objc private func backClicked() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func forwardClicked() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    @objc private func reloadStopClicked() {
        if webView.isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    @objc private func urlEntered(_ sender: NSTextField) {
        let text = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let url: URL
        let knownScheme = text.hasPrefix("http://") || text.hasPrefix("https://")
            || text.hasPrefix("file://") || text.hasPrefix("ftp://")
        let looksLikeDomain = !text.contains(" ")
            && (text.contains(".") || text.hasPrefix("localhost") || text.hasPrefix("127."))
        if knownScheme {
            url = URL(string: text) ?? searchURL(for: text)
        } else if looksLikeDomain {
            url = URL(string: "https://\(text)") ?? searchURL(for: text)
        } else {
            url = searchURL(for: text)
        }
        navigate(to: url)
    }

    private func searchURL(for query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)") ?? URL(string: "about:blank")!
    }

    @objc private func dismissErrorBanner() {
        errorBannerHeightConstraint?.constant = 0
        errorBanner.isHidden = true
    }

    private func showErrorBanner(message: String) {
        errorLabel.stringValue = message
        errorBannerHeightConstraint?.constant = 24
        errorBanner.isHidden = false
    }

    // MARK: - Auto-retry on connection loss

    private func startRetryIfConnectionError(_ error: Error) {
        let nsError = error as NSError
        // NSURLErrorDomain connection failures (server down, refused, timeout, network lost)
        let retryableCodes: Set<Int> = [
            NSURLErrorCannotConnectToHost,      // -1004
            NSURLErrorNetworkConnectionLost,    // -1005
            NSURLErrorNotConnectedToInternet,   // -1009
            NSURLErrorTimedOut,                 // -1001
            NSURLErrorCannotFindHost,           // -1003
        ]
        guard nsError.domain == NSURLErrorDomain, retryableCodes.contains(nsError.code) else { return }
        guard retryTimer == nil else { return }
        retryCount = 0
        showErrorBanner(message: "Server disconnected — reconnecting…")
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.attemptRetry()
            }
        }
    }

    private func attemptRetry() {
        retryCount += 1
        if retryCount > Self.maxRetries {
            cancelRetry()
            // Auto-close: server didn't come back within 30s
            onClosePaneRequested?()
            return
        }
        errorLabel.stringValue = "Reconnecting… (\(retryCount)/\(Self.maxRetries))"
        webView.reload()
    }

    private func cancelRetry() {
        retryTimer?.invalidate()
        retryTimer = nil
        retryCount = 0
    }

    private func updateReloadStopButton(isLoading: Bool) {
        let symbol = isLoading ? "xmark" : "arrow.clockwise"
        reloadStopButton.setSymbol(symbol, accessibilityDescription: nil, pointSize: 11, weight: .medium)
    }

    // MARK: - Public API

    public func navigate(to url: URL) {
        if url.isFileURL {
            // WKWebView refuses plain file:// loads; the directory grant lets
            // sibling assets (course.js, style.css) load alongside the HTML.
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        urlTextField.stringValue = url.absoluteString
        updateViewSourceButtonVisibility(for: url)
        dismissErrorBanner()
    }

    public func evaluateJS(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let resultString = result as? String {
                    continuation.resume(returning: resultString)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    public func snapshot(interactive: Bool) async throws -> BrowserSnapshot {
        let script = """
        (function(){
          // Clear stale stamps from a prior snapshot first — an element that dropped out of
          // THIS snapshot must not keep answering to its old ref (that would make a later
          // querySelector('[data-kouen-ref="eN"]') resolve to a stale, wrong node in document
          // order instead of correctly missing).
          document.querySelectorAll('[data-kouen-ref]').forEach(function(e){e.removeAttribute('data-kouen-ref');});
          var els=[],i=0;
          document.querySelectorAll('a,button,input,select,textarea,[role=button],[role=link],[role=checkbox],[role=radio],[role=combobox],[role=menuitem]').forEach(function(el){
            var r=el.getBoundingClientRect();
            var visible=r.width>0&&r.height>0&&getComputedStyle(el).visibility!=='hidden'&&getComputedStyle(el).display!=='none';
            var id='e'+(++i);
            el.setAttribute('data-kouen-ref', id);
            els.push({
              id:id,
              tag:el.tagName.toLowerCase(),
              role:el.getAttribute('role')||el.tagName.toLowerCase(),
              text:(el.innerText||el.getAttribute('aria-label')||'').trim().slice(0,80),
              value:el.value||'',
              placeholder:el.placeholder||'',
              href:el.href||'',
              bounds:{x:Math.round(r.x),y:Math.round(r.y),width:Math.round(r.width),height:Math.round(r.height)},
              visible:visible
            });
          });
          return JSON.stringify({url:location.href,title:document.title,
            text:document.body.innerText.slice(0,3000),elements:els});
        })()
        """
        let jsonString = try await evaluateJS(script)
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "BrowserPaneView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid snapshot format"])
        }
        var snapshot = try JSONDecoder().decode(BrowserSnapshot.self, from: data)
        snapshot.logs = self.consoleLogs
        return snapshot
    }

    public func screenshot() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image,
                      let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    continuation.resume(throwing: NSError(domain: "BrowserPaneView", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode screenshot"]))
                    return
                }
                continuation.resume(returning: pngData.base64EncodedString())
            }
        }
    }

    public func waitForLoad(timeout: TimeInterval) async throws {
        if !webView.isLoading {
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let state = LoadCompletionState(continuation: continuation)
            self.loadStates.append(state)

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                state.complete(error: NSError(domain: "BrowserPaneView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Loading timed out"]))
            }
        }
    }

    private func completeLoading(error: Error? = nil) {
        let current = loadStates
        loadStates.removeAll()
        for state in current {
            state.complete(error: error)
        }
    }

    // MARK: - Key Equivalents

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        let cmd = event.modifierFlags.contains(.command)
        if cmd && characters == "w" {
            // Intercept before WKWebView consumes it — close this browser pane
            closePaneClicked()
            return true
        }
        if cmd && characters == "l" {
            self.window?.makeFirstResponder(urlTextField)
            return true
        }
        if cmd && characters.lowercased() == "d" {
            // Don't let WKWebView (via super) silently swallow ⌘D/⌘⇧D — let it
            // propagate up so Kouen's Split Right / Split Down menu shortcuts fire.
            return false
        }
        return super.performKeyEquivalent(with: event)
    }
}

extension BrowserPaneView: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url {
            urlTextField.stringValue = url.absoluteString
            updateViewSourceButtonVisibility(for: url)
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateReloadStopButton(isLoading: true)
        dismissErrorBanner()
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateReloadStopButton(isLoading: false)
        cancelRetry()
        if let url = webView.url {
            urlTextField.stringValue = url.absoluteString
            updateViewSourceButtonVisibility(for: url)
            UserDefaults.standard.set(url.absoluteString, forKey: "browserPane.\(paneID.uuidString).url")
        }
        // Update tab title
        if let idx = tabs.firstIndex(where: { $0.webView === webView }) {
            let title = webView.title ?? webView.url?.host ?? "Tab"
            tabs[idx].title = String(title.prefix(20))
            refreshTabBar()
        }
        applyWebDarkMode()
        // The nested-iframe scroll fix (kickCompositorRelayout) is driven by the in-frame
        // pointer-move signal, not from here — a blind post-load timer raced the iframe's
        // async mount and mis-fired before its scrollable content existed.
        completeLoading()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateReloadStopButton(isLoading: false)
        showErrorBanner(message: error.localizedDescription)
        startRetryIfConnectionError(error)
        completeLoading(error: error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateReloadStopButton(isLoading: false)
        showErrorBanner(message: error.localizedDescription)
        startRetryIfConnectionError(error)
        completeLoading(error: error)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showErrorBanner(message: "Page crashed, reloading…")
        webView.reload()
    }
}

extension BrowserPaneView: WKUIDelegate {
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let url = navigationAction.request.url ?? URL(string: "about:blank")!
        // Must return the created view (not nil) — returning nil cancels window.open() at the
        // JS level, leaving window.opener unset in the new tab. OAuth popups (Google GSI's
        // gsi_transform relay page, and similar) rely on window.opener.postMessage(...) followed
        // by window.close() to hand the session back and dismiss themselves.
        // skipLoad: true — WKWebView loads navigationAction.request into the returned view
        // automatically; loading it again ourselves would sever the window.opener link.
        return createTab(url: url, configuration: configuration, skipLoad: true)
    }

    public func webViewDidClose(_ webView: WKWebView) {
        if let idx = tabs.firstIndex(where: { $0.webView === webView }) {
            closeTab(at: idx)
        }
    }
}

// MARK: - Registry Definition

@MainActor
public final class BrowserPaneRegistry {
    public static let shared = BrowserPaneRegistry()
    private var panes: [PaneID: WeakBrowserPaneView] = [:]
    private var warmPool: [WKWebView] = []

    private struct WeakBrowserPaneView {
        weak var view: BrowserPaneView?
    }

    /// Pre-create a WKWebView so the first browser open is instant.
    public func prewarm() {
        guard warmPool.isEmpty else { return }
        let config = WKWebViewConfiguration()
        config.limitsNavigationsToAppBoundDomains = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsMagnification = true
        web.allowsBackForwardNavigationGestures = true
        web.customUserAgent = BrowserPaneView.desktopSafariUserAgent
#if DEBUG
        web.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
#endif
        warmPool.append(web)
    }

    /// Dequeue a pre-warmed WKWebView, or nil if pool is empty.
    public func dequeueWarmedWebView() -> WKWebView? {
        warmPool.isEmpty ? nil : warmPool.removeFirst()
    }

    public func register(_ view: BrowserPaneView) {
        panes[view.paneID] = WeakBrowserPaneView(view: view)
    }

    public func unregister(_ paneID: PaneID) {
        panes.removeValue(forKey: paneID)
    }

    public func get(_ paneID: PaneID) -> BrowserPaneView? {
        return panes[paneID]?.view
    }
}

private final class LoadCompletionState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCompleted = false

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func complete(error: Error? = nil) {
        lock.lock()
        defer { lock.unlock() }
        guard !isCompleted else { return }
        isCompleted = true
        if let error = error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: ())
        }
        continuation = nil
    }
}

// MARK: - Browser Tab Button

@MainActor
private final class BrowserTabButton: NSView {
    private let label = NSTextField(labelWithString: "")
    private let closeBtn = SoftIconButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
    private var onSelect: () -> Void
    private var onClose: () -> Void

    init(title: String, isActive: Bool, onSelect: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onClose = onClose
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = isActive
            ? KouenDesign.chrome.surfaceElevated.cgColor
            : NSColor.clear.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = title.isEmpty ? "New Tab" : title
        label.font = .systemFont(ofSize: 11.5, weight: .regular)
        label.textColor = isActive ? KouenDesign.chrome.textPrimary : KouenDesign.chrome.textSecondary
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        closeBtn.setSymbol("xmark", accessibilityDescription: "Close Tab", pointSize: 8, weight: .semibold)
        closeBtn.target = self
        closeBtn.action = #selector(closeTapped)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(closeBtn)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            widthAnchor.constraint(lessThanOrEqualToConstant: 180),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: closeBtn.leadingAnchor, constant: -4),
            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 20),
            closeBtn.heightAnchor.constraint(equalToConstant: 20),
        ])

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if closeBtn.frame.contains(loc) {
            onClose()
        } else {
            onSelect()
        }
    }

    @objc private func closeTapped() {
        NSLog("BROWSER_DEBUG: closeTapped fired")
        onClose()
    }
}

// MARK: - Progress bar

@MainActor
private final class BrowserProgressLine: NSView {
    private let fill = NSView()
    private var fillWidth: NSLayoutConstraint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        fill.wantsLayer = true
        fill.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        let widthConstraint = fill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth = widthConstraint
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthConstraint,
        ])
        alphaValue = 0
    }
    required init?(coder: NSCoder) { fatalError() }

    func setProgress(_ progress: Double, isLoading: Bool) {
        let w = bounds.width > 0 ? bounds.width : superview?.bounds.width ?? 400
        let target = w * CGFloat(min(max(progress, 0), 1))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            fillWidth?.animator().constant = target
        }
        if isLoading {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                self.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                fillWidth?.animator().constant = w
            }, completionHandler: {
                Task { @MainActor in
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.25
                        self.animator().alphaValue = 0
                    }
                    self.fillWidth?.constant = 0
                }
            })
        }
    }
}

extension BrowserPaneView: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "kouenCompositorKick" {
            if let wv = message.webView { kickCompositorRelayout(for: wv) }
            return
        }
        guard let body = message.body as? [String: Any],
              let level = body["level"] as? String,
              let text = body["message"] as? String else {
            return
        }
        
        let logLine = "[\(level.uppercased())] \(text)"
        
        // Cap in-memory array
        if consoleLogs.count >= 200 {
            consoleLogs.removeFirst()
        }
        consoleLogs.append(logLine)
        
        // Batch file writes — throttle to avoid spawning a work item per console.log
        pendingLogLines.append(logLine)
        guard !logWriteScheduled else { return }
        logWriteScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.logWriteScheduled = false
            let batch = self.pendingLogLines
            self.pendingLogLines.removeAll(keepingCapacity: true)
            let logPath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("kouen-browser-\(self.paneID.uuidString).log")
            DispatchQueue.global(qos: .utility).async {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                let ts = df.string(from: Date())
                let lines = batch.map { "[\(ts)] \($0)\n" }.joined()
                guard let data = lines.data(using: .utf8) else { return }
                let url = URL(fileURLWithPath: logPath)
                if let fh = try? FileHandle(forWritingTo: url) {
                    defer { try? fh.close() }
                    _ = try? fh.seekToEnd()
                    _ = try? fh.write(contentsOf: data)
                } else {
                    _ = try? data.write(to: url, options: .atomic)
                }
            }
        }
    }
}

@MainActor
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var handler: WKScriptMessageHandler?

    init(_ handler: WKScriptMessageHandler) {
        self.handler = handler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?.userContentController(userContentController, didReceive: message)
    }
}
