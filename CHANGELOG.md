# Changelog

All notable changes to Kouen are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Kouen follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each released version
has a matching `vX.Y.Z` tag and a signed, notarized DMG on
[GitHub Releases](https://github.com/Vit129/kouen-terminal/releases).
## [4.11.0] - 2026-08-09

### Added
- Add Claude Code CLI subprocess harness (kouenCCRun/kouenCCStatus) ([`c5f37e2`](https://github.com/Vit129/kouen-terminal/commit/c5f37e204dbc0e8a0c8e640e79f319abb025055f))

### Documentation
- Resolve M2-M9 competitive gaps to Closed, add M2-M9 feature matrix ([`ba1b713`](https://github.com/Vit129/kouen-terminal/commit/ba1b71305ddb606aa161e320016e38d992031a29))

### Fixed
- Bump ipcProtocolVersion so M2/M5's new IPC cases force a daemon restart ([`3ec755f`](https://github.com/Vit129/kouen-terminal/commit/3ec755ff5f4ab485d07ed02e12bf9d1b260d1246))

## [4.10.0] - 2026-08-06

### Added
- Select all URL text on click ([`758481b`](https://github.com/Vit129/kouen-terminal/commit/758481b7a5888ab0e8acfa382d7dd35dde5e4526))
- Add AgentRoutingRule model for agent:"auto" spawn-time CLI routing ([`9273a62`](https://github.com/Vit129/kouen-terminal/commit/9273a627c0690cd38303c304f7a9b76d592091f4))
- Add AgentRoutingRuleStore persistence for routing rules ([`85b6702`](https://github.com/Vit129/kouen-terminal/commit/85b6702695adbaf67dae21af31968aad3f452de1))
- Add AgentRoutingResolver, first-match rule resolution to AgentKind ([`653d0b5`](https://github.com/Vit129/kouen-terminal/commit/653d0b5bc9ead8de08fa03c568dd8ccfaad8fe6e))
- Add IPC-safe AgentRoutingRuleSummary type ([`72ee1ca`](https://github.com/Vit129/kouen-terminal/commit/72ee1cabab9edf0150d26195119826fb35ae51bb))
- Add defaultAgentKind fallback for unmatched auto-routing ([`a981c64`](https://github.com/Vit129/kouen-terminal/commit/a981c6495329a75dac61727ec26ec08fed7829f2))
- Gate routing-rule mutate tools behind MCP control policy ([`f7347ed`](https://github.com/Vit129/kouen-terminal/commit/f7347edd6574abd712479d0212a288b4918bd1e6))
- Register kouenRoutingRule* MCP tools ([`39c19fa`](https://github.com/Vit129/kouen-terminal/commit/39c19fa9fd22036424dec0f241179c12bc5d6f70))
- Resolve agent:"auto" via routing rules in kouenSpawnAgent ([`87c99e7`](https://github.com/Vit129/kouen-terminal/commit/87c99e7c327fbdaf6265c17f1952f63b5c0ac884))
- Add routing-rule and saved-layout IPC request/response cases ([`1cf3d4a`](https://github.com/Vit129/kouen-terminal/commit/1cf3d4a62248715b020b5aa6df5c0625b2fee68e))
- Wire AgentRoutingRuleStore and SavedLayoutStore into the daemon ([`764fa60`](https://github.com/Vit129/kouen-terminal/commit/764fa60b7299b4ad35acf06f6696f243482ec258))
- Add agent-routing-rules.json and saved-layouts.json paths ([`286a26c`](https://github.com/Vit129/kouen-terminal/commit/286a26c9f888d47901436496856f4eec0fdadd7f))
- Add browser design mode — hover-highlight, click-select, style preview, Copy CSS ([`d6346ba`](https://github.com/Vit129/kouen-terminal/commit/d6346baa8b4224e46b86ec95b77d9e1384e19d19))
- Add SavedLayout/PaneLayoutShape model, distinct from LayoutTemplate ([`5c6c96e`](https://github.com/Vit129/kouen-terminal/commit/5c6c96e8281692c31e03937f603067ce4fce27ee))
- Add IPC-safe SavedLayout type ([`e768dea`](https://github.com/Vit129/kouen-terminal/commit/e768dea3423d75369c0df56916e000ff4aa00f22))
- Apply saved layout shape via recursive client-side split ([`bf98703`](https://github.com/Vit129/kouen-terminal/commit/bf987036b46faeffffa795299c0fa5246963cb68))
- Add RiskyCommandClassifier regex heuristic for risky-shell-command detection ([`f3f3dbd`](https://github.com/Vit129/kouen-terminal/commit/f3f3dbd89341ec680fe89520fd318a3983219ceb))
- Saved-layout facade methods + risky-command advisory toast on command finish ([`e99d26b`](https://github.com/Vit129/kouen-terminal/commit/e99d26b918c6f3da674afa427e13c4c4c80454c9))
- Add Fork Conversation, Save/Apply Layout, Request Peer Review menu actions ([`0909fb3`](https://github.com/Vit129/kouen-terminal/commit/0909fb3154689ae8015ab59ad786fa64423d11a4))
- Parse PR reviewDecision from gh CLI output ([`8a1d6fc`](https://github.com/Vit129/kouen-terminal/commit/8a1d6fceb9be6d535f3b005379d922b649557203))
- Thread prReviewDecision through RepoGitMetadata ([`6e9b5b6`](https://github.com/Vit129/kouen-terminal/commit/6e9b5b668c71981aa0c43be3cf4fdb3bd875cec7))
- Offer checks-waiver merge when PR is approved, never waive mergeable ([`1b1af54`](https://github.com/Vit129/kouen-terminal/commit/1b1af548e7799a598771f7785cced65ef9e539a8))
- Add slash-command discoverability picker; fix(composer): reassert typingAttributes before every keystroke, not just once, so typed text is never black ([`95c8f1c`](https://github.com/Vit129/kouen-terminal/commit/95c8f1cf16a438109dbd3aa2a73e27ac953fd0a7))

### Changed
- Drop Agents cross-repo review dashboard, redundant with Board+Worktrees ([`c9e6989`](https://github.com/Vit129/kouen-terminal/commit/c9e69896675b0214d898bda62236837acaf2a0fd))
- Drop selectAgentsTab notification handling, Agents tab removed ([`46da53b`](https://github.com/Vit129/kouen-terminal/commit/46da53bfce8c4527896612210b138208383a959f))
- Drop Review Agent Work action, Agents tab removed ([`dc44cc0`](https://github.com/Vit129/kouen-terminal/commit/dc44cc003c9663100942492eab338b3f8d1141d3))

### Documentation
- Migrate stale Claude Code auto-memory into portable agent-memory ([`8ce6b61`](https://github.com/Vit129/kouen-terminal/commit/8ce6b61d466be2316608464f5706c4a41a51db1b))
- Update parseWorktreePorcelain comment after Agents tab removal ([`d764b95`](https://github.com/Vit129/kouen-terminal/commit/d764b9502a6644dc05a3a209af9e4fdc6c88c1b8))
- Record Agents tab removal decision (redundant with Board/Worktrees, 2026-08-06) ([`c8208fc`](https://github.com/Vit129/kouen-terminal/commit/c8208fcaace55b0616bc628d173ee7f1a389eea5))
- Design doc — session-spawn CLI routing (scope-corrected from Warp's model router) ([`7dd1521`](https://github.com/Vit129/kouen-terminal/commit/7dd1521a48b0472c36c44eb33d389c0fdf3f9e75))
- Task progress — closed, build/test/robot green, live-check owed ([`8b09020`](https://github.com/Vit129/kouen-terminal/commit/8b09020af4abeef1e8420525bc0562360d0dd325))
- Design doc — visual-preview-only, no source-file round-trip (scope cut) ([`288641e`](https://github.com/Vit129/kouen-terminal/commit/288641e19872c09f54c91f5a07bab9f8790872b4))
- Task progress — closed, build/test/robot green, live-check owed ([`7c2d4f8`](https://github.com/Vit129/kouen-terminal/commit/7c2d4f82da806358947e62a5027eb3805ae44334))
- Task progress — closed, shape-only (no ratio/process restore) ([`59a5657`](https://github.com/Vit129/kouen-terminal/commit/59a5657e577f291dec28d3a6a020b9f03e4c0279))
- Task progress — closed, advisory-only (fires after command finishes) ([`85b1cfe`](https://github.com/Vit129/kouen-terminal/commit/85b1cfe63c68d132623685a9426f6b63502117f3))
- Design doc — reuses each CLI's own native fork flag, claude-code/codex only ([`88271cd`](https://github.com/Vit129/kouen-terminal/commit/88271cdaf6619472501936edfec457ece79a8164))
- Task progress — closed, build/test green, live-check owed ([`699b0ec`](https://github.com/Vit129/kouen-terminal/commit/699b0ec7dc952df796d520b76842b485771cbf23))
- Task progress — closed, human-triggered ask-only (no auto-capture/paste-back) ([`8cce333`](https://github.com/Vit129/kouen-terminal/commit/8cce3334f9522c916141543861e3132488bc9864))
- Task progress — closed, extends existing P39 G3 merge picker ([`d93237c`](https://github.com/Vit129/kouen-terminal/commit/d93237c9ffd68e899df1c207c3f6297189c84f2d))
- Task progress — closed, @file mention cut (documented, not built) ([`049d15e`](https://github.com/Vit129/kouen-terminal/commit/049d15e78c264fa9edeef0cff40c42a6503ecfd9))
- Define M2-M9 vocabulary (Agent Routing Rule, Design Mode, Fork Conversation, Saved Layout, Risky Command Advisory, Request Peer Review, Merge Waiver, Slash Command Picker) ([`eacf7c5`](https://github.com/Vit129/kouen-terminal/commit/eacf7c5f7100d90cf180a6d448af30e1081cedc4))
- Wayfinder map — M2-M9 competitive-gap features, all 8 tickets closed 2026-08-05 ([`1a003ac`](https://github.com/Vit129/kouen-terminal/commit/1a003acb317a9e39b994974350cfcafa13fedf4a))
- Record user approval to build all 8 M2-M9 gaps despite no per-feature usage signal ([`dda8086`](https://github.com/Vit129/kouen-terminal/commit/dda8086430177a515c8cfcfa82f5da4b245cd892))
- Index M2-M9 plan files and wayfinder map ([`3bf851f`](https://github.com/Vit129/kouen-terminal/commit/3bf851f5dc029a5042e2755d5df5c574627e522d))
- Index m2-m9-competitive-build-decision and agents-tab-removed memory files ([`6f3f08b`](https://github.com/Vit129/kouen-terminal/commit/6f3f08b499467e706187f8c1088267582f7182e8))
- Flag broken [[review-new-features-against-lessons]] link for follow-up ([`9368729`](https://github.com/Vit129/kouen-terminal/commit/936872913988e07a0087cb49395c70cf99c6435f))
- Flag broken [[feedback_review-new-features-against-lessons]] link for follow-up ([`669858b`](https://github.com/Vit129/kouen-terminal/commit/669858bc37d970320492e50583566f2125e602ff))
- Record 2026-08-02 scheduled memory-maintenance run results ([`f505e96`](https://github.com/Vit129/kouen-terminal/commit/f505e9664ad398f2a8e210ab4863f72d91f877b9))
- Open gate for kouen-browser-mcp-intermittent-unresponsive investigation ([`a712142`](https://github.com/Vit129/kouen-terminal/commit/a7121424a089b288aecc3975fc7766f029c0cb7f))
- Forbid nested git worktrees inside .kouen-worktrees/ ([`b2c2ae8`](https://github.com/Vit129/kouen-terminal/commit/b2c2ae8139a9943c89df8a8ed43b0133d23f0043))

### Fixed
- Guard stale file-tree scan from clobbering active session's root ([`3b7b78e`](https://github.com/Vit129/kouen-terminal/commit/3b7b78ec6cbc9d42fc7f30cee8a513fd8a393a39))

## [4.9.3] - 2026-07-31

### Fixed
- Reload board columns on metadata-only snapshot pushes (release v4.9.3) ([`42ee2f8`](https://github.com/Vit129/kouen-terminal/commit/42ee2f8c0d066fecc6ef63bde4a25b4786bb657c))

## [4.9.2] - 2026-07-29

### Fixed
- Clamp persisted sidebar width so Cmd+\ toggle can't get stuck at zero-delta (release v4.9.2) ([`ffe984d`](https://github.com/Vit129/kouen-terminal/commit/ffe984d53d59e372111f14825af499cd0f776b1e))

## [4.9.1] - 2026-07-27

### Added
- AppIntents/Shortcuts (Phase 7), sidebar-width persistence (Phase 5) ([`da59c2a`](https://github.com/Vit129/kouen-terminal/commit/da59c2ae112f18cd628e645944845d1054ff8cce))

### Documentation
- Fix stale Phase 5 note, record why Phases 4/6/10/11/12 are deliberately deferred ([`1d3a227`](https://github.com/Vit129/kouen-terminal/commit/1d3a22705af90cc158449e4cc01819410dcd1c16))
- Close P8 and P37, archive completed plan docs ([`7beb315`](https://github.com/Vit129/kouen-terminal/commit/7beb315713a19cce21a081520f0d1e7b674cc5af))

### Fixed
- Resync GeneratedReleaseNotes.swift; test(notch): fix stale peek-size assertions ([`fa8a08c`](https://github.com/Vit129/kouen-terminal/commit/fa8a08cfd911a12352431751d170392c3547f26d))
- Prevent FSEventStream teardown race crash in FileTreeWatcher ([`e6d84f8`](https://github.com/Vit129/kouen-terminal/commit/e6d84f8f914297fc32de531fb3b4b814d85a2cb2))
- Resolve sidebar toggle window via NSApp.windows loop, not keyWindow chain ([`7d76e18`](https://github.com/Vit129/kouen-terminal/commit/7d76e18324fe1b3ba45e0304bc00d5b0eed77798))

## [4.9.0] - 2026-07-26

### Added
- Approve/deny, quick-reply, exact-pane jump, per-event sounds ([`d590786`](https://github.com/Vit129/kouen-terminal/commit/d59078689bc404f8e9bb9977176e3de2212f3fad))

### Fixed
- Restore Liquid Glass transparency pipeline and finish browser-pane chrome ([`157e5aa`](https://github.com/Vit129/kouen-terminal/commit/157e5aa6477ffa30540d6719bfb6d5f15474dd2b))
- Enable arrow-key line editing in release-pipeline prompts ([`cc60fc3`](https://github.com/Vit129/kouen-terminal/commit/cc60fc3484cd057b53052a8aff24c6499d2e24e2))
- Guard MobileBridgeServer reference for platforms without Network ([`9f7297f`](https://github.com/Vit129/kouen-terminal/commit/9f7297ff046b34daf8b613c50851153ca0cc2fbd))

## [4.8.0] - 2026-07-25

### Added
- Adopt macOS 27 plan additions and window quick wins ([`2ef888d`](https://github.com/Vit129/kouen-terminal/commit/2ef888d63b99b586e248ce154cc8f4d22c1a15d0))
- Add actionable notification category with Focus Pane, Rerun Command, and Copy Output ([`cf042ed`](https://github.com/Vit129/kouen-terminal/commit/cf042ed15488896c926e367c0a488a40ae1ec859))
- Make session row title semi-bold only when selected ([`1fbdacf`](https://github.com/Vit129/kouen-terminal/commit/1fbdacf82f54bdaacf5c50abaa0ffc72da7fd10e))
- Add ActivityAssertionManager to prevent App Nap during builds/agent runs ([`bfd5e09`](https://github.com/Vit129/kouen-terminal/commit/bfd5e09039f7e14ffd1b697f82548eec63650f30))
- Adopt NSViewCornerConfiguration and .containerConcentric on overlays ([`ea4b348`](https://github.com/Vit129/kouen-terminal/commit/ea4b34816b4ffd7d11f68591f756748f8a38980f))
- Support macOS27 beta 4 first version ([`4d2498b`](https://github.com/Vit129/kouen-terminal/commit/4d2498b8a52d40b5557fca26df1ca3924a287187))

### Documentation
- Add Scheduled Memory Maintenance Job term to LANGUAGE.md ([`42a2426`](https://github.com/Vit129/kouen-terminal/commit/42a242646c7a5593af175c1de21212f3acc1fa96))
- Rename LANGUAGE.md to GLOSSARY.md ([`4d3dc08`](https://github.com/Vit129/kouen-terminal/commit/4d3dc08e70823c9c9f275ac2ff6b1aeca44f791f))
- Record Xcode 27 beta compatibility findings for Phase 1 ([`edda070`](https://github.com/Vit129/kouen-terminal/commit/edda070866dd8dfd59cfe0a647b7e5bfa28422d7))

### Fixed
- Guard UNUserNotificationCenter calls when bundle identifier is nil ([`c6feec1`](https://github.com/Vit129/kouen-terminal/commit/c6feec186067b923027da0438fdc1d58a4127a7b))
- Safely handle UNUserNotificationCenter in xctest runner environment ([`861e959`](https://github.com/Vit129/kouen-terminal/commit/861e9592c7610dbf5f39f233f4672c736b41f3b7))
- Guard updateTrackingAreas against window==nil in TabOverviewController/ContentAreaViewController ([`9b5d2c2`](https://github.com/Vit129/kouen-terminal/commit/9b5d2c2ca81c85352f2b12c15815745bb5fe8b03))
- Replace unsafe MainActor.assumeIsolated with Task { @MainActor in } ([`82816f9`](https://github.com/Vit129/kouen-terminal/commit/82816f99abea3adf7a411056813f21ac2845fc73))

## [4.7.4] - 2026-07-23

### Fixed
- Stop daemon-side pane changes from being silently discarded while a browser pane is open (release v4.7.4) ([`6c14a8a`](https://github.com/Vit129/kouen-terminal/commit/6c14a8a7e96a98bb7b8832c23dd8380db208a1fd))

## [4.7.3] - 2026-07-23

### Fixed
- Raise daemon-routed git request timeout from 2s to 30s (fetch/pull/push were silently timing out on ordinary network latency) (release v4.7.3) ([`c6e8cf7`](https://github.com/Vit129/kouen-terminal/commit/c6e8cf72a71ada16249f3de8345766334930990c))

## [4.7.2] - 2026-07-23

### Added
- MAW-style merge validate gate + agent handoff surfacing (human review + agent-to-agent spawn seed) (release v4.7.2) ([`c788cf8`](https://github.com/Vit129/kouen-terminal/commit/c788cf8141cce3a64fe845ea3a9925c8813ad172))

## [4.7.1] - 2026-07-22

### Added
- Ghq-style wake command, signal-file agent routing, graphify LSP hover (release v4.7.0) ([`8280e1c`](https://github.com/Vit129/kouen-terminal/commit/8280e1cc3e9933a8b06e34ca2394ac2eff422e7c))

### Fixed
- Replace Harness placeholder logo with Kouen brand mark ([`60b749d`](https://github.com/Vit129/kouen-terminal/commit/60b749d8e5f9404f3273343fa97e42edb9ff0cd3))
- Closed notch pill no longer forced to a 100pt floor on non-notch Macs ([`a3cd3e3`](https://github.com/Vit129/kouen-terminal/commit/a3cd3e3916faaba9cf49c5fbb8a8f293571cff2f))
- Stop swallowing gh release create/edit errors in full-cycle.sh ([`3e0f86d`](https://github.com/Vit129/kouen-terminal/commit/3e0f86de8e5c0e6974c237dd68aabcc9a4d42b31))
- Guard release notes against GitHub's 125000-char body limit ([`33f4f7d`](https://github.com/Vit129/kouen-terminal/commit/33f4f7dca97b5f0600dceae4c117b2d21a6fa5ec))
- Browser pane always opens in the requesting session's own tab, not whichever tab is focused (release v4.7.1) ([`d712328`](https://github.com/Vit129/kouen-terminal/commit/d712328be65c5365d9752107f629d07e87e61e88))

## [4.6.1] - 2026-07-18

### Added
- Group Task Dashboard by project, auto-delete tasks on done ([`9c3053b`](https://github.com/Vit129/kouen-terminal/commit/9c3053bbfd86c4caf101fa8cbfb19c8b76d7f2b2))

### Fixed
- Emit task createdAt/updatedAt in UTC+7 instead of UTC ([`ddc1cad`](https://github.com/Vit129/kouen-terminal/commit/ddc1cad252706e8c8f3409d657cd2e798e099c99))
- Route markdown through syntax view, restore file preview copy/find (release v4.6.1) ([`f1d8dce`](https://github.com/Vit129/kouen-terminal/commit/f1d8dce7a08db32e55dffa0f5203a6d1541dbc13))

## [4.6.0] - 2026-07-17

### Added
- Dedupe open-tab repo roots into kouenProjectsList MCP tool (release v4.6.0) ([`b3cffa6`](https://github.com/Vit129/kouen-terminal/commit/b3cffa65a9d4c001dae8ecf47016e39c9bb9a217))

## [4.5.5] - 2026-07-16

### Fixed
- Forward arrow keys through doCommandBy when input routes via marked-text/IME (release v4.5.5) ([`7b335c0`](https://github.com/Vit129/kouen-terminal/commit/7b335c05f79d1f9e176e9ada644205d4f1074bad))

## [4.5.4] - 2026-07-16

### Fixed
- Restore path-insert as default terminal drop (⌥-drag opts into file preview) (release v4.5.4) ([`732491c`](https://github.com/Vit129/kouen-terminal/commit/732491ce8e3deb33667a1328134f9e7e3762c963))

## [4.5.3] - 2026-07-16

### Added
- Group Recipes & History picker by originating pane ([`266b74c`](https://github.com/Vit129/kouen-terminal/commit/266b74c349ce5b1995ec08dda419971cd3fc02a1))
- Add Codex MCP config support (config.toml, not JSON) ([`04a0e19`](https://github.com/Vit129/kouen-terminal/commit/04a0e197812f8e6b47dc4e6fdfc1f16724b6ff01))
- Add Antigravity (agy) Stop hook support ([`886ab94`](https://github.com/Vit129/kouen-terminal/commit/886ab9476a4404825ee359c2571c6fc656ff5f5e))
- Check for newer git-clone version at launch, confirm before pull ([#53](https://github.com/Vit129/kouen-terminal/pull/53)) ([`c23b715`](https://github.com/Vit129/kouen-terminal/commit/c23b7157610dd7fc2be0639ef2960fada7075d73))
- Drag-and-drop file support (terminal open-preview, sidebar copy-in) (release v4.5.3) ([`4becc8b`](https://github.com/Vit129/kouen-terminal/commit/4becc8b98ab6f02629b8e92aa5d23b34fe3254c1))

### Fixed
- Scope kouenBrowserOpen pane reuse to the target tab ([`7fbdd61`](https://github.com/Vit129/kouen-terminal/commit/7fbdd611edc1314f49b2990fcd4ee3e9e2df5ce6))
- Show checkmark when agent hooks are installed ([`3952882`](https://github.com/Vit129/kouen-terminal/commit/39528824012684c97a9114fb73a40b00b2d78dff))

## [4.5.1] - 2026-07-15

### Fixed
- Actually call WorktreeAutoIsolateService.shared.start() ([`6a3ebf9`](https://github.com/Vit129/kouen-terminal/commit/6a3ebf9c2aa7f49a6bd5467663362feb1412f776))

## [4.5.0] - 2026-07-15

### Added
- Subagent visibility badge on tab/sidebar (P38 Phase B) ([`1ff21c9`](https://github.com/Vit129/kouen-terminal/commit/1ff21c9c532e7942c4144285e2b5327c723740e6))
- Merge command-history into the Recipes picker (P38 Phase C) ([`463e161`](https://github.com/Vit129/kouen-terminal/commit/463e16115bb3b49c27457f6bc8e73852eb413679))
- Kitty Graphics protocol conformance slice (P38 Phase D) ([`b56cbe3`](https://github.com/Vit129/kouen-terminal/commit/b56cbe307941e1147f2d6e5b7ec1dabe3451603e))

### Documentation
- Update P38 status across all phases in plans index ([`6c61169`](https://github.com/Vit129/kouen-terminal/commit/6c61169529a208375c161dd490111fb38432fb4a))

### Fixed
- Dispatch paneCreated/paneRemoved lifecycle hooks (P38 Phase E) ([`e4c72cc`](https://github.com/Vit129/kouen-terminal/commit/e4c72cc0759453aa59552c75358aa54773353ed5))
- Auto-isolate background tabs, not just the focused one ([`da3a988`](https://github.com/Vit129/kouen-terminal/commit/da3a988c2ffd550f0906f3dc1a56eedb6b8766e3))

## [4.4.4] - 2026-07-14

### Fixed
- Switch panel view + tag worktreePath on click-to-worktree navigation (release v4.4.4) ([`c405a3a`](https://github.com/Vit129/kouen-terminal/commit/c405a3a19042e47188e7bb3cafdbac95ef0565aa))

## [4.4.3] - 2026-07-14

### Added
- Mobile terminal keyboard toolbar (Esc/Tab/Ctrl-C/Ctrl-D/arrows) ([`9c4706f`](https://github.com/Vit129/kouen-terminal/commit/9c4706f36bd8fa6101180a0aab4c1f979b23a8d5))
- Mobile terminal @ file-path autocomplete (P37 Phase G1) ([`3fcd94d`](https://github.com/Vit129/kouen-terminal/commit/3fcd94d1b82e32078393a493cfb765ebf91d3673))
- Mobile terminal shell tab-completion suggestion strip (P37 Phase G2) ([`26ab0d5`](https://github.com/Vit129/kouen-terminal/commit/26ab0d5e9ad9ec3830022d4edffd56b88ecfcc81))
- Mobile terminal AI command suggestion via claude CLI (P37 Phase G3) ([`ebc4e77`](https://github.com/Vit129/kouen-terminal/commit/ebc4e77be88e2d8765798c93277291c43dd3c424))
- Capture creating session's cwd on Kouen Task create ([`308f7df`](https://github.com/Vit129/kouen-terminal/commit/308f7df0da4269eaadd51aca0d1d1816ec5783e5))
- Add cross-repo Agents review dashboard + merge flow, fix worktree card navigation (release v4.4.3) ([`8ce31e3`](https://github.com/Vit129/kouen-terminal/commit/8ce31e3e92bf69857b4d24d6ef786df974236400))

### Documentation
- Record F2 keyboard toolbar shipped + F3 already-true in Phase F ([`de71279`](https://github.com/Vit129/kouen-terminal/commit/de71279aa61ee7196f7d6fbb8a05c40d96765115))
- Design + task breakdown for P37 Phase G (autocomplete) ([`b911803`](https://github.com/Vit129/kouen-terminal/commit/b9118032ad1a7f3ea27f87ec7b7fce4a285a9fa3))
- Defer P37 F5 (share-sheet upload) pending web-based mobile bridge completion ([`4909fad`](https://github.com/Vit129/kouen-terminal/commit/4909fad2509f077240eb879105819f5438b22841))
- Caveman-compress CLAUDE.md to cut input tokens ([`bdbe80c`](https://github.com/Vit129/kouen-terminal/commit/bdbe80c4104154c0ff037886861f86d03d958344))
- Record today's P39/P40 verification pass, refresh graphify ([`46e7508`](https://github.com/Vit129/kouen-terminal/commit/46e75083c82d216f560a72252fbb3db87b20b8fa))

### Fixed
- G3 newline auto-execute, pipe deadlock risk, stale AI suggestion state ([`a98c94a`](https://github.com/Vit129/kouen-terminal/commit/a98c94a86383967d9e34224163dbbbe4b0093ede))
- Cmd+\ sidebar toggle raced window's launch-time resize-to-real-size, causing stuck squeeze/black panel ([`3a047d0`](https://github.com/Vit129/kouen-terminal/commit/3a047d09e647821d1dcf2427af796f0cb884c883))
- Browser open reuses existing pane as new tab instead of splitting a second pane ([`0a421c8`](https://github.com/Vit129/kouen-terminal/commit/0a421c8bf93da44e022b12ba705d3dbf83bfaa7c))
- Mobile bridge terminal double-wrap on real phone width, upload picker no-op, add copy-path ([`1c24562`](https://github.com/Vit129/kouen-terminal/commit/1c2456209bda92e989dbbe99bcebd93a0b7902fc))
- Mobile bridge reconnect trusts a stale readyState and never retries an active drop (P37 F4) ([`54c5df8`](https://github.com/Vit129/kouen-terminal/commit/54c5df82cba5bddb13cd57b1227fb1c3e503f65d))

## [4.4.2] - 2026-07-13

### Added
- Mobile-triggered Mac window focus + protect native window from phone resize votes ([`43b8265`](https://github.com/Vit129/kouen-terminal/commit/43b826582b72dc1a52ddf150f2e65c06f3decadf))
- Mobile bridge readFile/listDirectory for read-only file preview (P37 Phase D1, server-side) ([`338f898`](https://github.com/Vit129/kouen-terminal/commit/338f898405d92b112a1cf9e9e47a5adbeaa5e13f))
- Mobile bridge file preview UI — files sheet + text/image preview view (P37 Phase D1, client-side) ([`2313885`](https://github.com/Vit129/kouen-terminal/commit/2313885e0a8de70d1e5b49d77e3929ad9513175d))
- Mobile bridge file/image attach (upload) — server + client (P37 Phase D2) ([`b3c03f9`](https://github.com/Vit129/kouen-terminal/commit/b3c03f9c9aa71bb726818a24017a4bfbc4e1b284))
- Mobile bridge browser mirror — navigate/snapshot/interact/screenshot (P37 Phase D3) ([`0c5cd26`](https://github.com/Vit129/kouen-terminal/commit/0c5cd2626f86ed4ad27538a9f47649efe0d15463))
- Mobile bridge unified preview tab-strip + tablet layout (P37 Phase E) ([`2f516b4`](https://github.com/Vit129/kouen-terminal/commit/2f516b4f4f1328dd5a9021cecacbefb200e9bb5a))

### Documentation
- Record second Opus review pass + fixes in Phase E task doc ([`7e095bf`](https://github.com/Vit129/kouen-terminal/commit/7e095bffcb1ffb2a5bc44a42688318d7635415a2))

### Fixed
- Browser interact used a different element list than snapshot, could click the wrong element ([`bdfbb0b`](https://github.com/Vit129/kouen-terminal/commit/bdfbb0b636f0250e326ee034a6bab29ba2f2eed4))
- Phase E's #term-empty leaked onto phone, browser back/forward/reload raced the page load ([`4a782d6`](https://github.com/Vit129/kouen-terminal/commit/4a782d699ceb9c20d973baac5546fea0f089db38))
- Resync sidebar-side layout when Settings toggles Sidebar-on-right, preventing stuck black panel on next Cmd+\ (release v4.4.2) ([`6ca22d8`](https://github.com/Vit129/kouen-terminal/commit/6ca22d8a884a067fc04b7b13447e9f76921eec29))

## [4.4.1] - 2026-07-12

### Added
- Reveal cat/view'd files in the sidebar file tree (OSC 7736) ([`4ae745a`](https://github.com/Vit129/kouen-terminal/commit/4ae745a57493f7f30017f7dfa969d06e1148de37))

### Fixed
- Copy-mode yank leaked kouen-cat line numbers past the SGR 73/74 exclude marker ([`4989bc0`](https://github.com/Vit129/kouen-terminal/commit/4989bc0ac5c664ba9326ff8aa6118dc0f60cb622))
- Mobile-created sessions register as real tabs so they show and stay selectable; enable iOS predictive text in mobile terminal (release v4.4.1) ([`ea1568b`](https://github.com/Vit129/kouen-terminal/commit/ea1568b6c28df8ba64522a503bf5fd263be025b9))

## [4.4.0] - 2026-07-11

### Added
- P39 competitive-gap closes — SSH agent forwarding, sidebar port badge, git hunk staging, in-app PR merge, fleet visibility badge ([`4e6549e`](https://github.com/Vit129/kouen-terminal/commit/4e6549e948b31bbc8589902da765d52c6fdd551a))
- Add Tasks/Worktree/Hosts MCP tools and Automations scheduler (release v5.0.0) ([`97180fd`](https://github.com/Vit129/kouen-terminal/commit/97180fd03897b155eec66f1c33024db6dca0d265))

### Fixed
- Reload MCP tool policy on every check, not once at construction ([`7678351`](https://github.com/Vit129/kouen-terminal/commit/7678351f8e715667de72a3a05a0f167317673410))
- Move Cmd+F find bar below pane's browser/split/close icon row ([`1d796a5`](https://github.com/Vit129/kouen-terminal/commit/1d796a5774ec5173fa4393ba2f72a5b89d6f815e))
- Mobile pairing rejected every real device because the token rotated out before connect ([`c8bd2bc`](https://github.com/Vit129/kouen-terminal/commit/c8bd2bc2d272fbec2e8afc3f6bd23ef7141002f8))
- Browser pane sends a real Safari UA so Google/Apple OAuth doesn't reject it ([`e955924`](https://github.com/Vit129/kouen-terminal/commit/e955924494f177336e1925ca17414e5c01c18e9f))
- Correct release to v4.4.0 (was mistakenly major-bumped) and scope kouenBrowserOpen to the calling agent's own session ([`eed2a9f`](https://github.com/Vit129/kouen-terminal/commit/eed2a9fd972c0de3e01fc50c398afc6472501361))

## [4.3.1] - 2026-07-10

### Fixed
- Stop worktree branch cache clobbering, silent terminal file-link failures, and uncapped git panel history (release v4.3.1) ([`a60766d`](https://github.com/Vit129/kouen-terminal/commit/a60766dc6e1a5822ff8dd954a0fc6d9ee30ec745))

## [4.3.0] - 2026-07-10

### Added
- Mobile bridge Settings toggle no longer restarts daemon + P37 Phase C real terminal client (release v4.3.0) ([`36d09db`](https://github.com/Vit129/kouen-terminal/commit/36d09db783b1bebdd633481a09849aab84313117))

## [4.2.0] - 2026-07-09

### Added
- P37 mobile-bridge hardening + S1 daemon-restart fix (release v4.2.0) ([`fb70d91`](https://github.com/Vit129/kouen-terminal/commit/fb70d91c02f4cc8239c58f5dd330c5e915971b6d))

## [4.1.0] - 2026-07-08

### Added
- Add QuickTerminalController, a visor-style ⌥Space terminal panel ([`c800173`](https://github.com/Vit129/kouen-terminal/commit/c800173bae53c4ace9967c270a1bdd3eda366dc2))
- Darken app icon green + add dark-mode Dock icon via runtime swap ([`7be5721`](https://github.com/Vit129/kouen-terminal/commit/7be572185b3bd60eeee37633b7740d6c03bb1c2b))
- P25 mobile pairing bridge — pairing MVP + production wiring (build 195) ([`97afd2e`](https://github.com/Vit129/kouen-terminal/commit/97afd2e48da2fd83e6697a590b42680fe10e5ab5))

### Documentation
- Add fork maintainer's copyright to LICENSE ([`c88785d`](https://github.com/Vit129/kouen-terminal/commit/c88785d55941b737638b796205f7d1ba9e5927c4))
- Update agent memory notes ([`c9d9736`](https://github.com/Vit129/kouen-terminal/commit/c9d9736d21f2422a5f07183e4929cef2b0815682))

### Fixed
- Bump CI's pinned Xcode from 16 to 26.5 to match the dev toolchain ([`4c494e0`](https://github.com/Vit129/kouen-terminal/commit/4c494e0111ffa8c4ce26beacb39fa1467ff6801f))
- Guard UserNotifications import for Linux headless daemon build ([`ae55714`](https://github.com/Vit129/kouen-terminal/commit/ae557146e1c5781fcf3727eca5e3f3f05e951eb1))
- Use the existing kouenStderr/new kouenStdout idiom in CLI install-tools/agent ([`56e5c35`](https://github.com/Vit129/kouen-terminal/commit/56e5c3509cb27c7911de0e3a64da4875a9e3b20d))
- Pad dark Dock icon to match light icon's OS-auto-shrunk size ([`e6a1316`](https://github.com/Vit129/kouen-terminal/commit/e6a13163394bd4f9e7fc3ff867473e50394a37e9))
- OAuth login and nested-iframe scroll in embedded browser pane ([`db5c34d`](https://github.com/Vit129/kouen-terminal/commit/db5c34d9188d69b013890af223814337d0bde065))
- Prune legacy harness-cli hook entries on agent reinstall ([`57936a3`](https://github.com/Vit129/kouen-terminal/commit/57936a3f24b2738fd3aafb4937fa56c2f369203d))
- Stop QuickLook preview flicker loop from self-triggered attrib events ([`9bca6ab`](https://github.com/Vit129/kouen-terminal/commit/9bca6abcceef322744413628cd37536490ef1825))
- Clean up git panel error toast for push/fetch/pull failures ([`c7a675a`](https://github.com/Vit129/kouen-terminal/commit/c7a675a04bae56fae331d72f7745e15056d33303))

## [4.0.0] - 2026-07-06

### Added
- Rename product from Harness to Kouen ([#43](https://github.com/Vit129/kouen-terminal/pull/43)) ([`94c4f2c`](https://github.com/Vit129/kouen-terminal/commit/94c4f2c83d77b366d36afef6c778e3a625ff1425))
- KOUEN_HOME env var, sentinel migration, v4.0.0 bump ([#45](https://github.com/Vit129/kouen-terminal/pull/45)) ([`b94c653`](https://github.com/Vit129/kouen-terminal/commit/b94c6535dc96cc839507674d2c626f4417677c1e))
- Migrate the App Support data root from Harness to Kouen ([#48](https://github.com/Vit129/kouen-terminal/pull/48)) ([`24f7b06`](https://github.com/Vit129/kouen-terminal/commit/24f7b062f9174212effbb34c4e5b7aa5ade27bf3))
- Rename all internal Swift modules, directories, and identifiers to Kouen ([#49](https://github.com/Vit129/kouen-terminal/pull/49)) ([`704ad48`](https://github.com/Vit129/kouen-terminal/commit/704ad48a21d73d6c60a37518942717531bb45edd))

### Documentation
- Add "What's different from upstream" section to README ([`daabced`](https://github.com/Vit129/kouen-terminal/commit/daabcedd2b710d654d9d56be5c300709ccd32989))
- Trim "What's different from upstream" to link existing sections ([`9041960`](https://github.com/Vit129/kouen-terminal/commit/9041960f8090186d88f8decadc2f951748e0375a))
- State explicitly that this fork isn't affiliated with upstream ([#40](https://github.com/Vit129/kouen-terminal/pull/40)) ([`2e76384`](https://github.com/Vit129/kouen-terminal/commit/2e76384fe63e3eaf62cd9fbe7dfb3d330e27ef7b))
- Trim README's upstream mention to one, fix stale repo links ([#47](https://github.com/Vit129/kouen-terminal/pull/47)) ([`5538f8b`](https://github.com/Vit129/kouen-terminal/commit/5538f8b404ebb65b62378d7b6543b79beac2442d))
- Capture P35 plan — Google/OAuth login fails in embedded browser ([#42](https://github.com/Vit129/kouen-terminal/pull/42)) ([`1d77cdf`](https://github.com/Vit129/kouen-terminal/commit/1d77cdf88ad7433887fb83c3a9ba3f7b27b6e1e8))

### Fixed
- Rebrand bundle identifier off upstream, disable Sparkle appcast ([#41](https://github.com/Vit129/kouen-terminal/pull/41)) ([`d1ca64f`](https://github.com/Vit129/kouen-terminal/commit/d1ca64f6821189e9bbd14dd9ac2d47f1e07fd2b3))
- Rename the release/packaging pipeline and revert App Support path drift ([#46](https://github.com/Vit129/kouen-terminal/pull/46)) ([`b8cf6e9`](https://github.com/Vit129/kouen-terminal/commit/b8cf6e9863521f0cf6dc6f4030a515731a899e1b))
- Rename the tracked Xcode project and entitlements file ([#50](https://github.com/Vit129/kouen-terminal/pull/50)) ([`b9c0c73`](https://github.com/Vit129/kouen-terminal/commit/b9c0c73fd697623a7cefd88c9eef384738f417e7))
- Rename remaining tooling configs missed by every previous pass ([#51](https://github.com/Vit129/kouen-terminal/pull/51)) ([`4d43c7e`](https://github.com/Vit129/kouen-terminal/commit/4d43c7ecc027fb1449248b359ea72f1fdd31e0eb))

## [3.14.0] - 2026-07-04

### Added
- Open every http/https link in the in-app Browser Pane ([`36ea9b6`](https://github.com/Vit129/kouen-terminal/commit/36ea9b6a546741a7661ba32002ff66c6478e97b3))
- Route web links to the in-app browser pane, fix popup crash (release v3.14.0) ([`2c98e9e`](https://github.com/Vit129/kouen-terminal/commit/2c98e9ec6dc2b700faeb97c0de81dfc6f8d4277f))

### Fixed
- Respect sound toggle in foreground and route banner clicks to their pane ([`2202305`](https://github.com/Vit129/kouen-terminal/commit/2202305e8c5f296450ef2fd599d0e70861c01612))
- Prevent crash when a browser popup reuses the opener's WKWebViewConfiguration ([`149d28b`](https://github.com/Vit129/kouen-terminal/commit/149d28ba8c639bbaa8d7f63633157077e65baf10))

## [3.13.3] - 2026-07-04

### Added
- Render local .html files in the embedded browser pane on double-click (release v3.13.3) ([`70ba89c`](https://github.com/Vit129/kouen-terminal/commit/70ba89ce0a9954d0cab6c11561d58cf577caaf78))

### Fixed
- Auto-tag commit message when Info.plist is staged ([`e4d8d51`](https://github.com/Vit129/kouen-terminal/commit/e4d8d51693ab8b863ebdb50777300db022c893eb))

## [3.13.2] - 2026-07-03

### Added
- Wire auto-rebuild hook + gitignore wiki/log bloat ([`3ee42f8`](https://github.com/Vit129/kouen-terminal/commit/3ee42f822bc15fc3bf4ed6aad54f5597c9027bcb))

### Fixed
- Notification Step 1, S1 daemon-reuse install, H5 bootout quoting bug ([`85354d2`](https://github.com/Vit129/kouen-terminal/commit/85354d23e192f1ba5d7ae70bef39c751cac29b80))
- Notification Step 1, S1 daemon-reuse install, H5 bootout quoting bug (v3.13.2) ([`8a9fcf7`](https://github.com/Vit129/kouen-terminal/commit/8a9fcf7d3a9529faf3b02804acbab077dee656af))

## [3.13.1] - 2026-07-02

### Added
- Support non-interactive option with patch version bump ([`5dbb64e`](https://github.com/Vit129/kouen-terminal/commit/5dbb64eacb5f4d1c6fef7f22ae0fda6e558e26fd))

### Documentation
- Drop hardcoded release version from README ([`c7fb340`](https://github.com/Vit129/kouen-terminal/commit/c7fb3403052e2a918c774c97515d800167e7a17a))

### Fixed
- Preserve selection on reload, fix clicking agent tool-call paths ([`587fa90`](https://github.com/Vit129/kouen-terminal/commit/587fa906c3ae07eb4e9018861b6ab6220716ef3f))

## [3.13.0] - 2026-07-02

### Added
- Visible divider between panes + 3-way corner drag ([`b83773e`](https://github.com/Vit129/kouen-terminal/commit/b83773e99b7f5e67ba2e5a28cde58ae7074e23ae))
- Visible divider between panes + 3-way corner drag ([`b556b4f`](https://github.com/Vit129/kouen-terminal/commit/b556b4fede55ab3ff9e50a74f296f36430ec6e79))
- SSH socket auto-detect for remote host manager (P23/PBI-SSH-008) ([`a634720`](https://github.com/Vit129/kouen-terminal/commit/a6347206a6e4da3896b36807c76b718f296de362))
- Explicit New Agent Task command palette flow (P32 Phase 1) ([`5641273`](https://github.com/Vit129/kouen-terminal/commit/5641273f9c4708843229105cd7a73af85272dcda))
- Task metadata + sidebar UI for agent task tabs (P32 Phase 2) ([`d9c1ad1`](https://github.com/Vit129/kouen-terminal/commit/d9c1ad1a8c3635cc40e22ddc2db788dcb029e6d3))
- Wire archiveScript teardown hook + close out P32 (Phase 3+4) ([`a9317c6`](https://github.com/Vit129/kouen-terminal/commit/a9317c6c8dabe0179cae92a4ec8d7bc01b254863))
- Surface agent notification text in sidebar (P33 Phase 2) ([`001da1e`](https://github.com/Vit129/kouen-terminal/commit/001da1ef686bbd68ae0778d45cc61e6f549bf1c1))
- Color git-change file previews like the diff instead of raw unified text ([`c238bc0`](https://github.com/Vit129/kouen-terminal/commit/c238bc016d08a3b321bfe7591b73f45ea2d4df00))
- Scope file preview tabs per terminal Tab ([`b405e32`](https://github.com/Vit129/kouen-terminal/commit/b405e321ac04143be9a1ed8d7d891e536cc698f4))
- Expand editor LSP + syntax highlighting to 21 languages ([`9838134`](https://github.com/Vit129/kouen-terminal/commit/98381347ec727f64ab092b15a9ad1f904135905e))
- Capture exact command text on OSC 133 command boundary (P34 F1 slice 1) ([`2ca7fbb`](https://github.com/Vit129/kouen-terminal/commit/2ca7fbb860a30559cec72394c97b1fec9d1d8c40))
- Block copy actions + MCP block access (P34 F2/F3) ([`8049605`](https://github.com/Vit129/kouen-terminal/commit/8049605ed45c90fee90e30ba065b7267c1c0802c))
- Add setPaneLabel MCP tool for per-pane purpose labels ([`965f7b3`](https://github.com/Vit129/kouen-terminal/commit/965f7b3e821727446642b723c9b7afa6ecafd2e1))
- Let spawnSession/splitPane set a pane label atomically ([`c9ee32c`](https://github.com/Vit129/kouen-terminal/commit/c9ee32ce99ced761e6d912cc2af4ebcf6d26283a))
- Link worktree cards to running agents, add diff-vs-main ([`301e838`](https://github.com/Vit129/kouen-terminal/commit/301e838d52ef489ae09aa895fbcc53ec171d3475))

### Changed
- Replace ⌘-click block action bar with right-click context menu ([`1723136`](https://github.com/Vit129/kouen-terminal/commit/17231362f9594c2b99af58981844f1ced6e8cd2d))

### Documentation
- V3.12.0 accuracy pass — remove stale inline AI chat claims, verify MCP/browser round-trip fixed, fix P33 status, add feature-provenance + P34 plan ([`ead9f57`](https://github.com/Vit129/kouen-terminal/commit/ead9f5795786f01a2d4e95d837bb3265869bd99b))
- Fix CONTEXT.md commit-status note for P34 F2/F3 ([`a2b6c38`](https://github.com/Vit129/kouen-terminal/commit/a2b6c38ffd09ce35ca15254eda211aeb26f561b4))
- Log two backlog decisions from P34 follow-up discussion ([`84ac1aa`](https://github.com/Vit129/kouen-terminal/commit/84ac1aa2a6b6442603c50c660bfaf950f09efc23))
- Archive P32 setPaneLabel + P34 right-click backlog items as shipped ([`8506b36`](https://github.com/Vit129/kouen-terminal/commit/8506b36f4c4fbd533ea97828a1d30fa41b2d641b))
- Archive atomic pane-label-on-create follow-up as shipped ([`a52b923`](https://github.com/Vit129/kouen-terminal/commit/a52b923204162dfc47505f887b8cf891ef030057))

### Fixed
- Repair swift test build broken by ACP removal ([`ec22918`](https://github.com/Vit129/kouen-terminal/commit/ec22918cf65c759ee7b069c175191e15dc0a2e9b))
- Surface addAgentTask errors via NSAlert instead of silent no-op (P32 Phase 2) ([`36cf813`](https://github.com/Vit129/kouen-terminal/commit/36cf813bcf78c438292bc8d960a2354c8aecbbb1))
- Pin sidebar width against proportional resize; smaller default + always-open ([`80b82db`](https://github.com/Vit129/kouen-terminal/commit/80b82db38455a973b506d1ce41932822c5920153))
- Unify running/status classification + replace dot with agent icon ([`eb0c89b`](https://github.com/Vit129/kouen-terminal/commit/eb0c89bde4c87ed1a8c4fb3ec1e21b188031adf3))
- Unify Board status classification/color + fix Board tab layout ([`49a67ba`](https://github.com/Vit129/kouen-terminal/commit/49a67babfaa5ce3d61819dfd3e26d76c71de9d65))
- Show PR checks status dot, remove dead PR poller (P33 Phase 1) ([`20b521b`](https://github.com/Vit129/kouen-terminal/commit/20b521b6910e792ab5b7096d3b5d90fcaed67347))
- NSSplitView first-reveal blank panel + wire diff popover (P33 Phase 3) ([`0aa1326`](https://github.com/Vit129/kouen-terminal/commit/0aa1326b2cade5f0f968fbc7405e47ad8a144081))
- Address 4 findings from Opus code review ([`575e864`](https://github.com/Vit129/kouen-terminal/commit/575e864b53ded1c5917b67e65727c3f66f61975a))
- Stop blanket .git/ FSEvent filter from swallowing external commit/push ([`405021e`](https://github.com/Vit129/kouen-terminal/commit/405021e53b7e9d41d2568d46daa6780f5055b8af))

## [3.12.0] - 2026-06-30

### Added
- Board + Spaces tabs + openDiffReview MCP tool ([`78af4a4`](https://github.com/Vit129/kouen-terminal/commit/78af4a49e1c559e1d223d5a0d73a91659d1a0602))
- Show Needs Attention text inline in session rows ([`73258c5`](https://github.com/Vit129/kouen-terminal/commit/73258c531532e9e6db1ca383a99a694f377aed0e))
- Board toggle, inline agent status, openDiffReview; bump version 3.12.0 ([`0277c32`](https://github.com/Vit129/kouen-terminal/commit/0277c3268f53e5e19ada91281e233b10a91e0e20))

### Changed
- Merge Board into Sessions tab with list/board toggle ([`fd7a294`](https://github.com/Vit129/kouen-terminal/commit/fd7a29417114999b1fd37ac2600a7e12d0b8aff8))
- Inline board status in session rows, drop Spaces tab ([`08014e8`](https://github.com/Vit129/kouen-terminal/commit/08014e87676974ab74de6a3e7f0ac01076cd1284))

### Documentation
- Record CASE-057 — CC 2.1.195 rejects whole settings.json on one invalid value ([`793b9ae`](https://github.com/Vit129/kouen-terminal/commit/793b9ae6c556d1a00641339aa66f08c129e0aea0))
- Record live perf profile — CPU = SwiftUI .repeatForever ViewGraph storm, memory clean ([`b188a4b`](https://github.com/Vit129/kouen-terminal/commit/b188a4b0902ad72f460d1da9f0cb0afbb4e9bf0e))
- Mark .repeatForever CPU fix done (dd7a78c) in knowledge ([`1905af0`](https://github.com/Vit129/kouen-terminal/commit/1905af041107d779ff34d9a10d39f9d75684445c))

### Fixed
- Status line hidden on plain mode after SwiftUI settings migration ([`71e3c05`](https://github.com/Vit129/kouen-terminal/commit/71e3c05bf3e33153b858ca594fba68c1de7e30ca))
- Contain Metal layer islands so status bar stays on top ([`2a5b3f0`](https://github.com/Vit129/kouen-terminal/commit/2a5b3f053c86a129f0df361a6a80896c6ec9139e))
- Eliminate CPU spikes from FSEvent storm during agent writes ([`f6ffb0a`](https://github.com/Vit129/kouen-terminal/commit/f6ffb0a3c9a24ca39f8171025bdafbe289d66a65))
- Move working/notch pulse off SwiftUI .repeatForever to CALayer (CPU) ([`dd7a78c`](https://github.com/Vit129/kouen-terminal/commit/dd7a78c37e74215800d1ca391f2d530f71a465be))
- Add openGitPanel stub to SurfaceRegistry exhaustive switch ([`4596a86`](https://github.com/Vit129/kouen-terminal/commit/4596a8695effb73f59560ab74dac95138b78c1ed))
- Kill in-flight CADisplayLink before reading frame width ([`ac77280`](https://github.com/Vit129/kouen-terminal/commit/ac772801d68a6fb95bef3bae690128df761ddf23))

## [3.11.7] - 2026-06-29

### Changed
- Skip Phase-1 revision pings in all UI snapshot observers ([`5cbbe82`](https://github.com/Vit129/kouen-terminal/commit/5cbbe828007342f2594014065a573f063fe6f509))
- Coalesce burst pings in SessionCoordinator; cap FrecencyDirectoryStore at 500 ([`ffb059a`](https://github.com/Vit129/kouen-terminal/commit/ffb059a9d4f2a521ac51a6e4b56f9a18449cdf1e))

## [3.11.6] - 2026-06-29

### Added
- Inline image paste & drag-drop via Kitty graphics; perf: remove SurfaceShellTracker full-process-table walk ([`7b5ff01`](https://github.com/Vit129/kouen-terminal/commit/7b5ff018da4aee8946306227ba2fc3997197b834))
- Image paste & drag-drop inserts file path instead of Kitty bytes ([`bc14a2c`](https://github.com/Vit129/kouen-terminal/commit/bc14a2c07ab8d5e64ddf46e5f8a14090c6019785))

### Documentation
- Update README — agent workspace positioning, browser MCP, multi-agent statusline ([`eb5a4a7`](https://github.com/Vit129/kouen-terminal/commit/eb5a4a795c8462638b80b342d345806016b7238e))
- Update README to v3.11.5 + keyboard shortcuts; CHANGELOG otty features ([`f3efcd5`](https://github.com/Vit129/kouen-terminal/commit/f3efcd527c72e254eaa913ba81df9c8fd9e1e4fa))
- Remove [Unreleased] section; mark otty-features closed in CHANGELOG ([`3505fa3`](https://github.com/Vit129/kouen-terminal/commit/3505fa3ade4a3c84051dc2147f905c2c187b9e64))
- Remove otty-features comment from CHANGELOG ([`9eb0028`](https://github.com/Vit129/kouen-terminal/commit/9eb0028b9476a9d85dfd9cc113e007c8ab4b7899))
- Record tab-switch black-screen root cause analysis in knowledge base ([`cc67abd`](https://github.com/Vit129/kouen-terminal/commit/cc67abdb3e41f274e99d9ecf453c3876a3c9dabe))

### Fixed
- Daemon stop command with built-in 2-second timeout ([`7e3793c`](https://github.com/Vit129/kouen-terminal/commit/7e3793c4b371d092a4078668f4a578bb72bdeaed))
- Black screen on tab switch — wake Metal renderer after isHidden restore ([`7310f42`](https://github.com/Vit129/kouen-terminal/commit/7310f42482fc65db402bb353adff40e031efe1c5))
- Tab-switch black screen — keep hosts in cached container ([`4b5be7b`](https://github.com/Vit129/kouen-terminal/commit/4b5be7b262f67ede64b571664cb2951b754900e1))
- Restore Metal rendering after display switch ([`c58621a`](https://github.com/Vit129/kouen-terminal/commit/c58621a9696e35cf93f54cfc932a49b3186033e2))
- Tab-switch black screen — keep hosts in cached container ([`7dd9000`](https://github.com/Vit129/kouen-terminal/commit/7dd9000e21e9299059e9fdccd6e38ef764a59462))
- Synchronous repaint on tab-switch fast-path reveal ([`da03968`](https://github.com/Vit129/kouen-terminal/commit/da03968c564c9c5e36ec7d42b36177a6fd7de17f))
- Evict cached container on force rebuild to prevent black-on-revisit ([`06daab6`](https://github.com/Vit129/kouen-terminal/commit/06daab6254975f64e69f699c815cd6bde0bf59af))
- Validate cached hosts before fast-path reveal; plug cache-overwrite leak ([`3d839a1`](https://github.com/Vit129/kouen-terminal/commit/3d839a19299df0983f4b20328425fc24409ca3fa))
- Performance and black screen when switch tab ([`9d49488`](https://github.com/Vit129/kouen-terminal/commit/9d4948827230405e3c36713c1c59b03fefb8f402))

## [3.11.4] - 2026-06-28

### Added
- Add Option 3 — Fix version to re-sync all 4 version files ([`e17e1b9`](https://github.com/Vit129/kouen-terminal/commit/e17e1b9399347e29b7a72fb8e65305a8bb35dc00))
- Add graceful install — preserve session layout across updates ([`9537a78`](https://github.com/Vit129/kouen-terminal/commit/9537a78346c3be1d3ab79bd343f8d5c359d7996e))

### Fixed
- Critical bugs in action buttons and status line visibility ([`32f03d7`](https://github.com/Vit129/kouen-terminal/commit/32f03d7a6f111fcbdabe26107bd0711f156d06fb))
- BlockActionBar buttons unresponsive + skip redundant scroll redraws ([`bc69cd6`](https://github.com/Vit129/kouen-terminal/commit/bc69cd6f28f334c8007640350f41671e274a70d1))
- Shell injection in directory picker + floating panel guards ([`c13ece9`](https://github.com/Vit129/kouen-terminal/commit/c13ece96e96c6fb2ac1326b23c90ce0d07743d2c))
- Remove duplicate shellQuoted extension + Self in stored property initializer ([`33b0b93`](https://github.com/Vit129/kouen-terminal/commit/33b0b933afdfae228cca319a14436257e85f4bda))
- Store and remove NotificationCenter observers in FloatingPaneController ([`ff381cc`](https://github.com/Vit129/kouen-terminal/commit/ff381cc102854ba6fd62db68b07973d9f321f93c))
- Vi mode breaks Esc + 3 audit bugs from otty-features wave ([`d432fc9`](https://github.com/Vit129/kouen-terminal/commit/d432fc99b8db39b4d44ed670637a22e0bb04a3d7))
- Group header '...' button silent since June 22 SwiftUI migration ([`1b6adfe`](https://github.com/Vit129/kouen-terminal/commit/1b6adfe1329be4ee5f8b1133f6d39edbb37b4238))
- ShowStatusLine orphaned gate hides status line permanently ([`ebc2e17`](https://github.com/Vit129/kouen-terminal/commit/ebc2e17d0875b0baee648cd53fe07a04ce590c1f))
- 4 bugs from wave-2 SwiftUI migration + Open With + harness view ([`411ee6d`](https://github.com/Vit129/kouen-terminal/commit/411ee6d79b6713652e19d2da60da8b9951413346))
- CommandPalette cd silently fails for paths with spaces ([`f0d75fe`](https://github.com/Vit129/kouen-terminal/commit/f0d75fe31ea2bb6587705b809cd44a04b3acda86))
- 5 SwiftUI migration bugs + perf improvements ([`ce16dbb`](https://github.com/Vit129/kouen-terminal/commit/ce16dbbdd0ec95a883a612c0b7e37ec166ab0752))
- Add timeout to harness-cli daemon stop to prevent hang ([`3a12fad`](https://github.com/Vit129/kouen-terminal/commit/3a12fad8ade55160bbfcbb4ad5c234e0c4274ef3))

## [3.11.2] - 2026-06-28

### Changed
- Debounce status line refresh + skip redundant NSAttributedString rebuilds ([`a0a343b`](https://github.com/Vit129/kouen-terminal/commit/a0a343b3292c02457ef93506cc46a8d8495d3924))
- Hoist process-table build out of per-surface agent scan loop ([`8076204`](https://github.com/Vit129/kouen-terminal/commit/8076204ce43d6760c35c6724b2296ec504f5b7a0))

### Fixed
- Remove NotificationCenter observer leaks on window/pane teardown ([`a3f437d`](https://github.com/Vit129/kouen-terminal/commit/a3f437d45f74c6033bab019524aaea0019f3a113))
- Browser routing, GUI-disconnect hang, stale runSurface Ctrl-C, per-chunk alloc ([`d2fa7f5`](https://github.com/Vit129/kouen-terminal/commit/d2fa7f5f4c30aa1f47124adc12dbe120ca239148))
- Shell-quote model/effort in spawnCommand + browser routing + invariant tests ([`1b2628c`](https://github.com/Vit129/kouen-terminal/commit/1b2628cc11ecc7358294f125f4e92a478411dff1))
- 5 Opus round-2 findings — snapshot reconnect, timer leak, progress, network capture, reconnect probe ([`c641239`](https://github.com/Vit129/kouen-terminal/commit/c64123976b110d45afe2149a892c94235792b776))
- PromptQueue surface-key leak + AppIdleThrottle double-install guard ([`2e6fdd0`](https://github.com/Vit129/kouen-terminal/commit/2e6fdd039815292d8b927f3bc02908c2ebf55df7))
- Status line Settings toggle bound to wrong field for non-full modes ([`2159a77`](https://github.com/Vit129/kouen-terminal/commit/2159a774e85f202613afc45b9f2d3e2b5a79a4a9))

## [3.11.0] - 2026-06-28

### Added
- Implement Phase 11 - Recipes command picker ([`87eeabb`](https://github.com/Vit129/kouen-terminal/commit/87eeabbdc60765f8cfb06f219585d95684a13589))
- Phase 10 — Quick Terminal ⌥Space (NSPanel + dedicated workspace) ([`a823fff`](https://github.com/Vit129/kouen-terminal/commit/a823fff6b0126d76fec19c5d33b9986bd0d7f878))
- Phase 2 — Vi modal editing (Esc/hjkl/wb/x/i/a/A) with ⌘⌃V toggle ([`5a7eb10`](https://github.com/Vit129/kouen-terminal/commit/5a7eb10688303e19a699783e9dfb7398b9f6abf2))
- Phase 12 — block output: prompt gutter on by default, ⌘-click selects OSC 133 block ([`196c362`](https://github.com/Vit129/kouen-terminal/commit/196c362c6c23a0c429b8bc3ca73db33344f1d5be))
- Phase 14 — Floating Terminal ⌘⌥F (NSPanel, persisted frame) + Phase 15 — Tab Overview ⌘⇧\ (thumbnail grid, click to switch) ([`68c4906`](https://github.com/Vit129/kouen-terminal/commit/68c490655d93c82a3d3b87f2a42bf856e17c5e55))
- ⌘↩ opens new tab in dir picker + zoxide as data source ([`e64bbc8`](https://github.com/Vit129/kouen-terminal/commit/e64bbc8d9f1edbe90fcee936fbb63b170defbcb1))
- Block output tint + AI explain action bar (Phase 12b) ([`0e608ce`](https://github.com/Vit129/kouen-terminal/commit/0e608ce2472ce8bc5ba78752ea2a2e2dd506ac0d))
- Block border, collapse/expand, re-run button (Phase 12c) ([`49d25b2`](https://github.com/Vit129/kouen-terminal/commit/49d25b21d45031d24a1cfef5a73c3b44942c8dc9))
- OSC 26 agent protocol + Fork Tab + approval bar ([`b6154c2`](https://github.com/Vit129/kouen-terminal/commit/b6154c2ea3ba2d3c2c95608b2dbc1e7c4f674a74))

### Changed
- Defer tab thumbnail renders + add OSC 26 hook payloads ([`372886a`](https://github.com/Vit129/kouen-terminal/commit/372886addfa4535758b571af75e17dd5bf3a7f37))

### Documentation
- Mark medium phases 10, 11, 18, 19 complete in PLAN + CONTEXT ([`584f31d`](https://github.com/Vit129/kouen-terminal/commit/584f31dede22e2bce4321b661fdbe1201051a6b4))
- Mark Phase 2 + 12 done in PLAN + CONTEXT ([`acf399b`](https://github.com/Vit129/kouen-terminal/commit/acf399b244e2c531d422bfd97959304a3cf98219))
- Mark Phase 14 + 15 done — otty-features complete ([`4d41ca3`](https://github.com/Vit129/kouen-terminal/commit/4d41ca3cffd44dd350a414591ea0da5cc85282f9))
- Add agent-terminal AIDLC planning + update otty-features PLAN ([`e41a344`](https://github.com/Vit129/kouen-terminal/commit/e41a3445bf2cebf45855595ad3c625726721c961))

### Fixed
- Deinit in extension SyntaxTextView — move to class body ([`cac75c5`](https://github.com/Vit129/kouen-terminal/commit/cac75c5aeb35bf100c39aee898a304e909b0eaeb))
- Full-cycle uses make install (prod+install) before tag/release ([`710580b`](https://github.com/Vit129/kouen-terminal/commit/710580bd8959614fb38ab53529aaeabbcac0c6c4))
- Approval bar freeze + ProMotion render-rate cap ([`6083086`](https://github.com/Vit129/kouen-terminal/commit/608308635fcbc20a945ce453909980c0a4b0c393))

## [3.10.1] - 2026-06-27

### Added
- Full-cycle --no-bump flag + start.mjs asks version bump before full run ([`10346cb`](https://github.com/Vit129/kouen-terminal/commit/10346cb36c4f607e32a17cea05611a3c83a0a432))
- Send selection to AI chat via right-click context menu ([`b104eed`](https://github.com/Vit129/kouen-terminal/commit/b104eed9b1e0875167370339d978e98acef7b84b))
- Wire ⌘F scrollback search — find bar was implemented but unbound ([`5fac8a7`](https://github.com/Vit129/kouen-terminal/commit/5fac8a7ae23b0c35fff61a4cb3946ba15683096d))
- Click-to-move shell cursor on single click (Phase 5) ([`ee002b8`](https://github.com/Vit129/kouen-terminal/commit/ee002b826f8cd399647bd04fbf1e214f3dcec096))
- Auto secure input on password prompts (Phase 6) ([`99643bc`](https://github.com/Vit129/kouen-terminal/commit/99643bcc7d0666d58122f36a17c0239908e4ec90))
- Ctrl+C copies selection when text is selected (Phase 7) ([`844b9c2`](https://github.com/Vit129/kouen-terminal/commit/844b9c220e28db7ae27fbeafd5d1bffdb66bee3f))
- Show git branch in tab immediately on cd (Phase 17) ([`be60091`](https://github.com/Vit129/kouen-terminal/commit/be60091588775b3c05442711f63c698ae43298fe))
- Composer panel for multi-line PTY commands ⌘⇧E (Phase 8) ([`f753a14`](https://github.com/Vit129/kouen-terminal/commit/f753a146b49773a255af54d1c19be0104b58596f))
- Prompt queue — sequential command runner (Phase 9) ([`d9e74b9`](https://github.com/Vit129/kouen-terminal/commit/d9e74b91591f6f5fb33ffb85a7249377c5e66016))

### Changed
- Prevent redundant UI rebuilds and memory leaks in GitPanelView ([`8841cc7`](https://github.com/Vit129/kouen-terminal/commit/8841cc71c09a665ca330fda0cfa10808289fd42f))

### Documentation
- Release workflow + version sync rule in CLAUDE.md ([`7dcac54`](https://github.com/Vit129/kouen-terminal/commit/7dcac543a81fa3d5732bae1ae45ae86033c0ad86))
- Expand otty-features PLAN — 6 new features from CMUX/Zellij/iTerm2 research ([`3163e1c`](https://github.com/Vit129/kouen-terminal/commit/3163e1ca46b2c007d1041897053a61af2b98c9f0))
- Update CHANGELOG, PLAN, CONTEXT for otty-features phases 1/3-9/17/20 ([`9ebe9c4`](https://github.com/Vit129/kouen-terminal/commit/9ebe9c4c4dcf5bdea5b0a75c1d262c130d2a4239))

### Fixed
- Full-cycle step 4 — build+sign only, no open (was dropping session) ([`9ae8d7c`](https://github.com/Vit129/kouen-terminal/commit/9ae8d7c3f63faf79374b0149c64f66d6fc27be00))
- Trim inactive session scrollback on macOS memory pressure ([`54f6a0b`](https://github.com/Vit129/kouen-terminal/commit/54f6a0b819a7fbe7335f2e20cea3eed79fcb5be1))
- AI chat streaming reads no output for batch-write agents (⌘I) ([`160d064`](https://github.com/Vit129/kouen-terminal/commit/160d06474e6bf94c31d361542a724421583bea47))
- Remove NSEvent monitors and NotificationCenter observers on deinit ([`6f9c155`](https://github.com/Vit129/kouen-terminal/commit/6f9c15562044a96dd138176e570b7a7b846c50ec))

## [3.10.0] - 2026-06-27

### Added
- SwiftUI settings foundation — SettingsModel + Terminal page ([`4435619`](https://github.com/Vit129/kouen-terminal/commit/443561969f40a6a153afa21beb37eef2fa7179f7))
- SwiftUI Settings — Appearance page (S2) ([`dd1ca45`](https://github.com/Vit129/kouen-terminal/commit/dd1ca45b688e7694b664b1bee1bab18be14fe45b))
- SwiftUI Settings S3–S5 — Colors, Keys, Agents pages ([`c572ed4`](https://github.com/Vit129/kouen-terminal/commit/c572ed4cf723d5ce22fe57ec5fef5e773e2704cb))
- SwiftUI Settings S6–S9 — Advanced, Remote, root wiring, AppKit deleted ([`94c9491`](https://github.com/Vit129/kouen-terminal/commit/94c94913c260e4fbca555f575e0f215d4ce1c5c4))
- Migrate WorkspacePillButton to SwiftUI ([`204dcf2`](https://github.com/Vit129/kouen-terminal/commit/204dcf2d2ddd5e7c0299320117a1594540322c6d))
- Migrate sidebar section label + footer to SwiftUI ([`a072edf`](https://github.com/Vit129/kouen-terminal/commit/a072edf56bdd051951a6ae9e4a1a0e26c6e988b6))
- Migrate sidebar tab bar from NSSegmentedControl to SwiftUI Picker ([`a6d59a9`](https://github.com/Vit129/kouen-terminal/commit/a6d59a9ce4549c1a080584bb981a268af569ac46))
- Open With Harness for source files + file preview routing ([`36fde38`](https://github.com/Vit129/kouen-terminal/commit/36fde383ef6d6f6ab5ec19bff05800fbfa81e1b0))
- Open With file → terminal at git root + tree reveals file ([`cabcb86`](https://github.com/Vit129/kouen-terminal/commit/cabcb86707bdc001cc590c11986e9a2f206176b5))
- File tree roots at git root, expands to CWD on cd ([`d3a700f`](https://github.com/Vit129/kouen-terminal/commit/d3a700f3d4d9c1fd55e005079cd5aea2de2de130))
- AppKit → SwiftUI wave 2 — 4 UI components migrated ([`760705a`](https://github.com/Vit129/kouen-terminal/commit/760705a092f877d78eacb5419e3e777ae4f3bfee))

### Changed
- Migrate Toast+About to SwiftUI, delete dead NotificationBellButton + DragReorder stub ([`94f4d54`](https://github.com/Vit129/kouen-terminal/commit/94f4d541b44ac728aeb58ade876edfbec84dd3b9))

### Documentation
- Update knowledge — CASE-042/043 + cwd-worktree-bleed companion fix + memory decisions ([`c67a980`](https://github.com/Vit129/kouen-terminal/commit/c67a980f668cb32497eecd1db8103242d3c53d10))
- Update CONTEXT — SwiftUI Settings S6–S9 complete ([`654fe82`](https://github.com/Vit129/kouen-terminal/commit/654fe820b0d8676f657d20487c8c2acdcfc8c74f))
- Update CONTEXT, knowledge, plans, graphify after sidebar SwiftUI wave 2 ([`95290db`](https://github.com/Vit129/kouen-terminal/commit/95290dbc140413bcb42db54896d81dfae6dd836e))
- Update CONTEXT — SwiftUI wave 2 complete (4 components, −424 lines) ([`139ab6a`](https://github.com/Vit129/kouen-terminal/commit/139ab6a04662f976d791c78a550172d902d57547))

### Fixed
- Flush NSHostingView layout after sidebar animation completes ([`bef888a`](https://github.com/Vit129/kouen-terminal/commit/bef888a9b06d0ef1a5cfd549c1a571a7a56b70da))
- Sidebar animation frames drop on macOS 26 — Task {@MainActor} → assumeIsolated ([`d5833b0`](https://github.com/Vit129/kouen-terminal/commit/d5833b0deed13b73942eec00e52f2fcc4e1b8541))
- Sync Metal terminal frames with CA during sidebar animation ([`28d0233`](https://github.com/Vit129/kouen-terminal/commit/28d02337fb1a55d0605cc352a021d9b337d6771b))
- Point Bug 1 robot guard to BrowserIntegrationController where removeValue lives ([`ad792c9`](https://github.com/Vit129/kouen-terminal/commit/ad792c9ca0753023088bd8f9b1e278c27a77e83d))
- Remove presentsWithTransaction from animated sidebar — was blocking main thread every vsync ([`b9f94cd`](https://github.com/Vit129/kouen-terminal/commit/b9f94cd7a49e0d767443a858c59d5e8f4332ec9e))
- Panel to response slow and move pane to left/right corner ([`0f71782`](https://github.com/Vit129/kouen-terminal/commit/0f7178285d13542c1f639f84cf3d0932cf25105c))

## [3.9.5] - 2026-06-26

### Added
- Vimium-style hint mode (Cmd+Shift+U) for keyboard link opening ([`cba7cdc`](https://github.com/Vit129/kouen-terminal/commit/cba7cdce553b4fec0dbef6bb72dd5a0553ab6333))
- Harness view opens sidebar file viewer via OSC 7735 ([`8913672`](https://github.com/Vit129/kouen-terminal/commit/8913672e8acb9d8fa558cea8cdf1c0ab8edae36c))
- Harness cat shows line numbers that are excluded from copy ([`22f4dd5`](https://github.com/Vit129/kouen-terminal/commit/22f4dd5c88e59ed897689c0869e57f51781cedc9))
- Add Commit & Push to Sync menu ([`e902d2e`](https://github.com/Vit129/kouen-terminal/commit/e902d2e54d0434cfbc57d3b6056a60bf8e98144e))

### Documentation
- Update agent-memory with RL-056/057/058 and CASE-039/040/041 ([`4b9eb22`](https://github.com/Vit129/kouen-terminal/commit/4b9eb2249a281bc05774e9ed819abdb317824216))
- Strip global-duplicate sections from CLAUDE.md ([`7bb5578`](https://github.com/Vit129/kouen-terminal/commit/7bb55781617016e728b7cee146bc60932a121174))
- Record memory-leak audit findings + onRetire fix pattern ([`8af2790`](https://github.com/Vit129/kouen-terminal/commit/8af27904ddc03dd7c803067db2729a11b81ecc25))
- Add memory-leak-audit case study + update graphify for v3.9.4 ([`120acf3`](https://github.com/Vit129/kouen-terminal/commit/120acf3b20caf34ac8af9c2100a350aeba7b0eaa))
- Bump version to v3.9.4 + note Commit & Push shortcut in README ([`5720d01`](https://github.com/Vit129/kouen-terminal/commit/5720d0149b940a41aa00ce75371104866d8a0d54))
- Note long-session memory stability in README ([`53aefa9`](https://github.com/Vit129/kouen-terminal/commit/53aefa9b4667cbc28519c5349cc11c5ec3185229))

### Fixed
- Fix button hit-testing, sidebar toggle, and browser log freeze ([`aeadae9`](https://github.com/Vit129/kouen-terminal/commit/aeadae9d3f45c2e883ad202739d4599240112d25))
- Remove adjustSubviews() calls that caused terminal blink regression ([`b55cc62`](https://github.com/Vit129/kouen-terminal/commit/b55cc6299c4241e70201d58efc782c4f051f60a2))
- Browser cannot show in cmd+b and browser button ([`e530205`](https://github.com/Vit129/kouen-terminal/commit/e53020518bf1356cf2c1ac1ee84779c10d0735b8))
- Browser pane reuse guidance and skill routing paths ([`9bd07a4`](https://github.com/Vit129/kouen-terminal/commit/9bd07a4afedd1f3380a384456d847b5ceb330b3c))
- Replace graphify CLI trigger with graph-report skill ([`528c166`](https://github.com/Vit129/kouen-terminal/commit/528c1661a85d0dcf6bb08c35ed2b20b9d070229a))
- Cmd+W closes browser pane (intercept before WKWebView consumes it) ([`02e49cd`](https://github.com/Vit129/kouen-terminal/commit/02e49cd553cf2172ea6e88ef0e29205ecb544d15))
- Disarm prefix key on mouse click to prevent swallowing Cmd+\ ([`fd7a5f0`](https://github.com/Vit129/kouen-terminal/commit/fd7a5f075e7abf1dc1b2d69bd5638ba9ba72873d))
- Prevent git panel double-refresh blink after commit/push ([`c9dc884`](https://github.com/Vit129/kouen-terminal/commit/c9dc884c487a3b89f2188566ca1afc4a20507ef4))
- Prevent git push from hanging in daemon ([`1ddc27d`](https://github.com/Vit129/kouen-terminal/commit/1ddc27d31485e753a3182097e8f654329f755be4))
- Release unclaimed TerminalHostViews after PaneContainerView build ([`0430ed8`](https://github.com/Vit129/kouen-terminal/commit/0430ed879698facf0720935029e6a18f3197b206))
- Stop per-pane AI controllers and browser network log from leaking ([`e642997`](https://github.com/Vit129/kouen-terminal/commit/e64299781218c800fa52b220ad1e766d83e911d2))
- Memory leak audit — pane lifecycle + AI controller cleanup ([`38fa427`](https://github.com/Vit129/kouen-terminal/commit/38fa4273c85187230dca073db3eff93b44597987))
- Don't fail make install when open has no window server ([`9d7de27`](https://github.com/Vit129/kouen-terminal/commit/9d7de27a34b693d2a776695676af195800c81d7f))
- Pin session worktree to shell cwd, not deepest foreground descendant ([`8ad328d`](https://github.com/Vit129/kouen-terminal/commit/8ad328d98c431cea72275fae931f82cbd0e6652e))

## [3.9.2] - 2026-06-22

### Documentation
- CHANGELOG for v3.10.0 — terminal flash fix ([`0fc4fd9`](https://github.com/Vit129/kouen-terminal/commit/0fc4fd9585a0d5383969a87b84ca6ec613d20c3e))

### Fixed
- Prevent hover flickering between shortcut and close button ([`f140efb`](https://github.com/Vit129/kouen-terminal/commit/f140efb94dfe414dbe33a85bb1ef8c70e939c587))
- Terminal flicker on ⌘\ — remove layoutSubtreeIfNeeded, use split.layout() ([`bf96fd1`](https://github.com/Vit129/kouen-terminal/commit/bf96fd111f1ca418958c4921dc7f82a7043f14a6))
- File preview open/close flicker — replace layoutSubtreeIfNeeded with layout() ([`ce0603f`](https://github.com/Vit129/kouen-terminal/commit/ce0603f7cf390e494f8b203aac357bc9e441123a))
- Eliminate tab switch flash — cache PaneContainerView per tab, hide/show instead of rebuild ([`de39a37`](https://github.com/Vit129/kouen-terminal/commit/de39a37c8d5718ed2bce51b94969108291e3f762))
- Eliminate terminal flash on sidebar, tab switch, split, and file preview ([`6dc94fe`](https://github.com/Vit129/kouen-terminal/commit/6dc94fe325ad45bd22a593e9cc02e4b8ac0a3ab7))

## [3.9.1] - 2026-06-22

### Added
- Sessions tab shows only idle worktrees (active ones already have sessions) ([`f5b78aa`](https://github.com/Vit129/kouen-terminal/commit/f5b78aab2ad9f9a1bf7154cc5fb1885fa4361c4c))
- Worktrees collapsed by default in Sessions sidebar ([`b990f64`](https://github.com/Vit129/kouen-terminal/commit/b990f6412b41b7c03d9e75cd65c5c7842714e17a))
- Enable Worktrees tab in Git panel (was hidden, code already existed) ([`8e55be6`](https://github.com/Vit129/kouen-terminal/commit/8e55be6c80ea0f1656ef752b3a558289aec6f9aa))
- Git worktree panel — fix click conflict, add merged status indicator ([`78badf8`](https://github.com/Vit129/kouen-terminal/commit/78badf89c37e3b23ff3e12e142d8c3035ed274c9))

### Changed
- Remove worktrees from Sessions sidebar — now lives in Git tab only ([`ffec772`](https://github.com/Vit129/kouen-terminal/commit/ffec7720fa5f50f896356d8f33d6463d5aa733f3))

### Documentation
- Archive completed plans (P28, sidebar SwiftUI, core split) ([`3718eb0`](https://github.com/Vit129/kouen-terminal/commit/3718eb004249024cc36a68fe78c51a97549f5e5f))
- Update plans INDEX — archive P26/P27, add SwiftUI migration as active ([`c009000`](https://github.com/Vit129/kouen-terminal/commit/c00900075578e17e1c63a816604e0bb9da92d052))
- Add RL-052/053 lessons + sidebar SwiftUI knowledge (MainActor freeze, @Observable loop) ([`3e43b89`](https://github.com/Vit129/kouen-terminal/commit/3e43b893de559b60ae3ffe067775da4e88c867df))

### Fixed
- Sidebar hang on z/cd — add re-entrancy guard to rebuildRows ([`36319f9`](https://github.com/Vit129/kouen-terminal/commit/36319f99ce8f506b162d3f7bf5da947ee7eb90ba))
- Sidebar freeze on z/cd — move Process.waitUntilExit off main thread ([`0d2196a`](https://github.com/Vit129/kouen-terminal/commit/0d2196a07d7e9689b40712ed3d7415f1d206b15a))
- Sidebar infinite re-render loop — @ObservationIgnored on gitMetadataCache ([`5587b02`](https://github.com/Vit129/kouen-terminal/commit/5587b02acfad03eb10deb5e0068ef058c6eb6e99))
- Worktree remove button — double-click for cd, single-click for ✕ button ([`92456d5`](https://github.com/Vit129/kouen-terminal/commit/92456d50b7232027994f2695678f5f741d816641))
- Worktree remove — confirmation alert, --force flag, proper error capture ([`fc60a68`](https://github.com/Vit129/kouen-terminal/commit/fc60a68d75a97ca67faeca1f38d7ce283ada4bfb))
- Worktree single-click cd + skip click on ✕ button area ([`fcd9032`](https://github.com/Vit129/kouen-terminal/commit/fcd90328f8dd4fae90af5b626b2f7a35b14dbec5))
- Worktree remove button — use SoftIconButton (same pattern as working browser tab close) ([`eb5e565`](https://github.com/Vit129/kouen-terminal/commit/eb5e5657d8ce49529380be8ceaa70e6bb9d00284))
- Worktree card — use mouseUp pattern (same as BrowserTabButton) for reliable click handling ([`1e7d389`](https://github.com/Vit129/kouen-terminal/commit/1e7d3893c0c2464caf0402ef51b6f5b0670ceeb6))
- Worktree panel flicker — cache output, skip rebuild if unchanged ([`333d352`](https://github.com/Vit129/kouen-terminal/commit/333d3520c76307f5c8f4fb6cc19115f4146cc363))
- V3.9.1 — sidebar freeze fix, git worktree panel, click handling ([`74ae012`](https://github.com/Vit129/kouen-terminal/commit/74ae01214ecb9be26b20a60ace4d4b7d775415f2))

## [3.9.0] - 2026-06-22

### Added
- Wire git-cliff into full-cycle.sh for auto CHANGELOG + release notes ([`a95f257`](https://github.com/Vit129/kouen-terminal/commit/a95f2570747460fc08c2b09bd98cda54e854655e))
- Replace NSTableView with SwiftUI List (Option B) ([`72cf712`](https://github.com/Vit129/kouen-terminal/commit/72cf71253865fbb3cbbab4d96dad809de12cbce1))

### Changed
- Extract HarnessCommands + HarnessSettings from HarnessCore ([`fdcbd58`](https://github.com/Vit129/kouen-terminal/commit/fdcbd58bd20c4a465dce030e5ee90a70c3e0a26f))

### Documentation
- Update agent-memory with RL-051 (table row crash) + harness-mcp completion ([`1cc11b0`](https://github.com/Vit129/kouen-terminal/commit/1cc11b04491239ec968d6f1d74264bb26d7ee596))
- Add sidebar race fix plan + update CONTEXT.md ([`9147e79`](https://github.com/Vit129/kouen-terminal/commit/9147e7912727c8ac2f837cda150cf589b36f7644))
- Add sidebar SwiftUI List migration plan (Option B) ([`23965f4`](https://github.com/Vit129/kouen-terminal/commit/23965f49c1157d3c11664edaca0555317c0fbc33))
- Update agent-memory indexes, regenerate graphify summary (post-migration) ([`dd26bde`](https://github.com/Vit129/kouen-terminal/commit/dd26bde979e1b58b4c39f662692e5387356a32e2))
- Add SwiftUI migration plan (Phase 1/2/3 component map) ([`39a32e0`](https://github.com/Vit129/kouen-terminal/commit/39a32e040931cd14a1159b38d901de587838c520))

### Fixed
- Sidebar crash on z/cd/⌘\ — reloadData before accessing table rows ([`e611e78`](https://github.com/Vit129/kouen-terminal/commit/e611e7886bbf7e0dfaa672fb3673bf4d813a8508))

## [3.8.0] - 2026-06-22

### Added
- CLI infrastructure — permissions, skill-trigger hook, graphify hint ([`502e5ec`](https://github.com/Vit129/kouen-terminal/commit/502e5ecb08f46dce9b28766a5b87624a8bfbb9c3))
- CLI infrastructure ([`4e2d43a`](https://github.com/Vit129/kouen-terminal/commit/4e2d43a5dcfa4393b7a6186b56b1806dc0145b99))
- Finalize Git tab with auto-staging by default ([`377da37`](https://github.com/Vit129/kouen-terminal/commit/377da370e3c8f8d51a8471cdb3905a8e66a33211))
- Route Git commands via IPC to HarnessDaemon ([`88a89f7`](https://github.com/Vit129/kouen-terminal/commit/88a89f742120dd2c3420c4b82de1fd48048f24ed))
- Fix crashes + worktree isolation + harness-mcp browser tools complete ([`b8c26ea`](https://github.com/Vit129/kouen-terminal/commit/b8c26ea3666a200290f602f7fd626798a4a697da))
- Add IPC protocol versioning to identifyClient handshake ([`a0bc5a0`](https://github.com/Vit129/kouen-terminal/commit/a0bc5a03f40ebec41781f6733e210e6cc788dbd6))

### Changed
- Decompose ContentAreaViewController into three focused coordinators ([`feaab9b`](https://github.com/Vit129/kouen-terminal/commit/feaab9b528a4892b13c711bbe3c5ee33c939129a))
- Centralize zombie-hold pattern into ZombieHoldRegistry ([`3d09e11`](https://github.com/Vit129/kouen-terminal/commit/3d09e114ff8a14393d565d8efc8b112a8eeec5da))
- Replace stringly-typed snapshotChanged userInfo with SnapshotChangedPayload ([`3302026`](https://github.com/Vit129/kouen-terminal/commit/3302026d8ace2891124da9a78db3fb8b733b7de2))
- Harness-terminal ([`0faeab2`](https://github.com/Vit129/kouen-terminal/commit/0faeab285585b57f0558f767858990202093223f))

### Documentation
- CONTEXT.md — P28 complete (all 3 phases + RL-048) + CLI infrastructure ([`80c8f1f`](https://github.com/Vit129/kouen-terminal/commit/80c8f1f89fee121b9a3263d75cb39914e3450141))
- CONTEXT.md P28 completion ([`0381090`](https://github.com/Vit129/kouen-terminal/commit/03810900e98ec1d48a137b83864307372f6760f9))

### Fixed
- Full-cycle push only new tag, not all tags — prevents rejection of existing tags ([`4f9b77f`](https://github.com/Vit129/kouen-terminal/commit/4f9b77f0d21ce9cf8cac2fa1f28ec996065b71c9))
- Full-cycle tag push fix ([`2b44272`](https://github.com/Vit129/kouen-terminal/commit/2b44272c71c90412a5321a0fa6f36e7d3d76aeb1))
- Warn + prompt when CHANGELOG entry missing before gh release ([`17dad96`](https://github.com/Vit129/kouen-terminal/commit/17dad961380206577d348074aa709acabd22ca6c))
- Full-cycle CHANGELOG guard ([`cdbc56b`](https://github.com/Vit129/kouen-terminal/commit/cdbc56b17f4a80e317fdddbd39e53c95341e5d31))
- Replace bash-only ${confirm,,} with tr for zsh compatibility ([`9fbe9bd`](https://github.com/Vit129/kouen-terminal/commit/9fbe9bde7945f2b02af56df436ae8f3b6d73db46))

## [3.7.0] - 2026-06-21

### Added
- P28 AI browser control — snapshot/network/storage + round-trip fix ([`d28042f`](https://github.com/Vit129/kouen-terminal/commit/d28042f5ab0e924f7f2fca5e9ffa0f37ca3f8463))

## [3.6.2] - 2026-06-21

### Added
- Pane drag-and-drop — model, IPC, coordinator, UI ([`9321449`](https://github.com/Vit129/kouen-terminal/commit/9321449dca016fbc90c0e966f1749c5ea9cfab44))
- Add MCP status and Add/Remove MCP button to agent list ([`5d3a0bb`](https://github.com/Vit129/kouen-terminal/commit/5d3a0bbd41945cbb701fae8789319a91f96593af))
- Bundle harness-mcp in Harness.app and add harness-cli mcp command ([`34788e1`](https://github.com/Vit129/kouen-terminal/commit/34788e1ead840b34509c6268c280a0935f591b98))
- Add ⌘I inline terminal AI chat (P26 Path B) ([`201f47d`](https://github.com/Vit129/kouen-terminal/commit/201f47d61501a242d8c03bf7007bf5d65e89b48f))
- AI chat agent selector (⌘I pill click) + bump 3.6.1 build 162 ([`20895ea`](https://github.com/Vit129/kouen-terminal/commit/20895ea592a853f3750f73bbce643acd96233c6b))

### Documentation
- Update split shortcuts to ⌘D/⌘⇧D across all references ([`91cb040`](https://github.com/Vit129/kouen-terminal/commit/91cb040204c333df22800848f9a4a52b4820f096))
- P27 plan — pane drag-and-drop reorder ([`8db5717`](https://github.com/Vit129/kouen-terminal/commit/8db5717bcce7a9f141bb17a150f2af1083f89b3d))
- Correct P8 nonisolated rule, update MCP tool count, add P26 terminal chat design ([`1bd43b0`](https://github.com/Vit129/kouen-terminal/commit/1bd43b07cad23b44dfc64155358c81a7eb58dcdb))
- Simplify terminal chat to use CLI print mode directly ([`635d0dc`](https://github.com/Vit129/kouen-terminal/commit/635d0dc96f5924f7f290e7345b033bf2dc0defd2))
- Add MCP setup guide to AGENT-HANDBOOK + update P26 plan ([`acf3937`](https://github.com/Vit129/kouen-terminal/commit/acf3937b5b7aea6835361f250e078c999f72883d))
- Update mcp-server.md — 27 tools, 6 categories, agent config wiring ([`cc80dc3`](https://github.com/Vit129/kouen-terminal/commit/cc80dc344bc68c830dc6633001d6887bc15b5bb1))
- Fix last lowercase agent-memory ref in AGENTS.md ([`87ddeeb`](https://github.com/Vit129/kouen-terminal/commit/87ddeeb45fff5be01c37bf49d6c9b4c3fce10fde))
- Update knowledge, CONTEXT, MEMORY, graphify for browser redesign session ([`76f0c97`](https://github.com/Vit129/kouen-terminal/commit/76f0c972eb89a485557bd6351146dbb18465f719))
- Update competitive position to v3.6.1 — gaps closed, new USPs ([`be15d3a`](https://github.com/Vit129/kouen-terminal/commit/be15d3a6a2a2fefdb5d2699565abd8daf830aede))
- Honest assessment — MCP and AI chat are partial, not fully functional yet ([`ab96468`](https://github.com/Vit129/kouen-terminal/commit/ab96468f2a19ea361dbab06e989e70e4a70b7017))

### Fixed
- Terminal blinks on ⌘D split / ⌘W close / tab switch (CASE-025)\n\nThe pane rebuild path (reloadIfNeeded) didn't wrap the structural\nchange with presentsWithTransaction like the file editor split does.\nMetal presents an empty frame between remove-old-container and\nnew-container-first-layout. Fix: set presentsWithTransaction=true\nbefore rebuild, release in CATransaction completion block after\nthe first layout pass. ([`f7b1381`](https://github.com/Vit129/kouen-terminal/commit/f7b13811f60e104aafec0e8494c6e3c4322c3186))
- Browser tab close button unclickable (CASE-038)\n\nNSClickGestureRecognizer on BrowserTabButton intercepts the close\nNSButton's mouse events even with delaysPrimaryMouseButtonEvents=false.\nFix: override hitTest to return closeBtn directly when the click is\nwithin its frame, bypassing the gesture recognizer entirely. ([`d08c668`](https://github.com/Vit129/kouen-terminal/commit/d08c668d84e27ce171c4077e20e69a9be1544a0a))
- Window not showing on launch + remove built-in AI chat/search panels ([`ccfcc6a`](https://github.com/Vit129/kouen-terminal/commit/ccfcc6ae5b0dd8e4a78730c107c16cecc999ae9c))
- Extend zombie-hold durations and plug event monitor leak ([`61d5ff6`](https://github.com/Vit129/kouen-terminal/commit/61d5ff63700abe11d64993ac1393fa186b57ef2c))
- Crash on ⌘⇧Arrow split + hang on fetchRepoName ([`b706ed1`](https://github.com/Vit129/kouen-terminal/commit/b706ed10eaef519a57aaa47a049299fb9bfc99e3))
- Wire notch notifications and split placement ([`0dbc69d`](https://github.com/Vit129/kouen-terminal/commit/0dbc69dd60c8338ee25bf0cc045c7f888b32bc9b))
- Wire missing command prompt verbs (z, view, edit, agent, shell tools) ([`fe0a2ad`](https://github.com/Vit129/kouen-terminal/commit/fe0a2adbf2714fa05ed94a22bf0ccdd10e85f751))
- Replace button with mouseDown drag grip for pane reorder ([`ce4bbc2`](https://github.com/Vit129/kouen-terminal/commit/ce4bbc26392366f050be2e13eb44e4048df1d06c))
- Smoother drop zone + disable center swap for 2-pane layout ([`7a8aac3`](https://github.com/Vit129/kouen-terminal/commit/7a8aac3def0045df4a35d29fcf4c5d7528e0d67d))
- Tab bar shows wrong branch when agent uses worktree ([`d98cf58`](https://github.com/Vit129/kouen-terminal/commit/d98cf58e51ebbc6aadb820daf9377f017995afd3))
- Split pane inherits worktree path instead of repo root ([`d25d3f8`](https://github.com/Vit129/kouen-terminal/commit/d25d3f8fdfbfdb4501c5bd91192c224024140788))
- Browser pane opens at root level (right of all terminals) ([`e258542`](https://github.com/Vit129/kouen-terminal/commit/e2585422cfbd6de726256f9025fe2d0a4efe72a7))
- Widen pane/sidebar dividers from 1px to 2px (centralized) ([`7021fce`](https://github.com/Vit129/kouen-terminal/commit/7021fce1c0a39ecf143d62d1692840f13b6e79c1))
- Browser pane auto-retries when localhost server disconnects ([`2a8dd99`](https://github.com/Vit129/kouen-terminal/commit/2a8dd99c12b35c9ab052f81c7da20464a8d22bb0))
- Browser auto-close after 30s unreachable (10 retries × 3s) ([`00a1a69`](https://github.com/Vit129/kouen-terminal/commit/00a1a69e7ccd390cb81b711e117e2c6c6d2aa189))
- Update release notes to 3.6.1 ([`701fe1d`](https://github.com/Vit129/kouen-terminal/commit/701fe1df8bdcf317781c8b0f72323d9f9f1d4970))
- Install missing NSEvent monitor + retire-hold in detachHosts ([`b616164`](https://github.com/Vit129/kouen-terminal/commit/b616164be35b8bc8cadcc09cbd4e6df623363acd))
- Universal retire-hold via removeFromSuperview override — covers all free paths ([`7d6f6fa`](https://github.com/Vit129/kouen-terminal/commit/7d6f6fae187c32cbd32339320776eee2ad981243))
- Remove workaround section from kiro plan ([`70d6310`](https://github.com/Vit129/kouen-terminal/commit/70d6310e879a6b9de4cced1f19de30d750ee9ecd))
- Browser toolbar URL field not expanding + translucent blur (CMUX-style) ([`df2fb60`](https://github.com/Vit129/kouen-terminal/commit/df2fb6078c00443764b48fcb8a5cbc060ebd42e4))
- Browser tab bar translucent blur + always visible + close last tab closes pane ([`4b1c59f`](https://github.com/Vit129/kouen-terminal/commit/4b1c59f4e11bf6eb53d3d4826610fbccff17010c))
- Browser tab close button hit target 14px→20px ([`7e38fea`](https://github.com/Vit129/kouen-terminal/commit/7e38feadee9b542357c077573c39e7f2f6af7fd3))
- Close last browser tab calls closeBrowserPane directly + debug logs ([`5aea5b9`](https://github.com/Vit129/kouen-terminal/commit/5aea5b9b576085ecf94d7d0d6da7f71183bb4054))
- Browser tab close — add mouseUp override, keep gesture as backup ([`1ac0a6e`](https://github.com/Vit129/kouen-terminal/commit/1ac0a6e99c2b14a9bde5d525d45f75b0b783db58))
- Browser tab close — replace NSScrollView with plain NSView (scroll view eats mouse events) ([`83939be`](https://github.com/Vit129/kouen-terminal/commit/83939bed5250bedcf56f9702aee527053c6e8f0a))
- Browser tab close button — use SoftIconButton (same as working close pane button) ([`2bf59cb`](https://github.com/Vit129/kouen-terminal/commit/2bf59cbb728f1a62cd14d3001d53c9c7b8e5490c))
- Tab close — handle in mouseUp directly (button action never fires with isTransparent) ([`c68f9c2`](https://github.com/Vit129/kouen-terminal/commit/c68f9c27b780a3551d0ac2f8d39661769adf8d4f))
- REMOVE gesture recognizer from BrowserTabButton — it consumed all clicks before mouseUp ([`32071eb`](https://github.com/Vit129/kouen-terminal/commit/32071ebc490842d0406525d69f5cbbf00dd56f1e))
- Nonisolated on keyDown/keyUp/displayTick, retire-hold on TabBar+FlippedView ([`45c386e`](https://github.com/Vit129/kouen-terminal/commit/45c386e67edc1e47c3c4f5703e5bba578708c346))

## [3.5.1] - 2026-06-20

### Added
- Implement 6 competitive-gap features vs Warp/iTerm2 ([`016bc9a`](https://github.com/Vit129/kouen-terminal/commit/016bc9ab645472365956c64d6ad76177642a4442))
- Modernize browser pane + add harnessSpawnAgent MCP tool ([`d64fe89`](https://github.com/Vit129/kouen-terminal/commit/d64fe89d2b471652432a6a5b07ae842189a08d2a))
- Metal shader overlay effects (scanlines, grain, vignette, crt) ([`a1f0520`](https://github.com/Vit129/kouen-terminal/commit/a1f05203eddde748cf99bf4faa626077861e4aac))
- Wire shaderEffect from HarnessSettings and add inline AI completion (⌥Space) ([`ded8dfd`](https://github.com/Vit129/kouen-terminal/commit/ded8dfdda7f183b5b7b0ab421a9f976628dc891a))
- AI chat, block terminal, plugins, settings export, browser modernization, MCP agent spawn, Metal shaders, inline AI completion ([`e5aad88`](https://github.com/Vit129/kouen-terminal/commit/e5aad888c73d1279d1a73c243bcba31d9d17b313))
- P23 SSH remote host manager UI — Settings Remote page + window title strip ([`5377a73`](https://github.com/Vit129/kouen-terminal/commit/5377a73e50e3c7fae730cbe51c71b75e16a1c19d))

### Documentation
- Update P4/ACP/MCP index, archive, and competitive position ([`3c23f8a`](https://github.com/Vit129/kouen-terminal/commit/3c23f8a0bc5f82236bcb95323c79c1fddaa1658e))

### Fixed
- RL-040 zombie crashes + tab branch probe + sidebar height + notification icon ([`8c55757`](https://github.com/Vit129/kouen-terminal/commit/8c55757aa676e0fbb31bddde45a369a55e5e6475))
- CWD tracking — skip shell-only poll when subprocess holds foreground ([`f60542a`](https://github.com/Vit129/kouen-terminal/commit/f60542ad3582806ce0f7c70decba2a59e927e9f4))
- Resolve 6 RL-040 zombie crashes on macOS 26 / Swift 6.3.2\n\nAll crashes share the same root cause: @objc thunk executor check\n(swift_task_isCurrentExecutorWithFlagsImpl) dereferences freed self.\n`nonisolated` does NOT suppress this on Swift 6.3.2.\n\nFixes:\n- HarnessTerminalSurfaceView: stopDisplayLink() in viewWillMove(toWindow:nil)\n- TerminalTabBarView: static retiredBars[] retire-hold (500ms)\n- HarnessWindow: static retiredWindows[] on close() + early contentView guard\n- PrefixKeymap: nonisolated(unsafe) capture bypasses executor check\n\nAlso fixes pre-existing Sendable compile errors in ClaudeDirectClient,\nInlineAICompletionController, and HarnessAIChatView. ([`80c49fb`](https://github.com/Vit129/kouen-terminal/commit/80c49fbf30d3997b24b6e043ec965f644e1b489c))
- Resolve 14 bugs in Remote settings, WindowTitleStripView, RemoteHostsService\n\n- hitTest() now passes through to child NSButtons (remoteBadge clickable)\n- saveRemoteHostClicked: duplicate-name guard + reconnect on rename of active host\n- connectRemoteHostClicked: no longer overwrites saved config for existing hosts\n- sshArgValue(after:) supports glued arg form (-p2222)\n- Connect button enabled for new unsaved hosts when form is filled\n- Settings VC observes activeHostDidChange (replaces stale 0.5s timer)\n- Remove ambiguous 'identity' keyword from Advanced page search\n- Guard constraint activation in buildRemotePage (no accumulation)\n- disconnect() only posts notification when state actually changed\n- Replace magic index 6 with SettingsWindowController.pageRemote constant\n- uniqueRemoteName() reads live store instead of stale in-memory list\n- Remove redundant refreshRemoteBadge() from applyChrome()\n- Remove dead initial build of pages 5/6 in layoutShell() ([`da3a2b4`](https://github.com/Vit129/kouen-terminal/commit/da3a2b436fdd510eb8486f5511acfa5a5c5d6f00))
- RL-040 crash in ContentAreaViewController.installCopySelectionToast()\n\nSame pattern: @Sendable closure's _checkExpectedExecutor crashes on\nzombie event chain. Use nonisolated(unsafe) capture to bypass the\nexecutor check (safe: NSEvent monitors always fire on main thread). ([`9d2b547`](https://github.com/Vit129/kouen-terminal/commit/9d2b547b042232ae7b203281cac26184b75025e8))
- Notification attributed to Script Editor instead of Harness\n\nOn macOS 26 where UNUserNotificationCenter is disabled (crash),\n`tell application id \"com.robert.harness\"` via osascript doesn't\nattribute the notification to our app (shows under Script Editor\nin System Settings). Switch to `tell application \"Harness\"` (by\nname) which macOS resolves correctly. ([`7b8cdd3`](https://github.com/Vit129/kouen-terminal/commit/7b8cdd36b60564f1b774522a2e985ff1daa920fb))

## [3.5.0] - 2026-06-20

### Added
- Sidebar 2-line layout (branch + cwd) + top bar always shows branch ([`d104eeb`](https://github.com/Vit129/kouen-terminal/commit/d104eeb99adda79d9c275c37b730a5e02a98eca8))
- ⌘I opens Agent Notch panel — select notifying agent directly ([`804b876`](https://github.com/Vit129/kouen-terminal/commit/804b87647423171170ba9c3602a276d7a474f8bc))
- Persistent notch peek — stays until user clicks, no auto-dismiss ([`0b03021`](https://github.com/Vit129/kouen-terminal/commit/0b0302196fd937c1dbc3bae896d6ab8e716a43fb))
- Harness-cli install-tools — one command to install all shell tools ([`340fc4e`](https://github.com/Vit129/kouen-terminal/commit/340fc4ee224f27eb071f852e14d6dfe61708e4b4))
- File click action setting + tab pill branch-first + worktree grouping fix ([`c1543e9`](https://github.com/Vit129/kouen-terminal/commit/c1543e9b2fa84a71ede3e7f5254e2784463c37ae))

### Documentation
- Add sidebar 2-line + top bar branch to knowledge/ui/tab-bar.md ([`51faac6`](https://github.com/Vit129/kouen-terminal/commit/51faac619d36e0986b512990ab2e32194157080e))
- Add P25 iOS/iPadOS support plan ([`b9b4559`](https://github.com/Vit129/kouen-terminal/commit/b9b45591b06282b6a50c0965aed2966d4d618cca))
- Add competitive position, git branch isolation to knowledge ([`5c9eace`](https://github.com/Vit129/kouen-terminal/commit/5c9eace60b6cb7993af007f526825eac3f9fc1bc))

### Fixed
- Enable macOS toast notifications via osascript fallback ([`7d18722`](https://github.com/Vit129/kouen-terminal/commit/7d18722e016082b5e018f80aeb1169a8db37ca39))
- Always auto-isolate into worktree on branch switch ([`63a5278`](https://github.com/Vit129/kouen-terminal/commit/63a52788641d0c4e9ff205cc182164869a6b278b))

## [3.4.0] - 2026-06-19

### Added
- F4 git worktree sidebar + F6 session row density ([`1ef8b28`](https://github.com/Vit129/kouen-terminal/commit/1ef8b28b8737a40ff59b06e66565379924fac01d))
- Harness.json + agent auto-start + ⌘R/⌘. run scripts ([`fa5cc73`](https://github.com/Vit129/kouen-terminal/commit/fa5cc73143bb8c9a6914ba84815721e2be22d50e))
- Worktree-per-session model — group by repo, CLI --worktree ([`0f62a4c`](https://github.com/Vit129/kouen-terminal/commit/0f62a4cbfc3a0960ba5073550ced6f5894f1997f))
- Worktree-per-session isolation model ([`0ed9030`](https://github.com/Vit129/kouen-terminal/commit/0ed9030a4ff74ce411edaeee70c9f1ecf96057ff))
- P24 Phase 3 — GitHub PR/CI integration + browser multi-tab ([`86f99cf`](https://github.com/Vit129/kouen-terminal/commit/86f99cf17f90ab16f4a89b00b44b7f9b9c7355ba))
- Enable LSP integration in FileViewerViewController preview ([`cf40de5`](https://github.com/Vit129/kouen-terminal/commit/cf40de58243b27425236b5d676ae780487196e6f))
- P24 Phase 2+4 complete — worktree auto-isolate/archive + polish ([`944b2be`](https://github.com/Vit129/kouen-terminal/commit/944b2bec47a7ebf5f6ec8f885bf6795b9e1e12f0))

### Documentation
- Update agent-memory, knowledge index, graphify for P24 completion ([`641530c`](https://github.com/Vit129/kouen-terminal/commit/641530c8afa14e2116ed81c7c41e3d7ad3a9bd06))

### Fixed
- Prevent self-kill in make start + remove close confirmations ([`8dca1b6`](https://github.com/Vit129/kouen-terminal/commit/8dca1b65fec00ad9b4ba55a0312d8f686ed2e3cf))
- Improve text contrast visibility with transparent windows ([`fe39de7`](https://github.com/Vit129/kouen-terminal/commit/fe39de70aeb93d296d20afbadba7ce65b0a1a0e1))
- RL-040 zombie surface view use-after-free on macOS 26.5\n\n- Add `guard window != nil` to mouseMoved (matches keyDown/keyUp)\n- Hold detached hosts 500ms during pane tree rebuild so in-flight\n  AppKit events (tracking area mouseMoved, queued keyDown) drain\n  before ARC frees unreused hosts\n\nAddresses EXC_BAD_ACCESS in swift_task_isCurrentExecutorWithFlagsImpl\nat @objc thunk boundary when AppKit dispatches events to freed\nHarnessTerminalSurfaceView instances. ([`c09618d`](https://github.com/Vit129/kouen-terminal/commit/c09618deb009e237cee4be0a322c46342d8f1ed0))
- Restore active pane focus on tab switch back ([`6004f7f`](https://github.com/Vit129/kouen-terminal/commit/6004f7ff761644eb32542d9b4a182c1e1d2863c8))
- Sidebar agent icon uses branding color instead of status color ([`e9e8c48`](https://github.com/Vit129/kouen-terminal/commit/e9e8c48ecfb4c25814488bac694b350d4f8a5a8e))
- Sidebar agent icon uses centralized settings color (same as tab pill) ([`44ad734`](https://github.com/Vit129/kouen-terminal/commit/44ad73475f2bb91ad7f6334aad2de443df0c6415))
- Git branch probe now updates all tabs sharing same cwd ([`79af190`](https://github.com/Vit129/kouen-terminal/commit/79af190ef85d755e975bd1680953b6f6a1313ba9))
- Invalidate NSTextInputContext on view removal (RL-040) ([`228c9a6`](https://github.com/Vit129/kouen-terminal/commit/228c9a6d4023bcedf4a2d594b3b52b374d458c50))
- Prevent zombie view crashes on macOS 26 / Swift 6.3 ([`df98148`](https://github.com/Vit129/kouen-terminal/commit/df98148562325392ad94a3d8b80b670e79b6ba8b))
- Suppress selectPane feedback during session switch ([`061ecb3`](https://github.com/Vit129/kouen-terminal/commit/061ecb31bb7818b6d0d720ca9ea04a0335d76dc9))
- Retain removed FileTreeNodes across render cycle ([`295bf1d`](https://github.com/Vit129/kouen-terminal/commit/295bf1dc1eeb4cdb5b13575efc7d13a301cd0791))
- Detect relative file paths not starting with / ~ or . ([`55e1df9`](https://github.com/Vit129/kouen-terminal/commit/55e1df9fb8d006eb3488e0710d905487d4a81852))

## [3.3.0] - 2026-06-18

### Added
- Output triggers + notch peek when active ([`a9822a8`](https://github.com/Vit129/kouen-terminal/commit/a9822a8409b887a32c76bb30dcb1add4d43b8003))
- Graphify auto-load via GRAPH_SUMMARY.md ([`5885bf3`](https://github.com/Vit129/kouen-terminal/commit/5885bf35d520093ffd749a5077925791fcf53cb4))
- Liquid Glass adaptive transparency (macOS 26+) ([`a1d73af`](https://github.com/Vit129/kouen-terminal/commit/a1d73af6e1b6fac2d3d457b9ce736e2a330e911b))
- Add loading state + success/error toast to Fetch/Pull/Push ([`1f30714`](https://github.com/Vit129/kouen-terminal/commit/1f30714d768fe09631a7cc59704483a0dab3369f))
- Sync button shows ahead/behind count (Push ↑2, Pull ↓1) ([`4e4267a`](https://github.com/Vit129/kouen-terminal/commit/4e4267a23597f165d2892259707065fe598a9158))
- Keybinding single source of truth, IDE-like navigation, cheat sheet ([`cf1ae5b`](https://github.com/Vit129/kouen-terminal/commit/cf1ae5ba57239953389167cfadc50dce1ae6981d))
- Full-cycle now auto-tags + creates GitHub release ([`5507738`](https://github.com/Vit129/kouen-terminal/commit/55077382713622ccd81355c6e7c2019f25dcf845))

### Changed
- Scrollback streaming compaction + renderer micro-batch optimizations ([`a5a10ad`](https://github.com/Vit129/kouen-terminal/commit/a5a10ad8d5ba7c844e1aa2639338031907fed0f5))
- SalvageRowKeys memo + off-main output coalesce; feat: file tree reveal ([`36ab4a9`](https://github.com/Vit129/kouen-terminal/commit/36ab4a91321aec28829999b6ed4eabdf7caabf05))
- Remove GRAPH_SUMMARY auto-load, use graphify-mcp instead ([`49bbb12`](https://github.com/Vit129/kouen-terminal/commit/49bbb1209152294889b48742316b910862f2da1f))
- Unify make start as single entry point, remove s1-s4 aliases ([`042e98a`](https://github.com/Vit129/kouen-terminal/commit/042e98add3ef08944853e9db4cf757257a3b6084))
- Skip BoardViewController rebuild when columns unchanged (fixes NSTextField leak) ([`2d3a577`](https://github.com/Vit129/kouen-terminal/commit/2d3a577889e5d3a234adf83883a564157dc2214f))
- Unify pane/session shortcuts to ⌘/⌘⇧ only\n\n- ⌘[/⌘] now cycles panes (was session navigation)\n- ⌘⇧[/⌘⇧] now navigates sessions (was ⌘[/⌘])\n- ⌘W closes pane (was ⌘⌥W), ⌘⇧W closes tab (was ⌘W)\n- ⌘⇧Arrow for directional pane focus (was ⌘⌥Arrow)\n- Fix: ⌘⌥Arrow no longer intercepted by readline handler\n- Matches iTerm2/Ghostty/Warp convention: ⌘=pane, ⌘⇧=tab/session ([`f7d4619`](https://github.com/Vit129/kouen-terminal/commit/f7d4619925c575ada623ed4bd8117ef66a4d3cf7))
- Extract BannerShortcutRegistry as single source of truth\n\nWelcome banner shortcuts now read from BannerShortcutRegistry\ninstead of hardcoded arrays. The registry has a showInBanner flag\nfor each shortcut, so future changes only need one edit. ([`2bc73dc`](https://github.com/Vit129/kouen-terminal/commit/2bc73dc176fbfa4ca5e133877b17823af3a1e2bb))

### Documentation
- Update memory, playbook, graphify for session work ([`b6c97ba`](https://github.com/Vit129/kouen-terminal/commit/b6c97baf8e6275a4644a0cd944552d562309b0ce))
- Update README + agent-memory; refresh graphify graph ([`2b6cbd8`](https://github.com/Vit129/kouen-terminal/commit/2b6cbd8716f87edc5e0c65fdfcc1a4656f9a5217))
- Shelve p20/p21 — terminal-first agent flow sufficient for now ([`acec0bc`](https://github.com/Vit129/kouen-terminal/commit/acec0bcfb140dc903cad5fa3181d771cdf5210b2))
- Close P16 (board) + P22 (perf) — both done ([`e1c7027`](https://github.com/Vit129/kouen-terminal/commit/e1c7027ce93e71b3edeab6a8f4729907cc533e68))
- Add zombie-crash-macos26 knowledge doc (CASE-034→040 consolidated) ([`267dfc0`](https://github.com/Vit129/kouen-terminal/commit/267dfc0c8cf374a7e2537df1a0ee2b4bf2e71b4e))
- Add NSTextField leak knowledge doc (P20 perf) ([`dfbacd6`](https://github.com/Vit129/kouen-terminal/commit/dfbacd628437415caf8d4104522e1fbcbaa628bd))
- Add P23 SSH Remote Host Manager plan ([#23](https://github.com/Vit129/kouen-terminal/pull/23)) ([`6058ffa`](https://github.com/Vit129/kouen-terminal/commit/6058ffa683a918e1a557f8fc012254dfd9a0a484))
- Add updateTrackingAreas guard to zombie crash knowledge ([`2429edd`](https://github.com/Vit129/kouen-terminal/commit/2429edd813d90838a30fc18a84dc7d9546f87148))
- Add tableView race guard to knowledge ([`d23caba`](https://github.com/Vit129/kouen-terminal/commit/d23caba14e0035573afe1ee0f8b80d9ec936ab44))
- Update zombie-crash knowledge with final timeline + script fix + 500ms ([`cb732af`](https://github.com/Vit129/kouen-terminal/commit/cb732af70b7884bbd25ad1181e237e6c9a2a20c4))
- Add Phase 0 (concurrency safety) to P8 macOS 27 plan — lessons from crash saga ([`4da5075`](https://github.com/Vit129/kouen-terminal/commit/4da5075d2e96ee6dd21ab16a9b8ead5c1bc7a03b))
- Update knowledge, changelog, graphify for crash fix session ([`059ce22`](https://github.com/Vit129/kouen-terminal/commit/059ce221c01d49ba159469e986ce14633ec6aea2))

### Fixed
- Zombie surface view crashes (CASE-037) + centralize configs ([`1b17b99`](https://github.com/Vit129/kouen-terminal/commit/1b17b99db9be39d37a32fff0c072017f3079d2f5))
- Zombie crash (CASE-037), perf: renderer micro-batch + scrollback ([`11062e4`](https://github.com/Vit129/kouen-terminal/commit/11062e45c771b7f49052e6d50aa38c4e7c8ea761))
- Zombie mouseMoved crash — remove NSTrackingArea on detach ([`e825ccf`](https://github.com/Vit129/kouen-terminal/commit/e825ccf58540f4fa31093f9a00b79daea856a981))
- Terminal content area unreadable at low opacity on bright backgrounds ([`1ee927e`](https://github.com/Vit129/kouen-terminal/commit/1ee927eafa2bf9cde9b8d33ad7ed1732d78ed9e1))
- Full-cycle builds before bumping version + rollback on failure ([`25998b2`](https://github.com/Vit129/kouen-terminal/commit/25998b25c88fb47ec8a034afca9bd5eb8947ed67))
- Remove discardCursorRects from deinit (Swift 6 actor warning) + regenerate release notes ([`6c55025`](https://github.com/Vit129/kouen-terminal/commit/6c5502553bbf8809251e4a6284817495435617e2))
- Restore discardCursorRects in deinit to prevent zombie crash ([`cbfb525`](https://github.com/Vit129/kouen-terminal/commit/cbfb5257b2ebd263ea2e552c056c34f985aefaf0))
- Eliminate macOS 26.5 zombie crashes — remove nonisolated layout, extend retire() to 100ms, fix Optional.map executor check ([`9102192`](https://github.com/Vit129/kouen-terminal/commit/9102192fc7388fd59759c0eab8667133f0c51351))
- Guard updateTrackingAreas against re-adding when view has no window ([`53d2e6b`](https://github.com/Vit129/kouen-terminal/commit/53d2e6b20e9eb048455e456f62d91b2366a2ca5f))
- Image preview blink — reuse QLPreviewView instead of recreating ([`adcafe3`](https://github.com/Vit129/kouen-terminal/commit/adcafe3171ac947cc7d32922e79dd500930252b9))
- Guard ALL updateTrackingAreas against windowless re-add (18 sites) ([`df619b8`](https://github.com/Vit129/kouen-terminal/commit/df619b884968f06043348558080ee1c823383efd))
- ⌘\ toggle sidebar works on first launch before initial layout ([`8a14207`](https://github.com/Vit129/kouen-terminal/commit/8a142076b060d53f6801d15d196dc25576ea9a92))
- Guard sidebar tableView delegate against stale row index ([`f1452f5`](https://github.com/Vit129/kouen-terminal/commit/f1452f59575f9584bd0f4c7a1f9fbdc6296fdfa0))
- Resign first responder before pane rebuild to prevent zombie keyDown ([`1752d26`](https://github.com/Vit129/kouen-terminal/commit/1752d2685a9c17a4a743d56639982dded437e21b))
- Increase retire/retiredContainer delay to 500ms ([`b3e3dac`](https://github.com/Vit129/kouen-terminal/commit/b3e3dacf562e94106d94583e907a040e55d81c48))
- Kill app BEFORE build in prod/install scripts ([`5bffd70`](https://github.com/Vit129/kouen-terminal/commit/5bffd701fab6d3e6cf004d41bebabd876f03af0b))
- NSEvent local monitor swallows events targeting windowless responders ([`317184f`](https://github.com/Vit129/kouen-terminal/commit/317184f1b44a7e3c0d53cf84ff64c164d4a830b1))
- BrowserPaneView crash on dealloc — move unregister to viewWillMove ([`a7f35b1`](https://github.com/Vit129/kouen-terminal/commit/a7f35b1a9f3efe259f936ff33f44d698e3eb32d6))
- ⌘\ sidebar + BrowserPaneView cleanup ([`7f87401`](https://github.com/Vit129/kouen-terminal/commit/7f874014c5bac44b77c518fb5caab770f1e1c9ee))
- Remove mouseUp/mouseDragged forwarding that caused infinite recursion ([`8e3e8f0`](https://github.com/Vit129/kouen-terminal/commit/8e3e8f0b807a80838c191b25d7104a31bd6a3445))
- Browser pane reload on tab switch, stale CWD on new tab, blank WKWebView ([`59e56bf`](https://github.com/Vit129/kouen-terminal/commit/59e56bffdc7565b910248e3334b3027e4b5c1c3c))
- Restore 3.3.0 version after botched non-TTY full-cycle run ([`77c2174`](https://github.com/Vit129/kouen-terminal/commit/77c2174edf351abf1697e503f6a4d1d95062e318))

## [3.2.1] - 2026-06-16

### Added
- Agent-memory v2 — CONTEXT.md + MEMORY.md, UPPERCASE files ([`aa19b80`](https://github.com/Vit129/kouen-terminal/commit/aa19b806844627c4720ad0f97297d47ec4f1484c))

## [3.2.0] - 2026-06-16

### Changed
- Cache agent icon in sidebar row, skip duplicate fileTreeView.updateRoot, fix file-preview flash (presentsWithTransaction on open/close) ([`e8573b8`](https://github.com/Vit129/kouen-terminal/commit/e8573b8d22a44c6e2c94930f3881e99166b48ba6))
- Skip sidebar rebuildSidebarRows+configure when sessions unchanged on metadata refresh ([`d2dfc67`](https://github.com/Vit129/kouen-terminal/commit/d2dfc678de4a6e9558780eac57b3316116c45937))
- Adaptive SurfaceShellTracker interval (0.5s→2s when idle); skip tabBar.refreshMetadata when tabs unchanged ([`aea6181`](https://github.com/Vit129/kouen-terminal/commit/aea618139b384bef40c29c7fd2f2aba6bfc6a5c6))
- IsStableEqual for Tab/SessionGroup — ignore volatile fields (currentCommand, lastMCPControlAt) in sidebar/tabbar skip checks ([`e5b3841`](https://github.com/Vit129/kouen-terminal/commit/e5b3841b92a51e87d84a116d5d6ef869a95a16ed))

### Documentation
- Update playbook (CASE-032/033), knowledge tab-bar effectiveAgentKind, memory v3.1.5 ([`a950389`](https://github.com/Vit129/kouen-terminal/commit/a9503899b37f70714b91df9be9bc191bc1e9e081))
- Archive CHANGELOG v1-v2 + Task_Ledger tasks 1-50 to reduce context size ([`393e90b`](https://github.com/Vit129/kouen-terminal/commit/393e90b7c1152324b9425607c4da646410a397c5))

### Fixed
- TerminalTabBarView layout() nonisolated crash (CASE-034); perf: skip browser-pane merge + surfaceIndex rebuild when no structure change ([`bbf6efe`](https://github.com/Vit129/kouen-terminal/commit/bbf6efe77e396b3057736cb73f0081a2e0f6947f))
- Nonisolated + MainActor.assumeIsolated on all override func layout()/viewDidMoveToWindow() in HarnessApp — prevent Swift 6 executor crash ([`ff350f9`](https://github.com/Vit129/kouen-terminal/commit/ff350f98d3f774c6716fc3e761df8097385e5c55))

## [3.1.3] - 2026-06-16

### Added
- Show native shortcuts on every new surface; add shortcut section to welcome banner ([`7d2ecd2`](https://github.com/Vit129/kouen-terminal/commit/7d2ecd2e09e28a1060dfd1c0333c9f6f8eff1a3f))

### Fixed
- Add deinit to HarnessTerminalSurfaceView; fix CASE-030 sidebar + CASE-031 CADisplayLink ([`e301d8b`](https://github.com/Vit129/kouen-terminal/commit/e301d8be21a448c1dd2990a411b1221665fdacfd))

## [3.1.2] - 2026-06-16

### Added
- Centralize logic — PathTokenParser (shared path:line:col parser) + AgentBridge (send context to agent pane) ([`d36a1bc`](https://github.com/Vit129/kouen-terminal/commit/d36a1bcde262e1b90954f1e836c2e1ab1422aa87))
- :agent ex command + harness agent send CLI ([`b3eb87d`](https://github.com/Vit129/kouen-terminal/commit/b3eb87d79ffa106c6f680e6dac26cd97644bdfc0))
- :agent target by kind (--claude/--codex/--kiro) + prompt when multiple agents ([`54df71b`](https://github.com/Vit129/kouen-terminal/commit/54df71b1df7e42b0b3441f73f98d6a75e5f26f94))
- :agent auto-spawn + file autocomplete ([`9a7eec4`](https://github.com/Vit129/kouen-terminal/commit/9a7eec4531f52ca3ef5aab93b84e6e2a2eb27a81))
- Add workbench commands (:view, :agent, :cd) + Robot suite ([`3d3d264`](https://github.com/Vit129/kouen-terminal/commit/3d3d264f88b9b88eee5fa47f715daab606d0e181))
- AgentCatalog centralized config (claude/codex/kiro/gemini models+effort) ([`3fcf15c`](https://github.com/Vit129/kouen-terminal/commit/3fcf15ccdfcd47851498e003242b9f677730fb27))

### Changed
- Eliminate unconditional 5-s sync + snapshot fanout overhead ([`9792410`](https://github.com/Vit129/kouen-terminal/commit/97924108891fc67415167833afb346971e00d5f7))

### Documentation
- P21 plan — ACP re-enable + agent/model/effort selection (terminal-first) ([`fa8cca0`](https://github.com/Vit129/kouen-terminal/commit/fa8cca01eec2ba2508605cddabe3cd59d500a825))
- Update P20/P21 status — AgentBridge/AgentCatalog/agent commands done, ACP re-enable deferred ([`1f0e9d0`](https://github.com/Vit129/kouen-terminal/commit/1f0e9d0ad4b58063ac04c4c7f794c27d6dd8de92))
- Merge harness chat branding into P21 PBI-ACP-005 ([`549d3e5`](https://github.com/Vit129/kouen-terminal/commit/549d3e5c6920480edc4544ca0aaca813e5c94058))
- Integrate Hermes concepts — multi-provider + brain + orchestration + backends ([`4cfb5dd`](https://github.com/Vit129/kouen-terminal/commit/4cfb5ddc3f4baadb4e9d77942a3daf6214dadeb3))
- Update agent-memory, knowledge, graphify for long-session perf work ([`9c93fa3`](https://github.com/Vit129/kouen-terminal/commit/9c93fa3fbd8528c808aaf31b9c456ac471f17403))

### Fixed
- Dot after title, branch always visible, cancel drag on reload ([`c754939`](https://github.com/Vit129/kouen-terminal/commit/c754939c4c0327b99b8a7f9f0ca7175880ee5c23))
- Dot after title, branch always visible, cancel drag on reload ([`fbff175`](https://github.com/Vit129/kouen-terminal/commit/fbff1758fb5ad0f86db9a4e13ebb5e0123f70cce))

## [3.1.0] - 2026-06-15

### Added
- Add status indicator to session card rows (dot + label on right) ([`3f5b283`](https://github.com/Vit129/kouen-terminal/commit/3f5b283efd8ef8b839b721b9c74413ea664d5f07))
- Central board status dot on top bar session pills + sidebar cards ([`c9303f4`](https://github.com/Vit129/kouen-terminal/commit/c9303f4d3c5e21ba54f861ba688ef7cb9b40e8c7))
- Bell badge + dropdown include board error/needs-attention sessions ([`4d669da`](https://github.com/Vit129/kouen-terminal/commit/4d669dac21db1988f4d6837f0becf156c88bc8fe))
- Change notification shortcut ⌘⇧U → ⌘⇧I (Inbox) ([`e8c497b`](https://github.com/Vit129/kouen-terminal/commit/e8c497bc95efb91866472554cec7889980c08c4f))
- ⌘F opens grep/find-in-files palette (Cmd+Shift+F parity) ([`d7edae8`](https://github.com/Vit129/kouen-terminal/commit/d7edae8435487a905d49adafbed6972bf529f717))
- Add ⌘P as alias for Command Palette (alongside ⌘K) ([`1957c0d`](https://github.com/Vit129/kouen-terminal/commit/1957c0d92240d75ed6c97e8d4854b1ef4856bc84))
- Replace ⌘K with ⌘P for Command Palette (VS Code/Cursor/Zed parity) ([`34c9d2a`](https://github.com/Vit129/kouen-terminal/commit/34c9d2ab7dbd9e691d8e43c6a60e020da0faa86d))

### Changed
- Centralize board status logic ([`db3c03c`](https://github.com/Vit129/kouen-terminal/commit/db3c03c078800f3323d747b2315397664a3d577f))

### Documentation
- Add IDE-like Terminal Workbench section to USAGE, COMMANDS, KEYBINDINGS ([`0689cfb`](https://github.com/Vit129/kouen-terminal/commit/0689cfb4a0ad0d15dd0e9ee54ca99861cc6ca176))
- Update README doc index with workbench command references ([`17adcd5`](https://github.com/Vit129/kouen-terminal/commit/17adcd5c10f6ef424637b3492d27a92ddb46462e))
- Update P11/P15/P16 plan status to reflect actual implementation state ([`9ce125b`](https://github.com/Vit129/kouen-terminal/commit/9ce125b84d50db1cbf0c4233a521533964e81456))
- Update KEYBINDINGS.md and fix remaining ⌘K/⌘⇧T/⌘⇧⌥W references in docs ([`f54f028`](https://github.com/Vit129/kouen-terminal/commit/f54f02850a3d41bfb0bba691f25421e93195ee35))
- Consolidate docs — add Modes+Migration summary to USAGE.md, move MANUAL_TEST_PLAN to agent-memory, update README index ([`971500e`](https://github.com/Vit129/kouen-terminal/commit/971500e5b0cba2cb070739cdbc2e533f28ba0666))

### Fixed
- Sidebar group header chevron size and click area ([`352a168`](https://github.com/Vit129/kouen-terminal/commit/352a1689acacec3efeb280bcb2f2fab24a5cbb91))
- Remove broken ⌘⇧T Reopen Closed Tab; ⌘F opens Command Palette (fuzzy find) instead of browser find bar ([`e95b471`](https://github.com/Vit129/kouen-terminal/commit/e95b471f7e82f02b09ecb3fe19acbf4ac2253252))
- Close Pane ⌘⇧⌥W → ⌘⌥W (iTerm2 parity, easier to press) ([`81546f4`](https://github.com/Vit129/kouen-terminal/commit/81546f4b8c50fa5172daa7eeb9b44d715b0e9203))
- Tab bar × button now shows confirmation dialog (same as ⌘W) ([`f362dbd`](https://github.com/Vit129/kouen-terminal/commit/f362dbd1918d96f91e3dfeabdf73b5725b2c592b))

## [3.0.0] - 2026-06-15

### Added
- Simplify version-bump flow into install/prod/full-cycle ([`24cadb2`](https://github.com/Vit129/kouen-terminal/commit/24cadb2a8eb6739118db422f27fce1e5c42077fd))
- Add keyboard navigation to notification dropdown ([`c956319`](https://github.com/Vit129/kouen-terminal/commit/c95631981e6d461fe7331bf7c95c8bbc19fe78dc))
- Implement spotlight search safety & fix git status update/blinking issues ([`3c043e9`](https://github.com/Vit129/kouen-terminal/commit/3c043e9243fd320fa107f893afe5bd68b610b632))
- Add interactive arrow-key start menu & auto-prepend release notes to changelog ([`b4d8473`](https://github.com/Vit129/kouen-terminal/commit/b4d84739c9092ef4bab1b147d1452a0d4470d9a2))
- Show next semantic versions in start menu choices ([`2509dc7`](https://github.com/Vit129/kouen-terminal/commit/2509dc7b67faf37b25ef401934750b3c94d608e4))
- Restore split-down (top/bottom) parity (P13) ([#10](https://github.com/Vit129/kouen-terminal/pull/10)) ([`e0a35f7`](https://github.com/Vit129/kouen-terminal/commit/e0a35f792407203470850d862ac71dee638406bb))
- Agent orchestration via MCP (P12 PBI-ORCH-001..005) ([#11](https://github.com/Vit129/kouen-terminal/pull/11)) ([`d8a5e90`](https://github.com/Vit129/kouen-terminal/commit/d8a5e901ab9c204dda4c4afbf745a237b3e08de7))
- Add terminal-first LSP and file view commands ([`9c54073`](https://github.com/Vit129/kouen-terminal/commit/9c540730245818d380a81bef2690cc02ebf3cdce))
- Complete vi lsp navigation ([`f251659`](https://github.com/Vit129/kouen-terminal/commit/f251659b24d29bd8c084e1b301442ccd17c20398))
- Add JavaScriptCore config runtime (P11 PBI-SCRIPT-001..003) ([`24f3968`](https://github.com/Vit129/kouen-terminal/commit/24f396881e9d29e271505e38e1b894429a2b9ec8))
- P16 Agent/Session Board (PBI-BOARD-001/002/003/005) ([`fa9d893`](https://github.com/Vit129/kouen-terminal/commit/fa9d893b387de31afc03c83b034e3f044489e1e3))
- Add harness.events bridge (P15 step 3) ([`3ac8afb`](https://github.com/Vit129/kouen-terminal/commit/3ac8afb9d0e79c1bd5f982015c8adf5d35827854))
- Merge harness.events bridge (step 3) — unblocks P11/P12/P16 ([`4843a69`](https://github.com/Vit129/kouen-terminal/commit/4843a69cae1481a9a615ea316c214214c4630192))
- PBI-ORCH-005 — MCP-controlled indicator on tab bar ([`0f17d02`](https://github.com/Vit129/kouen-terminal/commit/0f17d0215dbde933ec6ab56a5f4e31d75751be82))
- Complete PBI-SCRIPT-004/005 + harness.events bridge + test fixes ([`30766ef`](https://github.com/Vit129/kouen-terminal/commit/30766ef550edd14217b579dd270114506e85f4ad))
- PBI-BOARD-004 live updates + PBI-BOARD-006 dismiss ([`1cdd7d3`](https://github.com/Vit129/kouen-terminal/commit/1cdd7d3bf522f8fb99fbf29a6f4d9df84bedea88))
- Scripting 004/005 implementation from worktree ([`f67de07`](https://github.com/Vit129/kouen-terminal/commit/f67de073793b9ad539c74b7cbb3c6d06e78b950a))
- PBI-BROWSER-001..005 — embedded browser pane + MCP tools ([`3b39154`](https://github.com/Vit129/kouen-terminal/commit/3b391544e6d2d0be326c3107555f903d090f0cb1))
- WB-001 WorkbenchCommand facade + parser ([`33b7960`](https://github.com/Vit129/kouen-terminal/commit/33b7960b7594db0c69716c63a1adce2e7abb21fd))
- WB-002/003/004/006 ex commands + task detector ([`3bb683f`](https://github.com/Vit129/kouen-terminal/commit/3bb683f3f61c0f3bd917a11ec3d596af0497778e))
- WB-007 harness.profiles.use('ide-migrant-terminal') ([`f3a8f9d`](https://github.com/Vit129/kouen-terminal/commit/f3a8f9d1cbf5453aabfd9bb71015c2035af498c3))
- Terminal Workbench — all PBI-WB-001..007 done ([`44577d6`](https://github.com/Vit129/kouen-terminal/commit/44577d6870dccb3f1bb1071c278ae8a074be40bb))
- Add workbench CLI commands for IDE migrants ([`49b1ede`](https://github.com/Vit129/kouen-terminal/commit/49b1ede56e18233649e9e36474d30a378425a001))
- Session expand shows tab list with Board status + full CWD ([`3563357`](https://github.com/Vit129/kouen-terminal/commit/356335781b412a726a566892b8e77c635f8b39ba))
- Add Cmd+B shortcut for Browser Pane + open localhost links in-app ([`9844140`](https://github.com/Vit129/kouen-terminal/commit/9844140e2df73b5bb76eeb46c89b6f5c9a6e2572))
- Open LAN dev-server links (private IPv4/IPv6) in Browser Pane ([`4bcf3e8`](https://github.com/Vit129/kouen-terminal/commit/4bcf3e85c753a2818612be904c86a3eb94f9df02))

### Changed
- Restructure dev-loop make targets and start.sh menu ([`9746c5e`](https://github.com/Vit129/kouen-terminal/commit/9746c5e09c2ece9b7061c390aa681b0e709d5fdb))
- Consolidate menu shortcuts, add git panel toggle, fix preview socket path ([`825302b`](https://github.com/Vit129/kouen-terminal/commit/825302b760a62302aac061900d61958914cb02b8))
- Remove dead Tab-switch shortcuts, repoint ⌘[/⌘] to session navigation ([`22b6d65`](https://github.com/Vit129/kouen-terminal/commit/22b6d65df672acd0cf1a4b683a785ae06757f8f1))
- Worktree-aware full-cycle, commit-push-merge helper ([`908179e`](https://github.com/Vit129/kouen-terminal/commit/908179ed41dd3cb89da870f191cb3d529f18927e))
- Decompose SessionCoordinator → ThemeService + ActivePaneService ([`cb6a295`](https://github.com/Vit129/kouen-terminal/commit/cb6a2958bbc4c37bae78999d0b7c8bd7d094ef51))
- Complete PBI-REFACTOR-001 — SessionCoordinator 2050→397 LOC ✅ ([`e01aadb`](https://github.com/Vit129/kouen-terminal/commit/e01aadb144da7ba2649d7b3757fc0c76ae7b47cb))
- Organize UI/ into feature subfolders, shelve ACP behind HARNESS_ACP flag ([`0156e52`](https://github.com/Vit129/kouen-terminal/commit/0156e52d4139a0290a457a1c2848167c50b23ee2))
- Decompose ViNormalMode.swift into 5 focused files (PBI-REFACTOR-003) ([`c9fa0a5`](https://github.com/Vit129/kouen-terminal/commit/c9fa0a53b19a66fcfe060419c0eb9b930b2f12e5))

### Documentation
- Update memory to v2.5.2 + add HOW_TO_USE.md ([`06043c2`](https://github.com/Vit129/kouen-terminal/commit/06043c23999a5291152ab79737d143999faba2ad))
- Update agent-memory and graphify after CASE-028 keybinding cleanup ([`e72a7f4`](https://github.com/Vit129/kouen-terminal/commit/e72a7f459a153562db04ff84e5f575e7d2bf06a1))
- Add v2.5.3 entry for CASE-028 keybinding cleanup ([`5101183`](https://github.com/Vit129/kouen-terminal/commit/5101183423817d5f237b733a3a19a8737b6b1f89))
- Remove empty Unreleased heading so 2.5.3 is the top entry ([`bdf48c9`](https://github.com/Vit129/kouen-terminal/commit/bdf48c975940a8e7e0c1714b7b9349f09743967a))
- Add P11-P13 strategic backlog plans from terminal comparison ([`39e83e0`](https://github.com/Vit129/kouen-terminal/commit/39e83e0020120b49d6a1cd8bb704b54ad3914517))
- Add P15 integration roadmap and P16 agent/session board plans ([`3ae0b37`](https://github.com/Vit129/kouen-terminal/commit/3ae0b3704f8b7b1cfa1604756903faa5e9085a4d))
- Document P16 Agent/Session Board, update README and graph ([`687179f`](https://github.com/Vit129/kouen-terminal/commit/687179f09e9a7c24d5194031293ba9c871c9cd27))
- Refresh plan statuses after PR #10/#13-#19 merges ([`9eb5b47`](https://github.com/Vit129/kouen-terminal/commit/9eb5b47920ac4362c2ca2812145fd897ccd1e7c2))
- Refine terminal-first roadmap ([`84c6651`](https://github.com/Vit129/kouen-terminal/commit/84c6651252cadcbabdb1ab6de14728ad399466fe))
- Mark P17 PBI-002/003/005 done in structural-refactor plan ([`696fbaf`](https://github.com/Vit129/kouen-terminal/commit/696fbafee5fb7b2a1ada3ed0b05e186050e6f331))
- Mark P17 DONE, defer PBI-004 (HarnessCore split) ([`ed1c9cf`](https://github.com/Vit129/kouen-terminal/commit/ed1c9cf98776f0191a6f444b52cdf01d36d6b517))
- Update graphify, agent-memory, knowledge base ([`68b05b3`](https://github.com/Vit129/kouen-terminal/commit/68b05b3b303e16f4ad31a665bf00b4328b4a070b))
- Add terminal workbench migration plan ([`01ce2d5`](https://github.com/Vit129/kouen-terminal/commit/01ce2d57761f9228e8508e204f997a2971760d50))
- Mark P12 DONE, add task 67 to memory ([`2a6fb8b`](https://github.com/Vit129/kouen-terminal/commit/2a6fb8bda3bbd76601b3ccc540ba7f071184adb0))
- Mark P11 PBI-SCRIPT-004/005 done in memory ([`cd8a9e8`](https://github.com/Vit129/kouen-terminal/commit/cd8a9e84231f1b5cf80d726bd43c64862fbdf487))
- Mark step 4 (P11 PBI-SCRIPT-004/005) done in integration roadmap ([`71b09bd`](https://github.com/Vit129/kouen-terminal/commit/71b09bd8843122f87e8645097798107d134793de))
- Update browser pane plan with cmux research + agent control design ([`6f69f46`](https://github.com/Vit129/kouen-terminal/commit/6f69f4652d9c37f739ad5bedce9efcf61f6a1236))
- Finalize plan + agent prompt for PBI-BROWSER-001/002 ([`3036c6d`](https://github.com/Vit129/kouen-terminal/commit/3036c6d4b4b0de31daa7b8ba90857ea16ea58a54))
- Add single agent prompt for all PBI-BROWSER-001..005 ([`24becbc`](https://github.com/Vit129/kouen-terminal/commit/24becbcaf38bcf1f081f8c8385a729d1f2e44a61))
- Davin/Windsurf kanban+CMUX proposal for sessions panel/top bar ([`dda3201`](https://github.com/Vit129/kouen-terminal/commit/dda3201f21ea8f9892c5329c3a5623693d89f3f7))

### Fixed
- Kill stale Harness/daemon before relaunching via run.sh ([`e69d31b`](https://github.com/Vit129/kouen-terminal/commit/e69d31b57136f39e531ac3335c7d0c418c976afd))
- Scope kill_stale to prod release home, guard prepare-release against Unreleased, add version banner + clean-state ([`fa317ea`](https://github.com/Vit129/kouen-terminal/commit/fa317eacd0629d5ddffcea0d1a1cc686ea85be75))
- Swift build -c release builds all products, not just the last --product flag ([`17f79e0`](https://github.com/Vit129/kouen-terminal/commit/17f79e0b102ec4afd0c881246641db82ccb01f97))
- Keep text selection stable across scroll ([`578178a`](https://github.com/Vit129/kouen-terminal/commit/578178a2279d0d51019fce229394aef794e7bdfb))
- Fix diff deadlock, add notification rings, preview build badge ([`0845ea5`](https://github.com/Vit129/kouen-terminal/commit/0845ea5426e6cc0e929d954f83049cc50423473d))
- Make ⌘\ a pure sidebar toggle, decoupled from file-editor split ([`1fcc4c3`](https://github.com/Vit129/kouen-terminal/commit/1fcc4c3b7a112a2f2f92eb8f257fce84e700dc67))
- Close button bug, idle throttle, session short ID, P4 tests, P17/P18 plans ([`06f0d56`](https://github.com/Vit129/kouen-terminal/commit/06f0d56b5b19aad2381b061ce818d3db830955be))
- Guard NSApp nil in updateDockBadge, fix flaky board count assertion ([`1a177c7`](https://github.com/Vit129/kouen-terminal/commit/1a177c71b3537dda8cc261f2c75620ed818af213))
- Wire WorkbenchMRU.add + :copy-path callbacks in FileEditorView ([`4ffccaf`](https://github.com/Vit129/kouen-terminal/commit/4ffccaf58a87172f25506fdf58b702afbe328b21))
- Browser pane persists across daemon syncs ([`0ba5759`](https://github.com/Vit129/kouen-terminal/commit/0ba575961acf250dbc6d16f841571493d447e550))
- Stop browser pane blink loop ([`a86ce70`](https://github.com/Vit129/kouen-terminal/commit/a86ce70f8d6554abde67433a0ea77f140f935854))
- Add close (×) button to browser toolbar + closeBrowserPane ([`440317e`](https://github.com/Vit129/kouen-terminal/commit/440317e696449ddfb70f2ad6d3ee2fd2465d9e96))
- Wire closePaneButton → closeBrowserPane correctly ([`3f1ac4e`](https://github.com/Vit129/kouen-terminal/commit/3f1ac4e13adc129f19581dbc17ccb0c81882d20d))
- Expand arrow stays visible using insertRows/removeRows ([`d555e24`](https://github.com/Vit129/kouen-terminal/commit/d555e2426eb781103b1441a2c8899c1630c56d81))
- Browser close button + prompt file for Agy ([`97d6154`](https://github.com/Vit129/kouen-terminal/commit/97d6154b7d02a2927b41586b0f9c2d71103170e1))
- Browser toolbar close/refresh fix, branch-aware tabs ([`f0bdce0`](https://github.com/Vit129/kouen-terminal/commit/f0bdce0efd5c91f10d795c62b2cc712825ba0b73))
- Hide collapsed error banner to stop it intercepting toolbar clicks; add hit-test/action tests for close+refresh buttons ([`1db38e5`](https://github.com/Vit129/kouen-terminal/commit/1db38e59afd00723a56eb9dbf6f5cd7b500e2134))
- Keep group-header expand arrow visible after collapse/re-expand ([`a6f2ed7`](https://github.com/Vit129/kouen-terminal/commit/a6f2ed7a72694c41efd4562fe6a639422c645665))
- Stop applyLocalSnapshot from re-injecting closed browser panes ([`b76fb0d`](https://github.com/Vit129/kouen-terminal/commit/b76fb0dd006b9cf29a8a19b1f829f26bf0fce940))
- Apply initial sidebar visibility after first layout pass ([`21b7cc4`](https://github.com/Vit129/kouen-terminal/commit/21b7cc40e389fe8b7c349a9ad84d70e6a2b71ac5))

## [2.5.2] - 2026-06-12

### Fixed
- Enforce 15% minimum tint on translucent window background ([`c3dfc5c`](https://github.com/Vit129/kouen-terminal/commit/c3dfc5ca790d5311628ecbca932d5aa8dc8c9c1c))
- Make pasted image handoff readable ([`abc15d7`](https://github.com/Vit129/kouen-terminal/commit/abc15d7697b07e9aaa0726236427c14d1c0ab56b))
- Select sessions with number shortcuts ([`ff32a69`](https://github.com/Vit129/kouen-terminal/commit/ff32a69670a4a60bc151576c46f778ac0d8ab0e3))

## [2.5.1] - 2026-06-12

### Added
- Close last tmux gaps — word-separators in copy-mode w/b/e, CLI list-* -F ([`99d4cc2`](https://github.com/Vit129/kouen-terminal/commit/99d4cc25a3b6da4a1bab576d2760d190447f9112))
- Per-theme-mode background opacity for auto light/dark ([`a50846d`](https://github.com/Vit129/kouen-terminal/commit/a50846d336bf37cb78a699cd96921f401b37d2d0))
- Per-theme-mode background opacity for auto light/dark ([`1307b48`](https://github.com/Vit129/kouen-terminal/commit/1307b4811c6d2b2347bda0b6e87e78226a60c861))

### Documentation
- Rewrite README — cleaner structure, no agent-memory/graphify internals ([`4ce1b70`](https://github.com/Vit129/kouen-terminal/commit/4ce1b70641c5d74951dc657df922e25a42cf3b0e))
- Trim README to 66 lines (A+B style) ([`db974b2`](https://github.com/Vit129/kouen-terminal/commit/db974b2e5405eafd5a2faf4a2693e74000bdd9fe))
- Add fork attribution to README ([`332e1cc`](https://github.com/Vit129/kouen-terminal/commit/332e1cc1928abd2167af895a9e50eac0e5d451f7))
- Update CHANGELOG, memory, and knowledge for session fixes and opacity improvements ([`03b447b`](https://github.com/Vit129/kouen-terminal/commit/03b447bac7cf4ab1e91c8b0fc395ca5cb76284d0))
- Add Apple Liquid Glass / legibility context to knowledge base ([`763a5c3`](https://github.com/Vit129/kouen-terminal/commit/763a5c38fec2cf64928455a21a467d51679cd8f7))

### Fixed
- Use theme-tinted window background when translucent ([`76018e5`](https://github.com/Vit129/kouen-terminal/commit/76018e5b35d2acaf35da3daa5cf572797ac3db91))

## [2.5.0] - 2026-06-12

### Added
- Support wrap-search option and zoxide frecency in command palette ([`72bbd67`](https://github.com/Vit129/kouen-terminal/commit/72bbd67d7ffec2f29c3bf34d5014f4e4bbaa510f))
- Terminal power-user features — vi mode, tmux parity, LSP, zoxide ([`55c7bff`](https://github.com/Vit129/kouen-terminal/commit/55c7bffef33f9e61a4a3a98b63a65e41db4e8098))
- Keyboard file tree, vi jump-list/marks/search, tmux window-size/json ([`6cd143d`](https://github.com/Vit129/kouen-terminal/commit/6cd143d38ef94e54efcd103d3efb5e0bd3965b14))

### Changed
- Remove Toggle IDE Mode preset shortcut and menu items ([`76ebf70`](https://github.com/Vit129/kouen-terminal/commit/76ebf70a42e7b57bfa5f15e69ce69ee588da58cf))

### Documentation
- Clarify design philosophy to Terminal First, IDE Convenient and resolve features duplication ([`c2b3f02`](https://github.com/Vit129/kouen-terminal/commit/c2b3f02408724f97d89bc211cb19374462ddf00f))
- V2.5.0 — update CHANGELOG, README, memory, TMUX_PARITY, graphify ([`08589c4`](https://github.com/Vit129/kouen-terminal/commit/08589c49a0e2160d23d0d39729d1f286861257ed))

### Fixed
- Reset Focus Mode state on manual panel toggles to prevent out-of-sync layouts ([`c3c998b`](https://github.com/Vit129/kouen-terminal/commit/c3c998b11bdbae0ce72f3e48beb2f92a5ba69f3c))

## [2.4.0] - 2026-06-12

### Added
- Lazy scrollback reflow, task board sidebar, focus mode (⌘P) ([`4c2fa16`](https://github.com/Vit129/kouen-terminal/commit/4c2fa168a65cf39d1db113d767477ff75b95fa53))
- Add Switch Project section and worktree-to-tab integration ([`40ecd09`](https://github.com/Vit129/kouen-terminal/commit/40ecd093b355788bb0409ce645f0cc022aacd775))
- Add fuzzy file quick-open to command palette ([`7106b74`](https://github.com/Vit129/kouen-terminal/commit/7106b74878bbe0435ac805fea424726aaf66657f))
- Add Ctrl+R interactive command-history search overlay ([`4e4c2d4`](https://github.com/Vit129/kouen-terminal/commit/4e4c2d45708412c9591c6087a1f58f68323f18f9))
- Layout presets (⌘⌥1-5) and workspace symbol index in command palette ([`1e998ae`](https://github.com/Vit129/kouen-terminal/commit/1e998ae794fd969c4330abd9b89300d0522c5242))

### Changed
- Remove task board panel and clean up related code ([`ffca765`](https://github.com/Vit129/kouen-terminal/commit/ffca76592128811427fea4736176c3fd556127f3))
- Enumerate files off main thread for fuzzy file quick-open ([`2a4d3fa`](https://github.com/Vit129/kouen-terminal/commit/2a4d3fa2108724c84aedf0b443b336c1e3c8b4f2))

### Documentation
- Add scrollback lazy reflow prompt for P10 agent execution ([`5a45ac9`](https://github.com/Vit129/kouen-terminal/commit/5a45ac9352aa4c3553ca45cff33e6fbaff2d626a))
- Update memory, playbook, P10 plan; refresh graphify for v2.3.0 post-release ([`3dde732`](https://github.com/Vit129/kouen-terminal/commit/3dde732fc713dca42cadb9f79bd9b808b64b4929))
- Add fzf-searchable Linux + Vi cheat sheet ([`5970d79`](https://github.com/Vit129/kouen-terminal/commit/5970d795f4e15cb6e961d8badc3cd1f32fdd7583))
- Update README, KEYBINDINGS, AGENT-HANDBOOK, HARNESS_TMUX_CAPABILITIES ([`4c295cc`](https://github.com/Vit129/kouen-terminal/commit/4c295cc38241198d4cf2d11751e523c1f9c0cfae))

### Fixed
- Always stop+start display link in viewDidMoveToWindow (CASE-026) ([`50cff4a`](https://github.com/Vit129/kouen-terminal/commit/50cff4a1488eafd285c464dc250b8fad01a14709))
- CASE-026 black terminal on new session (display link race) ([`4153d76`](https://github.com/Vit129/kouen-terminal/commit/4153d76ba4de9a68ee43348f2883cfa2d1b29e15))
- Close-pane button closes the clicked pane, not the active one ([`dd3754d`](https://github.com/Vit129/kouen-terminal/commit/dd3754de0f94da27a71345af5965f04b7c57236e))
- Force child layout after applying split divider positions ([`1ca9bae`](https://github.com/Vit129/kouen-terminal/commit/1ca9bae0c6ae14e7a252b93d8d293ff3e4f733ab))
- Skip redundant schedule if revision already pending ([`14a12b7`](https://github.com/Vit129/kouen-terminal/commit/14a12b7f59a7ae315a3f6980210b7c9f9e3dee2a))

## [2.3.0] - 2026-06-11

### Added
- Diff syntax coloring, changes click-to-preview, history context menu ([`ea1ec5a`](https://github.com/Vit129/kouen-terminal/commit/ea1ec5a27966ca362138461b0ec19b7b310a45e7))

### Changed
- Extract pure logic from HarnessTerminalSurfaceView ([`4f2c1b3`](https://github.com/Vit129/kouen-terminal/commit/4f2c1b305cea1439beed7809f9fd9d2f27d66d53))
- Extract HarnessCLI handlers and SurfaceRegistry helpers ([`8009775`](https://github.com/Vit129/kouen-terminal/commit/8009775419fe8591e8dad2719e1bb3986f8a9848))

### Documentation
- Record P9 extraction task and refresh graphify graph ([`d2e4095`](https://github.com/Vit129/kouen-terminal/commit/d2e4095fdb932b1814c9eb85764f2d91509ca96b))
- Update for git panel fixes + P10 prompts, refresh graphify ([`8e56978`](https://github.com/Vit129/kouen-terminal/commit/8e56978fc276d60b8a112d610ae2bad80bf4c5b4))

## [2.2.4] - 2026-06-11

### Added
- Add Scripts/install-app.sh with macOS cache clearing ([`857ba90`](https://github.com/Vit129/kouen-terminal/commit/857ba90b36c3f63e1c2fd2dad8297020b27054c9))
- Redesign AgentInboxPanelView rows to match notch HUD format ([`39acb64`](https://github.com/Vit129/kouen-terminal/commit/39acb649c3db6c910149c3673314d300b9fa9cf9))
- Add toggles to show hidden files and folders ([`f46b6ca`](https://github.com/Vit129/kouen-terminal/commit/f46b6ca877a09d2f3354e40877ad666c2498fb4c))
- Expand start.sh menu with commit/push and release-prep options ([`80fdfb6`](https://github.com/Vit129/kouen-terminal/commit/80fdfb6eb99cb5b4568dd711fde3783f2e7d536d))
- Collapse sidebar by default on fresh installs ([`ae6e2ac`](https://github.com/Vit129/kouen-terminal/commit/ae6e2ac0c41146538af54655fe0cca79dc7222d1))
- Add Always collapse sidebar on launch option ([`36d2430`](https://github.com/Vit129/kouen-terminal/commit/36d2430bc1c850250c2fb935a54c0d14147ce8d0))
- Add Excel and CSV support via QuickLook ([`35d0a93`](https://github.com/Vit129/kouen-terminal/commit/35d0a933debc70c86d3bb1dc7fcf752ba221d32a))

### Changed
- Move app-only Notch and FileExplorer domains out of HarnessCore ([`9f675c8`](https://github.com/Vit129/kouen-terminal/commit/9f675c88bf75bc9fe082d6cb84a2bc112d2882c3))
- Split HarnessSidebarPanelViewController into focused files ([`49221fe`](https://github.com/Vit129/kouen-terminal/commit/49221fe42dd208543921ec791ea7e7de23941d6b))
- Split HarnessTerminalSurfaceView into focused extension files ([`d20453b`](https://github.com/Vit129/kouen-terminal/commit/d20453bc61b4c36d1c02227bcff78ca013131990))
- Split SettingsViewController into per-page extension files ([`adf06e7`](https://github.com/Vit129/kouen-terminal/commit/adf06e7b2ae633ef9edd582f435407ff713df001))

### Documentation
- Add CASE-016..021, FSEvents pattern, RL-007..010, git-panel knowledge update ([`910ad71`](https://github.com/Vit129/kouen-terminal/commit/910ad719b630de553ac0311b6e90a69e51127054))
- Record CASE-023/024 and refresh graphify graph ([`fb1b558`](https://github.com/Vit129/kouen-terminal/commit/fb1b558d83eafea2ad02b0cd7ad8d5639866c858))
- Record build/run command preferences ([`491f5ed`](https://github.com/Vit129/kouen-terminal/commit/491f5ed56bc988d1ae721420497090bf1c5c3b3c))

### Fixed
- Install-app.sh must build release to match package-app.sh release ([`89b2989`](https://github.com/Vit129/kouen-terminal/commit/89b2989cfb367f4f35dc05f612896b37d3611633))
- Refresh UI after create/delete/rename operations ([`3d3bc65`](https://github.com/Vit129/kouen-terminal/commit/3d3bc656d175f7efac11fdc1e51141722b92ee9a))
- Resolve file tree watcher, folder expand state, file preview selection, and selection highlight visibility ([`231ab7b`](https://github.com/Vit129/kouen-terminal/commit/231ab7b3949bda6b18cd384c1f211d494daa5c96))
- Replace DispatchSource watcher with recursive FSEvents stream ([`9191f8f`](https://github.com/Vit129/kouen-terminal/commit/9191f8f67864435aa6051e7f4bcf4c943e25552d))
- Update branch chip on HEAD change and add FSEvents watcher for working-tree changes ([`71b6371`](https://github.com/Vit129/kouen-terminal/commit/71b6371a85bfd12b20f6c04a7215c89b1e349136))
- Declare HarnessTerminalEngine dep, sync CLAUDE.md targets, ignore dated graphify dirs ([`7fd1076`](https://github.com/Vit129/kouen-terminal/commit/7fd1076172e26956b3dc046396c1c48ed8698b92))
- Serialize refresh() to prevent stale staged-state UI ([`d1227df`](https://github.com/Vit129/kouen-terminal/commit/d1227dfdef2b17b45677e39c7e5f2739dae784b9))
- Make File Preview opacity match Terminal exactly ([`e3f6bac`](https://github.com/Vit129/kouen-terminal/commit/e3f6bacc152f6b9b4fc0eb68c4f4950fa633f0ce))
- Reset transient modes at shell prompt ([`fa64dbd`](https://github.com/Vit129/kouen-terminal/commit/fa64dbd67d19974d591fe9b1acfb9e7f9c8d220d))
- Live-reload preview when the underlying file changes ([`3bf42af`](https://github.com/Vit129/kouen-terminal/commit/3bf42af07e39d94929ebaabfcc2e8f713368acba))
- Sync sidebarVisible when forcing collapse on launch ([`8bfb638`](https://github.com/Vit129/kouen-terminal/commit/8bfb6385b59ab957b967d5fa28435810b9b391a6))
- Don't clear synchronizedOutput on shell-prompt reset ([`532a96c`](https://github.com/Vit129/kouen-terminal/commit/532a96c944af4d5cd23d36861d61fb0951d575d7))

## [2.2.3] - 2026-06-09

### Added
- P7 sidebar button style + terminal tab bar background fixes ([`a1ba082`](https://github.com/Vit129/kouen-terminal/commit/a1ba0826d6af72176d4ff7afb93c362e5442979d))

### Documentation
- Add changelog entry for P7 header button style fix ([`6e72648`](https://github.com/Vit129/kouen-terminal/commit/6e726488f17f5f8cb5c307e06da20d9d3ea5b244))
- Consolidate P7 + tab bar fixes into 2.2.2 changelog ([`7beab57`](https://github.com/Vit129/kouen-terminal/commit/7beab57cffebf4ca435f43f1289ae484567f16b1))

### Fixed
- Use SoftIconButton for group header + and ... buttons ([`258e779`](https://github.com/Vit129/kouen-terminal/commit/258e7795d3798c4a91b065d62495edb01b00fca7))
- Terminal tab bar uses clear background with bottom border ([`51e8f81`](https://github.com/Vit129/kouen-terminal/commit/51e8f81396d7ac8249301b66b92e713e0dc0a5b0))
- Terminal tab bar background uses terminalBackground instead of clear ([`8fca6e2`](https://github.com/Vit129/kouen-terminal/commit/8fca6e2103490cfbf778bd4c269cf4857d82e8b1))
- Activate tab bar height constraint ([`2918f15`](https://github.com/Vit129/kouen-terminal/commit/2918f15b390b901bed7f81b13edb37f26169be6e))
- File editor opacity parity with terminal (P6) ([`1b77e95`](https://github.com/Vit129/kouen-terminal/commit/1b77e957ed272b32e6fc0cfc002a8ebbf83f19df))

## [2.2.2] - 2026-06-08

### Documentation
- Backfill CHANGELOG for v1.9.0, v2.0.0, v2.1.0 ([`b5da031`](https://github.com/Vit129/kouen-terminal/commit/b5da031449187c347be647d64d0b0acbb368860e))
- Add P6 plan — editor opacity parity with terminal ([`a807926`](https://github.com/Vit129/kouen-terminal/commit/a807926705bdd75045921497c782c941a0f3d16c))

### Fixed
- File preview text rendering + draggable editor divider (v2.2.2) ([`80de44c`](https://github.com/Vit129/kouen-terminal/commit/80de44c88ef0c56bddb72c250b29239aab387fb0))
- Editor panel background matches terminal vibrancy ([`a6113ab`](https://github.com/Vit129/kouen-terminal/commit/a6113ab67fdfb6686ad6171c8d1c332467fdbeca))
- Editor panel tab bar no longer overlaps terminal tab bar ([`dd38ddf`](https://github.com/Vit129/kouen-terminal/commit/dd38ddfa5d0a2a1f9b446e7dd579f7cf36d7e0a9))

## [2.2.1] - 2026-06-08

### Added
- Fast CWD tracking via lightweight daemon probe (500ms) ([`29d7c96`](https://github.com/Vit129/kouen-terminal/commit/29d7c96cbc7d55da013b3377b7c335169c183f1a))
- Add Search panel in sidebar — file name fuzzy search + content grep ([`30c1b09`](https://github.com/Vit129/kouen-terminal/commit/30c1b09f63c4b5bff2c9d85f74ce5ed8fc089e58))

### Documentation
- Update agent-memory with CWD tracking, file preview, crash fixes ([`45c1044`](https://github.com/Vit129/kouen-terminal/commit/45c1044ca768c898e69f89c7a3ee423dc1a4e40e))

### Fixed
- Restore real-time git refresh — DispatchSource watcher on .git dir ([`a044eb0`](https://github.com/Vit129/kouen-terminal/commit/a044eb0a005e5f4f89ede2289f4d77bcfba07dbc))
- Crash in GitPanelView.startWatching — @MainActor isolation from utility queue ([`6ed3b89`](https://github.com/Vit129/kouen-terminal/commit/6ed3b89ffeb643b3a6a1930d77c18ebef5db752b))
- GitPanelView watcher crash — bounce to main before accessing self ([`49c37f8`](https://github.com/Vit129/kouen-terminal/commit/49c37f88b15a8cc7560a8eebe63333b22bbe505b))
- MacOS 26 Swift 6 crash, git diff coloring, file tree perf, preview isolation ([`c307929`](https://github.com/Vit129/kouen-terminal/commit/c3079292e524fe14b81db96d6449c27c9343927f))
- File preview split ratio 40/60 with layout retry fallback ([`b29ceab`](https://github.com/Vit129/kouen-terminal/commit/b29ceab7f495d8efe3cacbd8b89dc60bde67cf3f))
- File preview no longer causes black screen + brighter text ([`65df3b8`](https://github.com/Vit129/kouen-terminal/commit/65df3b8c777a03dcb9475b3a286122e89d99d30e))
- Git panel row alignment + redesigned changes list, restore file preview rendering ([`7acb920`](https://github.com/Vit129/kouen-terminal/commit/7acb92035b367c416a9814ff01c43d78275e36aa))
- Sidebar session card now mirrors tab bar (icon + live folder title) ([`55dbbae`](https://github.com/Vit129/kouen-terminal/commit/55dbbaee0014d5e688d6b043681dd6e56b660533))

## [1.8.0] - 2026-06-07

### Added
- Add Worktrees tab with add/remove support ([`20d2b80`](https://github.com/Vit129/kouen-terminal/commit/20d2b80e80a295790345c7db6184175a0266891e))
- Session ID in sidebar, tab reorder fix, session grouping, hide Agent tab ([`825fc5b`](https://github.com/Vit129/kouen-terminal/commit/825fc5bc90dd1bc323b38da0785ff8cceff9d658))

### Documentation
- Add agent-memory/knowledge, update memory + user-profile + graphify ([`0f6162b`](https://github.com/Vit129/kouen-terminal/commit/0f6162b2f5ddbec219c11460d99cfd052f9864dc))

### Fixed
- Resolve correct ACP binary/args per agent kind in Settings ([`c05c9ae`](https://github.com/Vit129/kouen-terminal/commit/c05c9aef443d407eb5685ad778efa23d47ce621d))
- Resolve GitPanelView merge — use Worktrees version, add clearRoot stub ([`662e587`](https://github.com/Vit129/kouen-terminal/commit/662e587c54badfe6041e4fc91c2349e37d9b0e92))
- Suppress DECRPM (mode 2026) and Kitty ?u replies to prevent shell echo race ([`580d49e`](https://github.com/Vit129/kouen-terminal/commit/580d49e045fbe058231122f185622f9a1018642b))
- Stop replying to DECRQM 2026/2027 and Kitty keyboard queries to avoid echo race ([`24d1aa1`](https://github.com/Vit129/kouen-terminal/commit/24d1aa12a7123a08bd5e74cb8f9007d11947bf2a))
- Auto-refresh changes view and show commit details on click ([`c788e18`](https://github.com/Vit129/kouen-terminal/commit/c788e18a8c4ff30cd7f5da32d0a00096aeb8ea60))

## [1.5.1] - 2026-06-06

### Added
- Implement non-blocking async IPC (P2-async) and isolate Prod/Debug/Preview sessions ([`65b0114`](https://github.com/Vit129/kouen-terminal/commit/65b0114b9d28b66352870057e8b862bab15341dc))

### Documentation
- Rewrite README — CMUX + Zed architecture, full feature overview ([`9457ff3`](https://github.com/Vit129/kouen-terminal/commit/9457ff36158dcd90392fdfd3b2b9bf72a4d3d937))

### Fixed
- Force file tree + git panel refresh on session switch ([`e80a0f4`](https://github.com/Vit129/kouen-terminal/commit/e80a0f4521eb89b2bd472c968e8d5af3da462d15))
- Crash in GitPanelView.startWatching — @MainActor isolation from utility queue ([`611f274`](https://github.com/Vit129/kouen-terminal/commit/611f2740990b5061385b2e50766bb64000a00d8b))

## [2.2.0] - 2026-06-07

### Documentation
- Update README (graphify, agent-memory, multi-agent sections) + git real-time refresh ([`3634cbf`](https://github.com/Vit129/kouen-terminal/commit/3634cbf99225deac70a3a68c802dfb7900ac8566))

## [2.1.0] - 2026-06-07

### Added
- Decorate file tree git statuses ([`da39df1`](https://github.com/Vit129/kouen-terminal/commit/da39df1f0a137e4e01ab2b2eb95186a1c964a3c8))
- Add clickable commit history panel ([`48c49f1`](https://github.com/Vit129/kouen-terminal/commit/48c49f14fd24bc06839979af57a53afa0f7c22fc))
- Add LSP client package and preview resources ([`cb90c98`](https://github.com/Vit129/kouen-terminal/commit/cb90c98a896c93de40021b1bdb7b545588463a6b))
- Add syntax and quick look file previews ([`f22016c`](https://github.com/Vit129/kouen-terminal/commit/f22016cf724ddd395366f019ddb783235ce22754))
- ⌘-click file paths in terminal, branch switcher in Files tab, vi-like edit mode ([`ee37a8b`](https://github.com/Vit129/kouen-terminal/commit/ee37a8b7befa81704e7d638a524c430faf9694be))
- Add harness-mcp (MCP server for AI agents) ([`08ce231`](https://github.com/Vit129/kouen-terminal/commit/08ce23172a818e0a5541dfcea604fb17be7df386))
- Add `make install` — build + deploy to /Applications ([`9f98da8`](https://github.com/Vit129/kouen-terminal/commit/9f98da8084b0e3f272e45d4de2033b5d0a02fced))
- Implement ACP Client — agent chat panel in sidebar ([`7aff448`](https://github.com/Vit129/kouen-terminal/commit/7aff4485bd98ea4e2a9a62353ddd316bc486fb62))

### Documentation
- Update README with v2.0.0 file editor features ([`d86df99`](https://github.com/Vit129/kouen-terminal/commit/d86df99ec131fd08d3aca09391e516b792d34daa))

### Fixed
- Tab reordering, git branch display prefix, and metadata refresh order check ([`31a5c79`](https://github.com/Vit129/kouen-terminal/commit/31a5c7981c891b23ef2f24965c881436fa29138f))
- Refine preview isolation and session insertion ([`eadad53`](https://github.com/Vit129/kouen-terminal/commit/eadad532f6c86ec47da3dd4682fdd21ebd30807b))
- Flip gutter coordinate system, default LSP auto-start off ([`1571b74`](https://github.com/Vit129/kouen-terminal/commit/1571b7452ba493a1d82eabc83d08506fc6f38317))
- Session card title updates dynamically when cwd changes ([`14d5219`](https://github.com/Vit129/kouen-terminal/commit/14d52198b032420d7c4d619ed88f693e98862c57))

## [2.0.0] - 2026-06-07

### Added
- Split panel file editor with tabs, syntax, and file ops ([`3bbedf1`](https://github.com/Vit129/kouen-terminal/commit/3bbedf150811dacd5ec15a7fc6d3ac77ea98ea6f))
- Editable file editor with save, undo/redo, find/replace ([`f2cad57`](https://github.com/Vit129/kouen-terminal/commit/f2cad57fce2111d4daf5e9d22796493223885102))
- Vi-like mode (i=insert, Esc=normal) + git diff gutter ([`712999b`](https://github.com/Vit129/kouen-terminal/commit/712999b408f83e3379b758c0c4bbfbcb61c839f3))

### Documentation
- Consolidate completed plans into single archive ([`ad6d3d2`](https://github.com/Vit129/kouen-terminal/commit/ad6d3d29b0b032a469c5ac4e986944c1f4432a66))
- Add Terminal First, IDE Convenience philosophy to README ([`668389d`](https://github.com/Vit129/kouen-terminal/commit/668389d76de98b634eeee66be7dffdfea8680fff))

### Fixed
- Terminal-first split ratio 30/70 (editor is compact panel) ([`3d2b9ee`](https://github.com/Vit129/kouen-terminal/commit/3d2b9ee5174c134492c0288e2ddb38e19fd0a610))

## [1.6.0] - 2026-06-07

### Added
- Dynamic branch display per session (A+B) ([`f50fcb8`](https://github.com/Vit129/kouen-terminal/commit/f50fcb8bc4c0cda70d5227a722724c994be94c51))
- Merge dynamic branch display (A+B) ([`4f663c7`](https://github.com/Vit129/kouen-terminal/commit/4f663c7fdef7e100a0b1f2d026593ad95265b726))
- Add read-only file preview to sidebar (P4 Track 1 MVP) ([`a53f24f`](https://github.com/Vit129/kouen-terminal/commit/a53f24fa91d6c86fcef790a65ed7fe66b537f36a))
- Implement right sidebar layout and document current layout issues ([`6db23a5`](https://github.com/Vit129/kouen-terminal/commit/6db23a579eabad4c147fa6209a311fb5b1c0a22d))
- Right-click toggle button shows Move Sidebar Left/Right menu ([`4004b9e`](https://github.com/Vit129/kouen-terminal/commit/4004b9ed175b3666e794bbdff2f05abc59199f68))

### Documentation
- Add CLAUDE.md developer guide ([`87b8dd6`](https://github.com/Vit129/kouen-terminal/commit/87b8dd693a2a6d5c8cfa3585f4b639964e18b951))
- Merge CLAUDE.md developer guide ([`eb93369`](https://github.com/Vit129/kouen-terminal/commit/eb93369ed5eab69ca8353a8d8de0f472244a3015))
- Update playbook (CASE-006 recursion) and P3 plan with progress + cmuxlayer reference ([`2d73340`](https://github.com/Vit129/kouen-terminal/commit/2d733408b6fec04bb22e19f89d295749f9557fbe))
- Add AGENTS.md for AI coding agents (Codex/Gemini) ([`ce6ec01`](https://github.com/Vit129/kouen-terminal/commit/ce6ec01e1f840f19af850362794bffc300d19d3a))
- Merge AGENTS.md for AI coding agents ([`4a7533b`](https://github.com/Vit129/kouen-terminal/commit/4a7533b19c1b3a9d7ef07a19a1200babfc43d0ba))
- Update all docs for sidebar toggle fix and split down removal ([`6125957`](https://github.com/Vit129/kouen-terminal/commit/6125957b00a0e813cbd1e401529d598715b60f8a))

### Fixed
- N-ary flatten + recursion guard for equal pane sizing ([`225b105`](https://github.com/Vit129/kouen-terminal/commit/225b105e258f90e43cbe306c4af460538f5d780d))
- Real-time sidebar position toggle without restart ([`b9100ee`](https://github.com/Vit129/kouen-terminal/commit/b9100ee33d7ec87360db428df2e5e357363546d3))
- Remove Split Down from all context menus, add Move Sidebar option ([`f7acb5e`](https://github.com/Vit129/kouen-terminal/commit/f7acb5e12f9128fb130847597481160fc4326535))

## [1.3.0-vit] - 2026-06-06

### Added
- Complete inception phases for ACP (Agent Client Protocol) feature ([`bba93bf`](https://github.com/Vit129/kouen-terminal/commit/bba93bfce514eaed1f5a2133dc287fce240cc1f7))
- Implement ACP core transport and process (Phase 1) ([`1df08b0`](https://github.com/Vit129/kouen-terminal/commit/1df08b08ccf7ea45d531836e53819e84adb83fbf))
- Sidebar tab switcher + file tree outline view (Phase 1) ([`c790a64`](https://github.com/Vit129/kouen-terminal/commit/c790a6433cfad7db285c1673b8e5bc62ce7c94c1))
- Replace NSOutlineView file tree with SwiftUI List + onDrag ([`b2c0da4`](https://github.com/Vit129/kouen-terminal/commit/b2c0da48582170f6b4112e885a590f2bc6ab28b6))
- SwiftUI file tree with onDrag ([`56e18da`](https://github.com/Vit129/kouen-terminal/commit/56e18dab957cdfb501de6daad66e874ff1bf95ea))
- SwiftUI file tree - DisclosureGroup expand + lazy load + onDrag ([`b424989`](https://github.com/Vit129/kouen-terminal/commit/b4249891d4643fa5c983b1d63807a17087f8353b))
- Session group expand/collapse, right-aligned action buttons, and close group option ([`0e48c46`](https://github.com/Vit129/kouen-terminal/commit/0e48c464f6ae9dcccb3918ed10fa6498996a64ad))
- Hide Git tab in the sidebar, keeping Sessions and Files tabs ([`f841736`](https://github.com/Vit129/kouen-terminal/commit/f8417364abac622c94cc0b50d7a173425923d70a))
- Wire FSEvents live watcher into file tree view ([`c53b115`](https://github.com/Vit129/kouen-terminal/commit/c53b11570b87acb583cf3c2554d00c0c2b8b5435))
- Add full native support for antigravity/agy and update performance docs ([`f2aced8`](https://github.com/Vit129/kouen-terminal/commit/f2aced8199d7e904b118344e5c4f2cacf8fa5df4))

### Changed
- Panel & session performance fixes + file tree git status ([`c3db2d5`](https://github.com/Vit129/kouen-terminal/commit/c3db2d5fd6f05586cc4c2e4931a1ad8a0f5e672d))

### Documentation
- Add IDE sidebar feature README ([`1f04e7b`](https://github.com/Vit129/kouen-terminal/commit/1f04e7bfe259c04a0a15160830be9f23f65e425b))
- Add CHANGELOG.md for v1.0.0 ([`583fbe8`](https://github.com/Vit129/kouen-terminal/commit/583fbe866e82ac06e7636e1ad6acb222e3216adb))
- Add fork attribution to README ([`1cb5051`](https://github.com/Vit129/kouen-terminal/commit/1cb5051222c7135d9e335aacc97595612f8f8cd6))
- Remove non-working features and git clone from README ([`3c02d60`](https://github.com/Vit129/kouen-terminal/commit/3c02d60ce5ee7ca7b42be0012d747482f4dabdee))
- Add IDE Sidebar section covering Session, Files, and Git panels ([`4ad5a80`](https://github.com/Vit129/kouen-terminal/commit/4ad5a80c6d256833146899f3d02718c87e73cab8))
- Update README + CHANGELOG for v1.1.0 ([`2dab4d4`](https://github.com/Vit129/kouen-terminal/commit/2dab4d4388bee70f119e99c1d339c288127a9482))
- Add panel & session performance + file tree auto-update plan ([`02c69e3`](https://github.com/Vit129/kouen-terminal/commit/02c69e3e72ca49564093933bebafaa9ec328f2cf))
- Update panel-session-performance plan — mark P1/P3-P6/F1A-F1F done, note F1-G and P2 pending ([`4c9d780`](https://github.com/Vit129/kouen-terminal/commit/4c9d780386c5d70de74d315f2e5de71b72fd976b))

### Fixed
- Restore drag-drop to terminal + add image drag support ([`461bb79`](https://github.com/Vit129/kouen-terminal/commit/461bb79aaf6b8b56b5c5a9947fd2821c33c26316))
- Drag-drop to terminal (files, folders, images) ([`a6c6217`](https://github.com/Vit129/kouen-terminal/commit/a6c62176daefcb35948bc19bb35eeae5644670ed))
- Remove action selector that blocked drag initiation in file tree ([`7a68a07`](https://github.com/Vit129/kouen-terminal/commit/7a68a074fa5ca4d0341c3bc067cde118b08d1af0))
- Remove action selector that blocked drag initiation in file tree ([`f6789dd`](https://github.com/Vit129/kouen-terminal/commit/f6789dd5c487fa2fd8ba62dc78d9ea41bba78f6c))
- Single-click folder expands/collapses in file tree ([`fd5632b`](https://github.com/Vit129/kouen-terminal/commit/fd5632b384109329d0ef38e760f4b1dc05e5fac9))
- Merge drag-drop + folder click fixes from worktree ([`7c4c71a`](https://github.com/Vit129/kouen-terminal/commit/7c4c71a189c45b39d9b4c000db17f62ae7e4a13a))
- Defer UNUserNotificationCenter init to avoid macOS 26 launch crash ([`017bff7`](https://github.com/Vit129/kouen-terminal/commit/017bff7c160ea6acb9bcd76128117c3c3b8dafdb))
- Merge notification crash fix ([`18f3470`](https://github.com/Vit129/kouen-terminal/commit/18f3470318366737289b06cb0488481560d32a49))
- Disable UNUserNotificationCenter to avoid macOS 26 launch crash ([`fc4c117`](https://github.com/Vit129/kouen-terminal/commit/fc4c117090797eac1e53b86f04fab83e862048f9))
- Disable desktop notifications for macOS 26 compatibility ([`ddd9341`](https://github.com/Vit129/kouen-terminal/commit/ddd93413b3ee303506e48d8d4f39e0645d61dc59))
- Show empty state when no repo; surface git errors via alert ([`993cdcb`](https://github.com/Vit129/kouen-terminal/commit/993cdcb2a5fe79dc7b3a7b3378c58613c4b25c23))
- Disable NotificationPermission UNUserNotificationCenter calls on macOS 26 ([`f6f8be0`](https://github.com/Vit129/kouen-terminal/commit/f6f8be038c510dfbf117fcee9a4fd311b4967b09))
- Pre-load first-level children so List(children:) tree structure renders correctly ([`9fe4748`](https://github.com/Vit129/kouen-terminal/commit/9fe474891e7126ee507e77cb3dec9b82fa61b902))
- Notification crash + file tree expand ([`3ecec6e`](https://github.com/Vit129/kouen-terminal/commit/3ecec6e251cd5622183095f5389b6ffba2326601))
- Use DisclosureGroup so folder label click expands/collapses + lazy child loading ([`b2e152e`](https://github.com/Vit129/kouen-terminal/commit/b2e152eab2ef49f6467bccac29d2ff482a97407f))
- Folder expand/collapse in SwiftUI file tree ([`a3dd841`](https://github.com/Vit129/kouen-terminal/commit/a3dd841ac1524ebd664b1556bb7c3f09546afd36))
- Folder expand/collapse ([`56373ff`](https://github.com/Vit129/kouen-terminal/commit/56373ff0b661a538266b18fb9fb88801ebf2cf2c))
- Make top bar zoom instant ([`6f441eb`](https://github.com/Vit129/kouen-terminal/commit/6f441ebba4089ffa2fadecc6b865110e0d1b2be7))
- Make window zoom on double-click work across the entire top panel (tab bar and sidebar titlebar header) ([`2734062`](https://github.com/Vit129/kouen-terminal/commit/2734062137922608d0d813dfaf78e86f9ccb7aa6))

## [1.0.0] - 2026-05-31

