import XCTest
@testable import KouenMCP
import KouenCore

final class KouenDaemonToolsTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testControlGateRequiresExactOne() {
        XCTAssertFalse(KouenDaemonTools.isControlEnabled(environment: [:]))
        XCTAssertFalse(KouenDaemonTools.isControlEnabled(environment: ["KOUEN_MCP_ALLOW_CONTROL": "true"]))
        XCTAssertFalse(KouenDaemonTools.isControlEnabled(environment: ["KOUEN_MCP_ALLOW_CONTROL": "0"]))
        XCTAssertTrue(KouenDaemonTools.isControlEnabled(environment: ["KOUEN_MCP_ALLOW_CONTROL": "1"]))
    }

    func testMutatingToolReturnsDeterministicErrorWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.sendPaneText(surfaceId: "surface", text: "echo nope\n", bracketed: false)
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    func testPolicyAbsentUsesSafeDefaults() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("readFile"))
        XCTAssertTrue(policy.isToolAllowed("kouenList"))
        XCTAssertFalse(policy.isToolAllowed("writeFile"))
        XCTAssertFalse(policy.isToolAllowed("runCommand"))
        XCTAssertFalse(policy.isToolAllowed("sendPaneText"))
    }

    /// P16 PBI-BOARD-005: `kouenBoard` is a read-only tool, so it must be
    /// allowed by the default policy and registered in `ToolRegistry` like
    /// `kouenList`.
    func testKouenBoardIsReadOnlyAndRegistered() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenBoard"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: [String] = tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        }
        XCTAssertTrue(names.contains("kouenBoard"))
    }

    /// P40 F1: Task tools are read/write but not gated behind the control flag (same
    /// tier as kouenBoard, not sendPaneText) — Tasks are Kouen-app-local bookkeeping,
    /// not a mechanism to run arbitrary commands.
    func testTaskToolsAreRegistered() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        for expected in ["kouenTaskList", "kouenTaskGet", "kouenTaskCreate", "kouenTaskUpdate", "kouenTaskDelete"] {
            XCTAssertTrue(names.contains(expected), "Expected \(expected) to be registered")
        }
    }

    /// P44a: kouenPRStatus is read-only (never gated), same tier as gitStatus/gitDiff/
    /// gitLog — an Orchestrator polling CI shouldn't need KOUEN_MCP_ALLOW_CONTROL.
    func testKouenPRStatusIsRegisteredReadOnly() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenPRStatus"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        XCTAssertTrue(names.contains("kouenPRStatus"))
    }

    /// P44a: kouenSpawnWorker types an arbitrary prompt into a freshly-launched agent —
    /// same risk tier as sendPaneText, must require the control gate, unlike
    /// kouenSpawnAgent (launches a fixed known CLI, no arbitrary text typed).
    func testKouenSpawnWorkerRegisteredAndGated() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertFalse(policy.isToolAllowed("kouenSpawnWorker"))
        XCTAssertTrue(policy.isToolAllowed("kouenSpawnAgent"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        XCTAssertTrue(names.contains("kouenSpawnWorker"))
    }

    func testKouenSpawnWorkerBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.kouenSpawnWorker(
            agent: "claude", workspaceId: nil, cwd: nil,
            worktreePath: nil, parentRepoPath: nil, taskName: nil, prompt: "do the thing"
        )
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    func testKouenTaskGetRejectsInvalidUUID() async {
        let tools = KouenDaemonTools(controlEnabled: { true })
        let (result, error) = await tools.taskGet(id: "not-a-uuid")
        XCTAssertNil(result)
        XCTAssertEqual(error?.code, -32602)
    }

    /// P40 F2: kouenWorktreeList is read-only (never gated), Create/Remove mutate the
    /// filesystem and must be gated like sendPaneText/spawnSession.
    func testWorktreeToolsAreRegisteredWithCorrectGating() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenWorktreeList"))
        XCTAssertFalse(policy.isToolAllowed("kouenWorktreeCreate"))
        XCTAssertFalse(policy.isToolAllowed("kouenWorktreeRemove"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        for expected in ["kouenWorktreeList", "kouenWorktreeCreate", "kouenWorktreeRemove"] {
            XCTAssertTrue(names.contains(expected), "Expected \(expected) to be registered")
        }
    }

    func testKouenWorktreeCreateBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.worktreeCreate(
            repoPath: "/tmp", sessionID: "x", branch: nil, baseRef: nil
        )
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    /// P40 F3: kouenHostList is registered, read-only (never gated), and there is no
    /// create/update/delete counterpart — the write boundary is enforced by absence,
    /// not a runtime check, so this also guards against one being added by accident.
    func testHostListIsRegisteredReadOnlyAndHasNoWriteCounterpart() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenHostList"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        XCTAssertTrue(names.contains("kouenHostList"))
        for forbidden in ["kouenHostCreate", "kouenHostUpdate", "kouenHostDelete", "kouenHostRemove"] {
            XCTAssertFalse(names.contains(forbidden), "\(forbidden) must not exist — Settings UI is the only write path")
        }
    }

    /// Mirrors `testHostListIsRegisteredReadOnlyAndHasNoWriteCounterpart` — kouenProjectsList
    /// has no registration step (see KouenDaemonTools.projectsList doc comment), so there is
    /// no create/update/delete counterpart to guard either.
    func testProjectsListIsRegisteredReadOnlyAndHasNoWriteCounterpart() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenProjectsList"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        XCTAssertTrue(names.contains("kouenProjectsList"))
        for forbidden in ["kouenProjectsCreate", "kouenProjectsUpdate", "kouenProjectsDelete", "kouenProjectsRemove"] {
            XCTAssertFalse(names.contains(forbidden), "\(forbidden) must not exist — no registration store to write to")
        }
    }

    /// Pure dedupe logic: same repo root from two tabs collapses to one entry, sorted by path.
    func testDedupeProjectsCollapsesDuplicateRootsAndSortsByPath() {
        let roots = [
            "/Users/x/Git/beta", "/Users/x/Git/alpha", "/Users/x/Git/beta", "/Users/x/Git/alpha",
        ]
        let projects = KouenDaemonTools.dedupeProjects(roots: roots)
        XCTAssertEqual(projects.map(\.path), ["/Users/x/Git/alpha", "/Users/x/Git/beta"])
        XCTAssertEqual(projects.map(\.name), ["alpha", "beta"])
    }

    /// P41: List/Get are read-only (never gated), Create/Update/Delete/Pause/Resume/RunNow
    /// mutate state (spawn a session on RunNow) and must be gated like sendPaneText/spawnSession.
    func testAutomationToolsAreRegisteredWithCorrectGating() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenAutomationList"))
        XCTAssertTrue(policy.isToolAllowed("kouenAutomationGet"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationCreate"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationUpdate"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationDelete"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationPause"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationResume"))
        XCTAssertFalse(policy.isToolAllowed("kouenAutomationRunNow"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        for expected in [
            "kouenAutomationList", "kouenAutomationGet", "kouenAutomationCreate", "kouenAutomationUpdate",
            "kouenAutomationDelete", "kouenAutomationPause", "kouenAutomationResume", "kouenAutomationRunNow",
        ] {
            XCTAssertTrue(names.contains(expected), "Expected \(expected) to be registered")
        }
    }

    func testKouenAutomationGetRejectsInvalidUUID() async {
        let tools = KouenDaemonTools(controlEnabled: { true })
        let (result, error) = await tools.automationGet(id: "not-a-uuid")
        XCTAssertNil(result)
        XCTAssertEqual(error?.code, -32602)
    }

    func testKouenAutomationCreateBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.automationCreate(
            repoPath: "/tmp", workspaceId: nil, agent: "claude", prompt: "hi", intervalMinutes: 0
        )
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    func testKouenAutomationRunNowBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.automationRunNow(id: UUID().uuidString)
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    /// M2: List is read-only (never gated), Create/Update/Delete/Reorder mutate the rule
    /// list and must be gated like sendPaneText/kouenAutomationCreate.
    func testRoutingRuleToolsAreRegisteredWithCorrectGating() async {
        let missingPolicyURL = temporaryDirectory().appendingPathComponent("missing-policy.json")
        let policy = ToolPolicy.load(from: missingPolicyURL, environment: [:])
        XCTAssertTrue(policy.isToolAllowed("kouenRoutingRuleList"))
        XCTAssertFalse(policy.isToolAllowed("kouenRoutingRuleCreate"))
        XCTAssertFalse(policy.isToolAllowed("kouenRoutingRuleUpdate"))
        XCTAssertFalse(policy.isToolAllowed("kouenRoutingRuleDelete"))
        XCTAssertFalse(policy.isToolAllowed("kouenRoutingRuleReorder"))

        let registry = ToolRegistry(policy: { policy })
        guard case let .object(root) = registry.listTools(),
              case let .array(tools) = root["tools"]
        else {
            XCTFail("Expected listTools() to return { tools: [...] }")
            return
        }
        let names: Set<String> = Set(tools.compactMap {
            guard case let .object(tool) = $0, case let .string(name) = tool["name"] else { return nil }
            return name
        })
        for expected in [
            "kouenRoutingRuleList", "kouenRoutingRuleCreate", "kouenRoutingRuleUpdate",
            "kouenRoutingRuleDelete", "kouenRoutingRuleReorder",
        ] {
            XCTAssertTrue(names.contains(expected), "Expected \(expected) to be registered")
        }
    }

    func testKouenRoutingRuleUpdateRejectsInvalidUUID() async {
        let tools = KouenDaemonTools(controlEnabled: { true })
        let (result, error) = await tools.routingRuleUpdate(id: "not-a-uuid", pattern: nil, targetAgent: nil, enabled: nil)
        XCTAssertNil(result)
        XCTAssertEqual(error?.code, -32602)
    }

    func testKouenRoutingRuleCreateBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.routingRuleCreate(
            kind: "path", pattern: "/tmp/**", targetAgent: "codex", enabled: true
        )
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    func testKouenRoutingRuleReorderBlockedWhenGateClosed() async {
        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.routingRuleReorder(kind: "path", orderedIds: [UUID().uuidString])
        XCTAssertNil(result)
        XCTAssertEqual(error, KouenDaemonTools.controlDisabledError)
    }

    func testHostListReturnsConfiguredHosts() async throws {
        let previousHome = getenv("KOUEN_HOME").map { String(cString: $0) }
        let home = temporaryDirectory()
        setenv("KOUEN_HOME", home.path, 1)
        defer {
            if let previousHome { setenv("KOUEN_HOME", previousHome, 1) } else { unsetenv("KOUEN_HOME") }
        }
        try KouenPaths.ensureDirectories()
        RemoteHostStore().upsert(RemoteHost(name: "devbox", sshTarget: "rob@devbox", remoteSocketPath: "/home/rob/.local/share/kouen/kouen.sock"))

        let tools = KouenDaemonTools(controlEnabled: { false })
        let (result, error) = await tools.hostList()
        XCTAssertNil(error)
        guard case let .object(obj)? = result, case let .array(content)? = obj["content"],
              case let .object(first)? = content.first, case let .string(text)? = first["text"]
        else {
            XCTFail("Expected tool result content")
            return
        }
        XCTAssertTrue(text.contains("devbox"))
        XCTAssertTrue(text.contains("rob@devbox"))
    }

    func testPolicyExplicitDenyBlocksControlTools() async throws {
        let policyURL = try writePolicy(#"{ "version": 1, "allowControl": false, "allowedTools": [] }"#)
        let policy = ToolPolicy.load(from: policyURL, environment: [:])
        let registry = ToolRegistry(policy: { policy })

        let params: AnyCodable = .object([
            "name": .string("sendPaneText"),
            "arguments": .object([
                "surfaceId": .string("surface"),
                "text": .string("echo denied\n"),
            ]),
        ])
        let (result, error) = await registry.callTool(params: params)
        XCTAssertNil(result)
        XCTAssertEqual(error?.code, -32000)
        XCTAssertTrue(error?.message.contains("sendPaneText") == true)
        XCTAssertFalse(policy.isToolAllowed("writeFile"))
    }

    func testPolicyAllowsNamedToolOnly() async throws {
        let policyURL = try writePolicy(#"{ "version": 1, "allowControl": false, "allowedTools": ["writeFile"] }"#)
        let policy = ToolPolicy.load(from: policyURL, environment: [:])
        let registry = ToolRegistry(policy: { policy })
        let outputURL = temporaryDirectory().appendingPathComponent("policy-write.txt")

        let writeParams: AnyCodable = .object([
            "name": .string("writeFile"),
            "arguments": .object([
                "path": .string(outputURL.path),
                "content": .string("allowed"),
            ]),
        ])
        let (writeResult, writeError) = await registry.callTool(params: writeParams)
        XCTAssertNotNil(writeResult)
        XCTAssertNil(writeError)
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "allowed")

        let commandParams: AnyCodable = .object([
            "name": .string("runCommand"),
            "arguments": .object(["command": .string("echo denied")]),
        ])
        let (commandResult, commandError) = await registry.callTool(params: commandParams)
        XCTAssertNil(commandResult)
        XCTAssertEqual(commandError?.code, -32000)
        XCTAssertTrue(commandError?.message.contains("runCommand") == true)
    }

    func testUUIDParsingRunsAfterControlGate() async {
        let tools = KouenDaemonTools(controlEnabled: { true })

        let (_, spawnError) = await tools.spawnSession(workspaceId: "not-a-uuid", cwd: nil, name: nil, shell: nil)
        XCTAssertEqual(spawnError?.code, -32602)
        XCTAssertEqual(spawnError?.message, "Invalid 'workspaceId' UUID")

        let valid = UUID().uuidString
        let (_, splitTabError) = await tools.splitPane(tabId: "not-a-uuid", paneId: valid, direction: "right", shell: nil)
        XCTAssertEqual(splitTabError?.code, -32602)
        XCTAssertEqual(splitTabError?.message, "Invalid 'tabId' UUID")

        let (_, splitPaneError) = await tools.splitPane(tabId: valid, paneId: "not-a-uuid", direction: "right", shell: nil)
        XCTAssertEqual(splitPaneError?.code, -32602)
        XCTAssertEqual(splitPaneError?.message, "Invalid 'paneId' UUID")

        let (_, closeError) = await tools.closePane(paneId: "not-a-uuid")
        XCTAssertEqual(closeError?.code, -32602)
        XCTAssertEqual(closeError?.message, "Invalid 'paneId' UUID")
    }

    func testSplitPaneDirectionMappingUsesLayoutSemantics() {
        // P15 step 4: the direction-string mapping moved to `CommandIPCTranslator` so
        // `kouen.panes.split` (P11 PBI-SCRIPT-005) and this MCP tool agree on what
        // "right"/"left"/"up"/"down" mean.
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(forPaneDirection: "right"), .horizontal)
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(forPaneDirection: "left"), .horizontal)
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(forPaneDirection: "up"), .vertical)
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(forPaneDirection: "down"), .vertical)
        XCTAssertEqual(CommandIPCTranslator.layoutDirection(forPaneDirection: "RIGHT"), .horizontal)
        XCTAssertNil(CommandIPCTranslator.layoutDirection(forPaneDirection: "diagonal"))
    }

    /// Regression for the bug where `ToolRegistry.init(policy: ToolPolicy = ToolPolicy.load())`
    /// took a frozen *value*, loaded exactly once at construction, and captured it into the
    /// closures handed to `KouenDaemonTools`/`KouenBrowserTools` — so editing `mcp-policy.json`
    /// on disk had zero effect on an already-running `kouen-mcp` process until it was killed
    /// and relaunched (real-world symptom: `allowControl: true` written to disk, tool calls on
    /// the live process kept reporting disabled). `init(policy:)` now takes the *resolver*
    /// closure — this test injects one that re-reads a controllable temp file (mirroring
    /// production's default `{ ToolPolicy.load() }`), denies a control tool through the real
    /// `callTool` dispatch path, rewrites the file, and asserts the *same* registry instance
    /// allows it on the very next call with no new `ToolRegistry` constructed in between.
    func testToolRegistryReloadsPolicyFromDiskOnEveryCall() async throws {
        let policyURL = try writePolicy(#"{ "version": 1, "allowControl": false, "allowedTools": [] }"#)
        let registry = ToolRegistry(policy: { ToolPolicy.load(from: policyURL, environment: [:]) })
        let outputURL = temporaryDirectory().appendingPathComponent("reload-live.txt")

        let params: AnyCodable = .object([
            "name": .string("writeFile"),
            "arguments": .object([
                "path": .string(outputURL.path),
                "content": .string("after reload"),
            ]),
        ])
        let (deniedResult, deniedError) = await registry.callTool(params: params)
        XCTAssertNil(deniedResult)
        XCTAssertEqual(deniedError?.code, -32000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))

        // Rewrite the same file to now allow it — no new ToolRegistry constructed.
        try #"{ "version": 1, "allowControl": true, "allowedTools": [] }"#
            .write(to: policyURL, atomically: true, encoding: .utf8)

        let (allowedResult, allowedError) = await registry.callTool(params: params)
        XCTAssertNil(allowedError, "ToolRegistry must re-resolve the policy on every call, not cache the value from construction time")
        XCTAssertNotNil(allowedResult)
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), "after reload")
    }

    func testToolRegistryRejectsNonStringKeys() async {
        let registry = ToolRegistry()
        let params: AnyCodable = .object([
            "name": .string("sendPaneKeys"),
            "arguments": .object([
                "surfaceId": .string("surface"),
                "keys": .array([.string("Enter"), .int(1)]),
            ]),
        ])
        let (result, error) = await registry.callTool(params: params)
        XCTAssertNil(result)
        XCTAssertEqual(error?.code, -32602)
        XCTAssertEqual(error?.message, "'keys' must be an array of strings")
    }

    private func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KouenMCPTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func writePolicy(_ json: String) throws -> URL {
        let url = temporaryDirectory().appendingPathComponent("mcp-policy.json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
