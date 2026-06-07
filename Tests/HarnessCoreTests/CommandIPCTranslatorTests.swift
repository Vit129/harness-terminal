import XCTest
@testable import HarnessCore

/// The shared `Command` → `[IPCRequest]` mapping. The split-direction inversion
/// is the correctness-critical bit (a divider-orientation `Command.SplitDirection`
/// vs. the layout `SplitDirection` the daemon stores) — a regression here silently
/// rotated GUI splits 90°, so it is pinned by tests.
final class CommandIPCTranslatorTests: XCTestCase {
    /// Build a one-workspace/one-session/one-tab snapshot with a known active pane.
    private func makeTarget(splitOnce: Bool = false) throws -> (CommandTarget, TabID, PaneID) {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        var tab = try XCTUnwrap(ws.activeTab)
        var activePane = try XCTUnwrap(tab.rootPane.allPaneIDs().first)
        if splitOnce {
            activePane = try XCTUnwrap(editor.splitPane(in: ws.id, tabID: tab.id, paneID: activePane, direction: .horizontal))
            tab = try XCTUnwrap(editor.snapshot.activeWorkspace?.activeTab)
        }
        let target = CommandTarget(snapshot: editor.snapshot)
        return (target, tab.id, activePane)
    }

    func testSplitDirectionIsInverted() throws {
        // `.vertical` command (a vertical divider → side by side) must map to the
        // layout `.horizontal`; `.horizontal` command → layout `.vertical`.
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(for: .vertical), .horizontal)
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(for: .horizontal), .vertical)

        let (target, tabID, paneID) = try makeTarget()
        guard case let .requests(requests) = CommandIPCTranslator.translate(.splitWindow(direction: .vertical), target: target),
              case let .newSplit(reqTab, reqPane, direction, shell) = requests.first
        else { return XCTFail("expected a newSplit request") }
        XCTAssertEqual(reqTab, tabID)
        XCTAssertEqual(reqPane, paneID)
        XCTAssertEqual(direction, .horizontal, "side-by-side command splits side-by-side in the layout")
        XCTAssertNil(shell)
    }

    func testTargetlessKillResolvesActivePane() throws {
        let (target, _, paneID) = try makeTarget()
        guard case let .requests(requests) = CommandIPCTranslator.translate(.killPane, target: target),
              case let .killPane(reqPane) = requests.first
        else { return XCTFail("expected killPane") }
        XCTAssertEqual(reqPane, paneID)
    }

    func testSelectPaneNextResolvesToSibling() throws {
        let (target, tabID, activePane) = try makeTarget(splitOnce: true)
        // After one split the focused pane is the new one; `next` selects the other.
        guard case let .requests(requests) = CommandIPCTranslator.translate(.selectPane(target: .next), target: target),
              case let .selectPane(reqTab, reqPane) = requests.first
        else { return XCTFail("expected selectPane") }
        XCTAssertEqual(reqTab, tabID)
        XCTAssertNotEqual(reqPane, activePane, "next moves off the active pane")
        XCTAssertTrue(target.paneOrder.contains(reqPane), "selects a real pane in the tab")
    }

    func testDirectionalSelectIsSingleRequest() throws {
        let (target, _, paneID) = try makeTarget(splitOnce: true)
        guard case let .requests(requests) = CommandIPCTranslator.translate(.selectPane(target: .left), target: target),
              case let .selectPaneDirectional(current, axis) = requests.first
        else { return XCTFail("expected selectPaneDirectional") }
        XCTAssertEqual(current, paneID == target.paneID ? paneID : target.paneID)
        XCTAssertEqual(axis, .left)
    }

    func testJoinPaneRequiresMarkedPane() throws {
        let (target, _, _) = try makeTarget(splitOnce: true)
        // No marked pane → unresolved.
        if case .unresolved = CommandIPCTranslator.translate(.joinPane(direction: .vertical), target: target) {
            // expected
        } else {
            XCTFail("join-pane with no marked pane should be unresolved")
        }
    }

    func testTargetedKillResolvesWindowByIndex() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        let tab1 = try XCTUnwrap(ws.activeSession?.tabs.first)
        let tab1Pane = try XCTUnwrap(tab1.rootPane.allPaneIDs().first)
        _ = try XCTUnwrap(editor.addTab(to: ws.id))  // active is now the 2nd tab
        let target = CommandTarget(snapshot: editor.snapshot)

        // `-t :0` targets the first window even though the 2nd is active.
        let spec = TargetSpec(window: .byIndex(0), raw: ":0")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(.targeted(spec, .killPane), target: target),
              case let .killPane(pane) = reqs.first
        else { return XCTFail("expected killPane on the targeted window") }
        XCTAssertEqual(pane, tab1Pane)
    }

    // MARK: - Config / buffer / hook verbs

    /// A scoped set without -T resolves the target from the focus chain (tmux behavior —
    /// the CLI form requires -T because it has no focus to fall back on).
    func testSetOptionResolvesScopedTargetFromFocus() throws {
        let (target, tabID, paneID) = try makeTarget()
        guard case let .requests(reqs) = CommandIPCTranslator.translate(
            .setOption(scope: "tab", target: nil, key: "automatic-rename", rawValue: "off"), target: target),
            case let .setOption(scope, resolvedTarget, key, rawValue) = reqs.first
        else { return XCTFail("expected setOption") }
        XCTAssertEqual(scope, "tab")
        XCTAssertEqual(resolvedTarget, tabID.uuidString)
        XCTAssertEqual(key, "automatic-rename")
        XCTAssertEqual(rawValue, "off")

        guard case let .requests(paneReqs) = CommandIPCTranslator.translate(
            .setOption(scope: "pane", target: nil, key: "x", rawValue: "1"), target: target),
            case let .setOption(_, paneTarget, _, _) = paneReqs.first
        else { return XCTFail("expected setOption") }
        XCTAssertEqual(paneTarget, paneID.uuidString)

        // Global needs no target; an explicit -T wins over the focus chain.
        guard case .requests = CommandIPCTranslator.translate(
            .setOption(scope: "global", target: nil, key: "status", rawValue: "off"), target: target)
        else { return XCTFail("global set must translate") }
        guard case let .requests(explicit) = CommandIPCTranslator.translate(
            .setOption(scope: "tab", target: "abc", key: "k", rawValue: "v"), target: target),
            case let .setOption(_, explicitTarget, _, _) = explicit.first
        else { return XCTFail("expected setOption") }
        XCTAssertEqual(explicitTarget, "abc")
    }

    func testEnvironmentBufferAndHookVerbsTranslate() throws {
        let (target, _, paneID) = try makeTarget()

        guard case let .requests(env) = CommandIPCTranslator.translate(
            .setEnvironment(global: false, key: "EDITOR", value: "vim"), target: target),
            case let .setEnvironment(sessionID, key, value) = env.first
        else { return XCTFail("expected setEnvironment") }
        XCTAssertEqual(sessionID, target.session?.id, "non-global writes the focused session")
        XCTAssertEqual(key, "EDITOR")
        XCTAssertEqual(value, "vim")

        guard case let .requests(paste) = CommandIPCTranslator.translate(
            .pasteBuffer(name: "notes"), target: target),
            case let .pasteBuffer(surfaceID, name, bracketed) = paste.first
        else { return XCTFail("expected pasteBuffer") }
        XCTAssertEqual(surfaceID, target.surfaceID(of: paneID))
        XCTAssertEqual(name, "notes")
        XCTAssertTrue(bracketed)

        guard case let .requests(hook) = CommandIPCTranslator.translate(
            .setHook(event: "after-new-tab", source: "display-message hi", condition: nil), target: target),
            case let .bindHook(event, source, _) = hook.first
        else { return XCTFail("expected bindHook") }
        XCTAssertEqual(event, "after-new-tab")
        XCTAssertEqual(source, "display-message hi")
    }

    /// Show verbs are client-local: they produce output each front-end renders itself.
    func testShowVerbsAreClientLocal() throws {
        let (target, _, _) = try makeTarget()
        for command: Command in [
            .showOptions(scope: nil), .showEnvironment(global: true),
            .listBuffers, .showBuffer(name: nil), .showHooks(event: nil),
        ] {
            guard case .clientLocal = CommandIPCTranslator.translate(command, target: target) else {
                return XCTFail("\(command.shortDescription) must be clientLocal")
            }
        }
    }

    /// tmux `swap-pane -t X`: swap the CALLER's active pane with X — not X with X's
    /// own neighbor (which is what falling through to the relative translation against
    /// the resolved target would do).
    func testTargetedSwapPaneSwapsActiveWithResolved() throws {
        let (target, _, activePane) = try makeTarget(splitOnce: true)
        let other = try XCTUnwrap(target.paneOrder.first { $0 != activePane })

        let spec = TargetSpec(pane: .byID(other), raw: "%\(other.uuidString)")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(
            .targeted(spec, .swapPane(target: .next, source: nil)), target: target),
            case let .swapPanes(src, dst) = reqs.first
        else { return XCTFail("expected swapPanes") }
        XCTAssertEqual(src, activePane, "source is the caller's active pane")
        XCTAssertEqual(dst, other, "destination is the resolved -t pane")
    }

    /// Swapping a pane with itself (target resolves to the active pane) is unresolved,
    /// and so is a target that names nothing — never a silent wrong-pane swap.
    func testTargetedSwapPaneRejectsSelfAndUnresolvable() throws {
        let (target, _, activePane) = try makeTarget(splitOnce: true)
        let selfSpec = TargetSpec(pane: .byID(activePane), raw: "%\(activePane.uuidString)")
        guard case .unresolved = CommandIPCTranslator.translate(
            .targeted(selfSpec, .swapPane(target: .next, source: nil)), target: target)
        else { return XCTFail("self-swap must be unresolved") }

        let missing = TargetSpec(session: .byName("bogus"), raw: "bogus")
        guard case .unresolved = CommandIPCTranslator.translate(
            .targeted(missing, .swapPane(target: .next, source: nil)), target: target)
        else { return XCTFail("unknown session must be unresolved") }
    }

    /// `select-pane -t %id` resolves absolutely (the existing `.targeted(.selectPane)` path
    /// the parser now reaches for any absolute target).
    func testTargetedSelectPaneResolvesAbsolutely() throws {
        let (target, tabID, activePane) = try makeTarget(splitOnce: true)
        let other = try XCTUnwrap(target.paneOrder.first { $0 != activePane })
        let spec = TargetSpec(pane: .byID(other), raw: "%\(other.uuidString)")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(
            .targeted(spec, .selectPane(target: .next)), target: target),
            case let .selectPane(reqTab, reqPane) = reqs.first
        else { return XCTFail("expected selectPane") }
        XCTAssertEqual(reqTab, tabID)
        XCTAssertEqual(reqPane, other)
    }

    /// A level-ambiguous `{top}` rides `bareToken` and resolves at the pane level for a
    /// pane-kind command — the full grammar path the parser now reaches for select-pane.
    func testTargetedSelectPaneResolvesGeometryBareToken() throws {
        let (target, tabID, _) = try makeTarget(splitOnce: true)
        let spec = TargetSpec.parse("{top}")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(
            .targeted(spec, .selectPane(target: .next)), target: target),
            case let .selectPane(reqTab, reqPane) = reqs.first
        else { return XCTFail("expected selectPane for {top}") }
        XCTAssertEqual(reqTab, tabID)
        XCTAssertTrue(target.paneOrder.contains(reqPane))
    }

    /// STRICT resolution applies to EVERY targeted verb, not just select/swap: a `-t`
    /// naming a missing session/window/pane makes destructive verbs `.unresolved`
    /// instead of silently acting on the caller's focus (the v1.7.1 misroute class —
    /// pre-fix, `kill-pane -t bogus` killed the CURRENT pane).
    func testTargetedVerbsRejectUnresolvableTargets() throws {
        let (target, _, _) = try makeTarget(splitOnce: true)
        let badSession = TargetSpec(session: .byName("bogus"), raw: "bogus:")
        let badWindow = TargetSpec(window: .byIndex(99), raw: ":99")
        let badPane = TargetSpec(pane: .byID(UUID()), raw: "%ghost")
        for (spec, inner): (TargetSpec, Command) in [
            (badSession, .killPane), (badWindow, .killPane), (badPane, .killPane),
            (badSession, .killWindow), (badWindow, .killWindow),
            (badPane, .selectPane(target: .next)),
            (badWindow, .selectWindow(index: 99)),
        ] {
            guard case .unresolved = CommandIPCTranslator.translate(.targeted(spec, inner), target: target) else {
                return XCTFail("\(inner.shortDescription) -t \(spec.raw) must be unresolved, not act on focus")
            }
        }
    }

    /// `swap-pane -s X -t Y` swaps X with Y (neither needs to be the active pane);
    /// `-s X` alone swaps X with the current pane; an unresolvable `-s` is loud.
    func testSwapPaneSourceFlagResolves() throws {
        let (target, _, activePane) = try makeTarget(splitOnce: true)
        let other = try XCTUnwrap(target.paneOrder.first { $0 != activePane })

        // -s other (no -t): swap other with the CURRENT pane.
        let sourceSpec = TargetSpec(pane: .byID(other), raw: "%\(other.uuidString)")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(
            .swapPane(target: .current, source: sourceSpec), target: target),
            case let .swapPanes(src, dst) = reqs.first
        else { return XCTFail("expected swapPanes for -s") }
        XCTAssertEqual(src, other, "source is the -s pane")
        XCTAssertEqual(dst, activePane, "destination defaults to the current pane")

        // -s with a -t destination: swap the two named panes.
        let dstSpec = TargetSpec(pane: .byID(activePane), raw: "%\(activePane.uuidString)")
        guard case let .requests(reqs2) = CommandIPCTranslator.translate(
            .targeted(dstSpec, .swapPane(target: .next, source: sourceSpec)), target: target),
            case let .swapPanes(src2, dst2) = reqs2.first
        else { return XCTFail("expected swapPanes for -s + -t") }
        XCTAssertEqual(src2, other)
        XCTAssertEqual(dst2, activePane)

        // Unresolvable -s never silently swaps the focused pane.
        let ghost = TargetSpec(pane: .byID(UUID()), raw: "%ghost")
        guard case .unresolved = CommandIPCTranslator.translate(
            .swapPane(target: .current, source: ghost), target: target)
        else { return XCTFail("unresolvable -s must be unresolved") }
    }

    func testTargetedHonorsBaseIndex() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        let tab1 = try XCTUnwrap(ws.activeSession?.tabs.first)
        let tab1Pane = try XCTUnwrap(tab1.rootPane.allPaneIDs().first)
        _ = try XCTUnwrap(editor.addTab(to: ws.id))
        let target = CommandTarget(snapshot: editor.snapshot)

        // With base-index 1, window "1" is the first window (array position 0).
        let spec = TargetSpec(window: .byIndex(1), raw: ":1")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(.targeted(spec, .killPane), target: target, baseIndex: 1),
              case let .killPane(pane) = reqs.first
        else { return XCTFail("expected killPane") }
        XCTAssertEqual(pane, tab1Pane)
    }

    func testSelectWindowAppliesBaseIndexOffset() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        let firstTab = try XCTUnwrap(ws.activeSession?.tabs.first)
        _ = try XCTUnwrap(editor.addTab(to: ws.id))
        let target = CommandTarget(snapshot: editor.snapshot)

        guard case let .requests(reqs) = CommandIPCTranslator.translate(.selectWindow(index: 1), target: target, baseIndex: 1),
              case let .selectTab(_, tabID) = reqs.first
        else { return XCTFail("expected selectTab") }
        XCTAssertEqual(tabID, firstTab.id, "window 1 under base-index 1 is the first tab")
    }

    func testMovePaneResolvesToJoin() throws {
        let (target, _, _) = try makeTarget(splitOnce: true)
        let firstPane = try XCTUnwrap(target.paneOrder.first)
        let active = try XCTUnwrap(target.paneID)
        let spec = TargetSpec(pane: .byIndex(0), raw: ".0")
        guard case let .requests(reqs) = CommandIPCTranslator.translate(.movePane(direction: .vertical, source: spec), target: target),
              case let .joinPane(src, dst, _) = reqs.first
        else { return XCTFail("expected joinPane from move-pane") }
        XCTAssertEqual(src, firstPane)
        XCTAssertEqual(dst, active)
    }

    func testRenumberWindowsResolvesSession() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        let session = try XCTUnwrap(ws.activeSession)
        _ = try XCTUnwrap(editor.addTab(to: ws.id))
        let target = CommandTarget(snapshot: editor.snapshot)
        guard case let .requests(reqs) = CommandIPCTranslator.translate(.renumberWindows, target: target),
              case let .renumberWindows(sid) = reqs.first
        else { return XCTFail("expected renumberWindows") }
        XCTAssertEqual(sid, session.id)
    }

    func testRenumberWindowsCompactsSortOrder() throws {
        var editor = SessionEditor()
        let ws = try XCTUnwrap(editor.snapshot.activeWorkspace)
        _ = try XCTUnwrap(editor.addTab(to: ws.id))
        _ = try XCTUnwrap(editor.addTab(to: ws.id))
        let session = try XCTUnwrap(editor.snapshot.activeWorkspace?.activeSession)
        XCTAssertTrue(editor.renumberWindows(sessionID: session.id))
        let tabs = try XCTUnwrap(editor.snapshot.activeWorkspace?.activeSession?.tabs)
            .sorted { $0.sortOrder < $1.sortOrder }
        for (i, tab) in tabs.enumerated() { XCTAssertEqual(tab.sortOrder, i) }
    }

    func testClientLocalVerbsAreNotIPC() throws {
        let (target, _, _) = try makeTarget()
        for command: Command in [.copyMode, .detachClient, .displayPanes, .showCheatsheet] {
            guard case .clientLocal = CommandIPCTranslator.translate(command, target: target) else {
                return XCTFail("\(command.shortDescription) should be client-local")
            }
        }
    }
}
