import XCTest
@testable import KouenCore

/// Covers the shared (KouenCore) hook installer used by both `kouen-cli install-hooks`
/// and the Settings "Install hooks" button. All tests run against a temp `homeOverride` so
/// they never touch the real `~/.claude` etc.
final class AgentHookInstallerTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("kouen-hooks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    func testInstallCreatesFileAndIsDetected() throws {
        XCTAssertFalse(AgentHookInstaller.isInstalled(agent: .claudeCode, homeOverride: home))
        let result = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path.path))
        XCTAssertNil(result.backedUp)
        XCTAssertFalse(result.replacedInvalidJSON)
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .claudeCode, homeOverride: home))
        let text = try String(contentsOf: result.path, encoding: .utf8)
        XCTAssertTrue(text.contains("kouen-cli notify"))
    }

    func testInstallPreservesExistingUserConfig() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .claudeCode, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = #"{ "model": "claude-opus", "permissions": { "allow": ["Bash"] } }"#
        try existing.write(to: url, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        XCTAssertNotNil(result.backedUp) // backed the user's file up
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus")
        XCTAssertNotNil(json["hooks"]) // ours merged in
        XCTAssertNotNil((json["permissions"] as? [String: Any])?["allow"])
    }

    func testReinstallIsIdempotent() throws {
        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let again = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        XCTAssertNotNil(again.backedUp)
        let data = try Data(contentsOf: again.path)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let hooks = json["hooks"] as? [String: Any]
        let notification = hooks?["Notification"] as? [Any]
        XCTAssertEqual(notification?.count, 1) // not duplicated on reinstall
    }

    func testClaudeNotificationUsesStdinHookNotEnvVar() throws {
        let result = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let command = try claudeNotificationCommand(at: result.path)
        XCTAssertTrue(command.contains("--from-hook"), "Notification body must come from stdin")
        // The PATH prefix must point at the platform's real install location — a hardcoded
        // macOS path in Linux-installed hooks made every notification silently vanish
        // (`kouen-cli` was never on the hook's PATH).
        #if os(Linux)
        XCTAssertTrue(command.contains(
            "PATH=\"${XDG_DATA_HOME:-$HOME/.local/share}/kouen/bin:$PATH\" kouen-cli notify"))
        #else
        XCTAssertTrue(command.contains("PATH=\"$HOME/Library/Application Support/Kouen/bin:$PATH\" kouen-cli notify"))
        #endif
        XCTAssertFalse(command.contains("KOUEN_NOTIFY_MESSAGE"), "the dangling env var must be gone")
    }

    /// The migration: a config carrying the OLD broken `$KOUEN_NOTIFY_MESSAGE` hook must
    /// converge to exactly one corrected entry on (re)install — not append a second copy.
    func testInstallUpgradesOldBrokenNotificationHookInPlace() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .claudeCode, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let broken = #"""
        {
          "model": "claude-opus",
          "permissions": { "allow": ["Bash"] },
          "hooks": {
            "Notification": [
              { "matcher": "*", "hooks": [ { "type": "command", "command": "kouen-cli notify --surface \"$KOUEN_SURFACE\" --title \"Claude Code\" --body \"$KOUEN_NOTIFY_MESSAGE\"" } ] }
            ],
            "PreToolUse": [
              { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo my-own-hook" } ] }
            ]
          }
        }
        """#
        try broken.write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let notification = try XCTUnwrap(hooks["Notification"] as? [Any])
        XCTAssertEqual(notification.count, 1, "old broken entry replaced, not appended")
        let command = try claudeNotificationCommand(at: url)
        XCTAssertTrue(command.contains("--from-hook"))
        XCTAssertFalse(command.contains("KOUEN_NOTIFY_MESSAGE"))
        XCTAssertTrue(command.contains("kouen-cli notify"), "converges to the current (post-rename) command")
        // Unrelated config + the user's own non-Kouen hook survive untouched.
        XCTAssertEqual(json["model"] as? String, "claude-opus")
        XCTAssertNotNil((json["permissions"] as? [String: Any])?["allow"])
        XCTAssertNotNil(hooks["PreToolUse"] as? [Any])
    }

    /// A user's *own* Notification entry (no Kouen marker) must be preserved alongside ours.
    func testInstallPreservesUserNotificationEntries() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .claudeCode, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = #"""
        { "hooks": { "Notification": [
          { "matcher": "*", "hooks": [ { "type": "command", "command": "say hello" } ] }
        ] } }
        """#
        try existing.write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        let notification = try XCTUnwrap((json["hooks"] as? [String: Any])?["Notification"] as? [Any])
        XCTAssertEqual(notification.count, 2, "the user's entry plus exactly one Kouen entry")
        let commands = notification.compactMap { entry -> String? in
            ((entry as? [String: Any])?["hooks"] as? [Any])?
                .compactMap { ($0 as? [String: Any])?["command"] as? String }.first
        }
        XCTAssertTrue(commands.contains("say hello"))
        XCTAssertTrue(commands.contains { $0.contains("--from-hook") })
    }

    func testReinstallStaysSingleAndCorrected() throws {
        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .claudeCode, homeOverride: home))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        let notification = try XCTUnwrap((json["hooks"] as? [String: Any])?["Notification"] as? [Any])
        XCTAssertEqual(notification.count, 1)
        XCTAssertTrue(try claudeNotificationCommand(at: url).contains("--from-hook"))
    }

    func testDetectInstalledAgentsFindsAgentByConfigDir() throws {
        // Inject a table whose executables can't exist on PATH, so the result is driven purely
        // by config-dir presence — deterministic regardless of what's installed on the host.
        let table = AgentTable(entries: AgentKind.allCases.map {
            AgentTableEntry(kind: $0, executables: ["kouen-test-\(UUID().uuidString)"])
        })
        // A bare `~/.claude` dir (no binary needed) signals Claude Code is set up here.
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        let detected = AgentHookInstaller.detectInstalledAgents(homeOverride: home, table: table)
        XCTAssertEqual(detected, [.claudeCode], "only the agent with a config dir is offered")
    }

    /// Helper: pull the single Kouen `Notification` command string out of a Claude config.
    private func claudeNotificationCommand(at url: URL) throws -> String {
        try claudeHookCommand(at: url, event: "Notification")
    }

    /// Helper: pull the single Kouen command string out of a Claude config for the given
    /// event ("Notification" or "Stop").
    private func claudeHookCommand(at url: URL, event: String) throws -> String {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let entries = try XCTUnwrap(hooks[event] as? [Any])
        let kouen = entries.compactMap { entry -> String? in
            ((entry as? [String: Any])?["hooks"] as? [Any])?
                .compactMap { ($0 as? [String: Any])?["command"] as? String }
                .first { $0.contains("kouen-cli notify") || $0.contains("kouen-cli notify") }
        }
        return try XCTUnwrap(kouen.first)
    }

    /// Regression test for the "every normal turn shows as needing approval" bug: the Stop
    /// hook (turn finished, no decision needed) must pass `--status done` so the daemon sets
    /// `Tab.status = .done` instead of `.waiting` — while the Notification hook (a real
    /// attention/permission event) must NOT carry that flag, since it should still set
    /// `.waiting` and show the notch's Reply/Deny/Allow controls.
    func testClaudeStopHookMarksDoneNotWaiting() throws {
        let result = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let stopCommand = try claudeHookCommand(at: result.path, event: "Stop")
        XCTAssertTrue(stopCommand.contains("--status done"), "Stop hook must mark the tab done, not waiting")
        let notificationCommand = try claudeNotificationCommand(at: result.path)
        XCTAssertFalse(notificationCommand.contains("--status done"), "a real attention event must still set waiting")
    }

    func testInvalidExistingJSONIsReplacedWithBackup() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .codex, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "not json at all".write(to: url, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .codex, homeOverride: home)
        XCTAssertTrue(result.replacedInvalidJSON)
        XCTAssertNotNil(result.backedUp)
        // The written file is now valid JSON with our hook.
        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .codex, homeOverride: home))
    }

    func testUnsupportedAgentThrows() {
        XCTAssertThrowsError(try AgentHookInstaller.install(agent: .aider, homeOverride: home)) { error in
            XCTAssertEqual(error as? AgentHookInstaller.InstallError, .unsupported(.aider))
        }
        XCTAssertFalse(AgentHookInstaller.canInstall(.gemini))
        XCTAssertNil(AgentHookInstaller.hookConfigURL(for: .goose, homeOverride: home))
    }

    func testCodexInstallsEventHooksWithoutFeatureFlag() throws {
        let result = try AgentHookInstaller.install(agent: .codex, homeOverride: home)
        // hooks.json uses the event/matcher shape (not the inert on_pause/on_done keys).
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try Data(contentsOf: result.path)) as? [String: Any]
        )
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        XCTAssertNil(hooks["on_pause"])
        XCTAssertNotNil(hooks["Stop"] as? [Any])
        XCTAssertNotNil(hooks["PermissionRequest"] as? [Any])
        XCTAssertNotNil(hooks["Notification"] as? [Any])
        // Codex hooks are enabled by default now — we must NOT write config.toml anymore.
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".codex/config.toml").path))
    }

    /// P38 Phase B: Claude Code's Task-subagent hooks — matcher must be scoped to `Task` (not
    /// `*`, which would fire on every tool call), and correctly idempotent/pruned on reinstall.
    func testClaudeInstallsSubagentHooksScopedToTaskMatcher() throws {
        let result = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: result.path)) as? [String: Any])
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])

        let preToolUse = try XCTUnwrap(hooks["PreToolUse"] as? [[String: Any]])
        XCTAssertEqual(preToolUse.count, 1)
        XCTAssertEqual(preToolUse.first?["matcher"] as? String, "Task")
        let preToolUseCommand = try XCTUnwrap(((preToolUse.first?["hooks"] as? [[String: Any]])?.first)?["command"] as? String)
        XCTAssertTrue(preToolUseCommand.contains("--subagent start"))

        let subagentStop = try XCTUnwrap(hooks["SubagentStop"] as? [[String: Any]])
        let stopCommand = try XCTUnwrap(((subagentStop.first?["hooks"] as? [[String: Any]])?.first)?["command"] as? String)
        XCTAssertTrue(stopCommand.contains("--subagent stop"))

        // Reinstall converges to exactly one entry each (prune works), same as every other event.
        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let reinstalled = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: result.path)) as? [String: Any])
        let reinstalledHooks = try XCTUnwrap(reinstalled["hooks"] as? [String: Any])
        XCTAssertEqual((reinstalledHooks["PreToolUse"] as? [Any])?.count, 1)
        XCTAssertEqual((reinstalledHooks["SubagentStop"] as? [Any])?.count, 1)
    }

    /// A user's own unrelated `PreToolUse` hook (e.g. a `Bash` matcher) must survive install —
    /// `managedEvents` now includes `PreToolUse` for prune purposes, but prune must only remove
    /// Kouen-owned entries by content marker, not wipe the whole event array.
    func testClaudeInstallPreservesUsersOwnPreToolUseHook() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .claudeCode, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = #"""
        { "hooks": { "PreToolUse": [
          { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo my-own-hook" } ] }
        ] } }
        """#
        try existing.write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .claudeCode, homeOverride: home)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        let preToolUse = try XCTUnwrap((json["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]])
        let matchers = preToolUse.compactMap { $0["matcher"] as? String }
        XCTAssertTrue(matchers.contains("Bash"), "user's own PreToolUse entry must survive")
        XCTAssertTrue(matchers.contains("Task"), "Kouen's Task entry must be added")
    }

    func testCursorInstallsStopHookArrayShape() throws {
        // Seed the user's own stop hook to prove it survives the merge.
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .cursor, homeOverride: home))
        XCTAssertTrue(url.path.hasSuffix(".cursor/hooks.json"))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{ "version": 1, "hooks": { "stop": [ { "command": "echo mine" } ] } }"#
            .write(to: url, atomically: true, encoding: .utf8)

        func stopCommands() throws -> [String] {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
            XCTAssertEqual(json["version"] as? Int, 1)
            let stop = try XCTUnwrap((json["hooks"] as? [String: Any])?["stop"] as? [Any])
            return stop.compactMap { ($0 as? [String: Any])?["command"] as? String }
        }

        _ = try AgentHookInstaller.install(agent: .cursor, homeOverride: home)
        var commands = try stopCommands()
        XCTAssertTrue(commands.contains("echo mine"))
        XCTAssertEqual(commands.filter { $0.contains("kouen-cli notify") }.count, 1)

        // Reinstall converges to exactly one Kouen entry (prune works), user entry intact.
        _ = try AgentHookInstaller.install(agent: .cursor, homeOverride: home)
        commands = try stopCommands()
        XCTAssertTrue(commands.contains("echo mine"))
        XCTAssertEqual(commands.filter { $0.contains("kouen-cli notify") }.count, 1)
    }

    func testAntigravityMergesNamedGroupAtRootAndConverges() throws {
        // Seed another tool's own top-level hook group to prove it survives the merge —
        // Antigravity's `hooks.json` has no shared `hooks` wrapper key like Claude/Codex/Cursor;
        // every tool owns its own named key at the root.
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .antigravity, homeOverride: home))
        XCTAssertTrue(url.path.hasSuffix(".gemini/config/hooks.json"))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{ "other-tool": { "Stop": [ { "type": "command", "command": "echo mine" } ] } }"#
            .write(to: url, atomically: true, encoding: .utf8)

        func stopCommands(_ groupKey: String) throws -> [String] {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
            let stop = try XCTUnwrap((json[groupKey] as? [String: Any])?["Stop"] as? [Any])
            return stop.compactMap { ($0 as? [String: Any])?["command"] as? String }
        }

        _ = try AgentHookInstaller.install(agent: .antigravity, homeOverride: home)
        XCTAssertEqual(try stopCommands("other-tool"), ["echo mine"], "sibling tool's own group must survive")
        XCTAssertEqual(try stopCommands("kouen-notify").filter { $0.contains("kouen-cli notify") }.count, 1)
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .antigravity, homeOverride: home))

        // Reinstall converges to exactly one Kouen entry (array-union dedup), sibling untouched.
        _ = try AgentHookInstaller.install(agent: .antigravity, homeOverride: home)
        XCTAssertEqual(try stopCommands("other-tool"), ["echo mine"])
        XCTAssertEqual(try stopCommands("kouen-notify").filter { $0.contains("kouen-cli notify") }.count, 1)
    }

    func testGrokWritesOwnFlatFileAndLeavesSiblingsAlone() throws {
        let result = try AgentHookInstaller.install(agent: .grok, homeOverride: home)
        XCTAssertTrue(result.path.path.hasSuffix(".grok/hooks/kouen.json"))
        // Grok merges every *.json in the dir — a sibling user file must be untouched.
        let sibling = result.path.deletingLastPathComponent().appendingPathComponent("user.json")
        try #"{"pre-edit":"echo hi"}"#.write(to: sibling, atomically: true, encoding: .utf8)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: result.path)) as? [String: Any])
        XCTAssertTrue((json["on-complete"] as? String)?.contains("kouen-cli notify") ?? false)
        XCTAssertTrue((json["on-error"] as? String)?.contains("kouen-cli notify") ?? false)
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .grok, homeOverride: home))

        let again = try AgentHookInstaller.install(agent: .grok, homeOverride: home)
        XCTAssertNotNil(again.backedUp) // our own file existed → backed up before overwrite
        XCTAssertEqual(try String(contentsOf: sibling, encoding: .utf8), #"{"pre-edit":"echo hi"}"#)
    }

    func testOpenCodeInstallsPluginFile() throws {
        XCTAssertTrue(AgentHookInstaller.canInstall(.openCode))
        let result = try AgentHookInstaller.install(agent: .openCode, homeOverride: home)
        XCTAssertTrue(result.path.path.hasSuffix(".config/opencode/plugins/kouen.js"))
        let text = try String(contentsOf: result.path, encoding: .utf8)
        XCTAssertTrue(text.contains("session.idle"))
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .openCode, homeOverride: home))
        // Idempotent overwrite: reinstall backs up and reproduces the same plugin.
        let again = try AgentHookInstaller.install(agent: .openCode, homeOverride: home)
        XCTAssertNotNil(again.backedUp)
        XCTAssertEqual(try String(contentsOf: again.path, encoding: .utf8), text)
    }

    func testPiInstallsTsExtension() throws {
        let result = try AgentHookInstaller.install(agent: .pi, homeOverride: home)
        XCTAssertTrue(result.path.path.hasSuffix(".pi/agent/extensions/kouen.ts"))
        let text = try String(contentsOf: result.path, encoding: .utf8)
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(text.contains("session_end"))
        XCTAssertTrue(text.contains("KOUEN_SURFACE ?? \"\""))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .pi, homeOverride: home))
    }


    func testHermesYamlEditPreservesContentAndIsIdempotent() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .hermes, homeOverride: home))
        XCTAssertTrue(url.path.hasSuffix(".hermes/config.yaml"))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "model: hermes-3\nprovider: nous\n".write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .hermes, homeOverride: home)
        var text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("model: hermes-3"))   // user content preserved
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(text.contains("kouen-managed"))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .hermes, homeOverride: home))

        // Reinstall replaces the managed region in place — not a second copy.
        _ = try AgentHookInstaller.install(agent: .hermes, homeOverride: home)
        text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(text.components(separatedBy: "kouen-cli notify").count - 1, 1)
    }

    func testOpenClawJson5EditPreservesComments() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .openClaw, homeOverride: home))
        XCTAssertTrue(url.path.hasSuffix(".openclaw/openclaw.json"))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let json5 = """
        {
          // user comment — must survive
          gateway: { port: 8080 },
        }
        """
        try json5.write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .openClaw, homeOverride: home)
        var text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("// user comment — must survive"), "JSON5 comments must not be destroyed")
        XCTAssertTrue(text.contains("gateway"))
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .openClaw, homeOverride: home))

        // Reinstall replaces the managed region in place — not a second copy.
        _ = try AgentHookInstaller.install(agent: .openClaw, homeOverride: home)
        text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(text.components(separatedBy: "kouen-cli notify").count - 1, 1)
    }

    func testHermesSkipsWhenConfigAlreadyDefinesHooks() throws {
        // A user who already has a top-level `hooks:` must not get a duplicate key (invalid YAML).
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .hermes, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = "model: hermes-3\nhooks:\n  - event: lint\n    command: 'echo mine'\n"
        try original.write(to: url, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .hermes, homeOverride: home)
        XCTAssertTrue(result.needsManualMerge)
        XCTAssertFalse(AgentHookInstaller.isInstalled(agent: .hermes, homeOverride: home))
        // File left exactly as it was — no corruption, no second `hooks:`.
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testOpenClawSkipsWhenConfigAlreadyDefinesHooks() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .openClaw, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = "{\n  \"hooks\": { \"x\": 1 },\n}\n"
        try original.write(to: url, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .openClaw, homeOverride: home)
        XCTAssertTrue(result.needsManualMerge)
        XCTAssertFalse(AgentHookInstaller.isInstalled(agent: .openClaw, homeOverride: home))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testRegionEditSkipsTornSentinel() throws {
        // Only the begin marker survives (e.g. a manual edit) — refuse to guess; leave it alone.
        // Uses the pre-rename sentinel text deliberately — also covers that a torn *legacy*
        // region is recognized as torn, not mistaken for absent (which would let a second
        // region get appended alongside it).
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .hermes, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = "model: hermes-3\n# >>> kouen-managed (do not edit) >>>\nhooks:\n  - event: stop\n"
        try original.write(to: url, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .hermes, homeOverride: home)
        XCTAssertTrue(result.needsManualMerge)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testFreshOpenClawInstallProducesWrappedObject() throws {
        // New user: no openclaw.json yet — install must create a valid JSON5 root object.
        let result = try AgentHookInstaller.install(agent: .openClaw, homeOverride: home)
        XCTAssertNil(result.backedUp)
        let text = try String(contentsOf: result.path, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("{"))
        XCTAssertTrue(text.contains("\"hooks\""))
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .openClaw, homeOverride: home))
    }

    func testFreshHermesInstallCreatesConfigYaml() throws {
        let result = try AgentHookInstaller.install(agent: .hermes, homeOverride: home)
        XCTAssertNil(result.backedUp)
        let text = try String(contentsOf: result.path, encoding: .utf8)
        XCTAssertTrue(text.contains("hooks:"))
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(AgentHookInstaller.isInstalled(agent: .hermes, homeOverride: home))
    }

    func testLegacyOrphanRemovedWhenKouenOwned() throws {
        // An older Kouen wrote cursor hooks at the now-wrong `.cursor/agent-hooks.json`.
        let legacy = home.appendingPathComponent(".cursor/agent-hooks.json")
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{ "agent_notify": "kouen-cli notify --title Cursor" }"#.write(to: legacy, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .cursor, homeOverride: home)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path), "Kouen-owned orphan removed")
        XCTAssertEqual(result.removedLegacy, [legacy])
    }

    func testLegacyFilePreservedWhenUserOwned() throws {
        let legacy = home.appendingPathComponent(".cursor/agent-hooks.json")
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try #"{ "my_own": "echo not kouen" }"#.write(to: legacy, atomically: true, encoding: .utf8)

        let result = try AgentHookInstaller.install(agent: .cursor, homeOverride: home)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path), "a non-Kouen file at the old path is left alone")
        XCTAssertTrue(result.removedLegacy.isEmpty)
    }

    func testResolveAgentNameAliases() {
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("claude"), .claudeCode)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("claude-code"), .claudeCode)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("cursor-agent"), .cursor)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("codex"), .codex)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("grok"), .grok)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("grok-build"), .grok)
        XCTAssertEqual(AgentHookInstaller.resolveAgentName("opencode"), .openCode)
        XCTAssertNil(AgentHookInstaller.resolveAgentName("nonsense-agent"))
    }

    /// `installableAgents` (the curated, ordered list) and `canInstall` (derived from the
    /// strategy table) must never diverge — adding a strategy without listing the agent, or vice
    /// versa, is a bug.
    func testInstallableAgentsMatchStrategyCapability() {
        XCTAssertEqual(
            Set(AgentHookInstaller.installableAgents),
            Set(AgentKind.allCases.filter { AgentHookInstaller.canInstall($0) })
        )
    }

    /// A header comment containing a brace must not be mistaken for the JSON5 root object.
    func testOpenClawJson5InsertSkipsBraceInLeadingComment() throws {
        let url = try XCTUnwrap(AgentHookInstaller.hookConfigURL(for: .openClaw, homeOverride: home))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let json5 = """
        // OpenClaw config — see docs at { example.com } for the schema
        {
          gateway: { port: 8080 },
        }
        """
        try json5.write(to: url, atomically: true, encoding: .utf8)

        _ = try AgentHookInstaller.install(agent: .openClaw, homeOverride: home)
        let text = try String(contentsOf: url, encoding: .utf8)
        // The managed region landed inside the real root object, after the header comment.
        let header = try XCTUnwrap(text.range(of: "see docs at"))
        let region = try XCTUnwrap(text.range(of: "kouen-managed"))
        XCTAssertTrue(header.lowerBound < region.lowerBound, "region must come after the header comment")
        XCTAssertTrue(text.contains("kouen-cli notify"))
        XCTAssertTrue(text.contains("gateway"))
    }

    func testSetupPromptCoversEveryInstallableAgentAndItsRealPath() {
        let prompt = AgentHookInstaller.setupPrompt
        XCTAssertTrue(prompt.contains("kouen-cli notify"))
        XCTAssertTrue(prompt.contains("$KOUEN_SURFACE"))
        XCTAssertTrue(prompt.contains("install-hooks"))
        for kind in AgentHookInstaller.installableAgents {
            XCTAssertTrue(prompt.contains("install-hooks \(kind.rawValue)"),
                          "prompt should tell the IDE how to install \(kind.rawValue)")
            if let url = AgentHookInstaller.hookConfigURL(for: kind) {
                XCTAssertTrue(prompt.contains(url.lastPathComponent),
                              "prompt should cite \(kind.rawValue)'s config file \(url.lastPathComponent)")
            }
        }
    }

    func testGrokIsInstallableAndDetectable() {
        XCTAssertTrue(AgentHookInstaller.canInstall(.grok))
        XCTAssertTrue(AgentHookInstaller.installableAgents.contains(.grok))
        XCTAssertTrue(AgentTable.default.entries.contains { $0.kind == .grok && $0.executables.contains("grok") })
    }
}
