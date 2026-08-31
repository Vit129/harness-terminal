import Foundation
import KouenCore

/// Registry of MCP tools exposed to agents.
///
/// Policy is re-resolved on every check rather than loaded once at construction —
/// `mcp-policy.json` (or `KOUEN_MCP_ALLOW_CONTROL`) can change at any time while a
/// daemon/mcp process keeps running for hours, and a stale in-memory snapshot would
/// silently ignore that change until the process was killed and relaunched.
///
/// `init(policy:)` takes the resolver itself (defaulting to a fresh `ToolPolicy.load()`
/// per call) rather than a frozen `ToolPolicy` value — that's what makes the reload-on-
/// every-check behavior real instead of just theoretically possible. Tests can pass a
/// closure that always returns the same fixed policy for determinism, or one that reads
/// a controllable temp file to assert live-reload behavior end-to-end.
struct ToolRegistry: Sendable {
    private let resolvePolicy: @Sendable () -> ToolPolicy
    private let daemonTools: KouenDaemonTools
    private let browserTools: KouenBrowserTools

    init(policy resolvePolicy: @escaping @Sendable () -> ToolPolicy = { ToolPolicy.load() }) {
        self.resolvePolicy = resolvePolicy
        self.daemonTools = KouenDaemonTools(
            isToolAllowed: { resolvePolicy().isToolAllowed($0) },
            disabledError: { resolvePolicy().disabledError(for: $0) }
        )
        self.browserTools = KouenBrowserTools(
            isToolAllowed: { resolvePolicy().isToolAllowed($0) },
            disabledError: { resolvePolicy().disabledError(for: $0) }
        )
    }

    func listTools() -> AnyCodable {
        .object(["tools": .array([
            toolDef("kouenList", "List Kouen workspaces, sessions, tabs, and panes (call first to find existing browser panes before opening new ones)", [
                param("includePanes", "boolean", "Include per-tab pane details (optional, default true)"),
                param("includeAgents", "boolean", "Include detected agent info per tab (optional, default true)"),
            ]),
            toolDef("kouenBoard", "Kanban-style board of Kouen sessions grouped by status (Needs Attention/Running/Idle/Done/Error)", []),
            toolDef("openDiffReview", "Open the Git diff panel in the Kouen sidebar (switches sidebar to Git tab)", [
                param("repoPath", "string", "Repository path to show diffs for (optional)"),
            ]),
            toolDef("readPaneOutput", "Read recent output from a Kouen pane", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("lines", "number", "Number of lines to read from the bottom (optional, default 200, max 2000)"),
                param("escapeSequences", "boolean", "Return raw output including escape sequences (optional)"),
                param("joinWrapped", "boolean", "Join soft-wrapped lines into their logical line (optional)"),
            ]),
            toolDef("kouenGetLastBlock", "Get the most recently finished command block on a pane (exact command, output, exit code) — precise, unlike readPaneOutput's line-count tail. Requires the pane's shell to emit OSC 133 C (zsh/fish; not bash yet)", [
                param("surfaceId", "string", "Surface id from kouenList"),
            ]),
            toolDef("kouenGetBlock", "Get a specific command block by id (from a prior kouenGetLastBlock/kouenGetBlock response) on a pane", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("blockId", "number", "Block id to fetch"),
            ]),
            toolDef("setPaneLabel", "Set (or clear) a durable purpose label on a pane — e.g. \"build\", \"claude\" — so it can be told apart from sibling panes in the same tab via kouenList's paneJSON. Distinct from title: never overwritten by shell/OSC output. Requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("label", "string", "Label text; omit or send empty string to clear"),
            ]),
            toolDef("sendPaneText", "Send text to a Kouen pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("text", "string", "Text to send"),
                param("bracketed", "boolean", "Whether text was requested as bracketed paste (optional, currently sent as text)"),
            ]),
            toolDef("sendPaneKeys", "Send key tokens to a Kouen pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("keys", "array", "Key tokens to send"),
            ]),
            toolDef("spawnSession", "Create a new Kouen session (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("workspaceId", "string", "Workspace UUID"),
                param("cwd", "string", "Working directory (optional)"),
                param("name", "string", "Session name (optional)"),
                param("shell", "string", "Shell path (optional)"),
                param("label", "string", "Purpose label for the new pane, set atomically (optional) — e.g. \"build\". Same as calling setPaneLabel right after, without the extra round-trip"),
            ]),
            toolDef("splitPane", "Split an existing Kouen pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("tabId", "string", "Tab UUID"),
                param("paneId", "string", "Pane UUID"),
                param("direction", "string", "Split direction: right, left, up, or down"),
                param("shell", "string", "Shell path (optional)"),
                param("label", "string", "Purpose label for the new pane, set atomically (optional) — e.g. \"build\". Same as calling setPaneLabel right after, without the extra round-trip"),
            ]),
            toolDef("closePane", "Close a Kouen pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Pane UUID"),
            ]),
            toolDef("waitForPaneOutput", "Wait until a Kouen pane emits a target string", [
                param("surfaceId", "string", "Surface id from kouenList"),
                param("pattern", "string", "Target string to match"),
                param("timeoutMs", "number", "Timeout in milliseconds (optional, default 30000)"),
                param("fromNow", "boolean", "Ignore existing scrollback when true (optional, default true)"),
            ]),
            toolDef("readFile", "Read the contents of a file", [
                param("path", "string", "Absolute path to the file"),
            ]),
            toolDef("writeFile", "Write content to a file", [
                param("path", "string", "Absolute path to the file"),
                param("content", "string", "Content to write"),
            ]),
            toolDef("listDirectory", "List files and directories at a path", [
                param("path", "string", "Absolute path to the directory"),
            ]),
            toolDef("runCommand", "Run a shell command and return output", [
                param("command", "string", "The command to execute"),
                param("cwd", "string", "Working directory (optional)"),
            ]),
            toolDef("gitStatus", "Get git status for a repository", [
                param("path", "string", "Path to the git repository"),
            ]),
            toolDef("gitDiff", "Get git diff for a repository", [
                param("path", "string", "Path to the git repository"),
                param("staged", "boolean", "Show staged changes only (optional)"),
            ]),
            toolDef("gitLog", "Get recent git commits", [
                param("path", "string", "Path to the git repository"),
                param("count", "number", "Number of commits (default 10)"),
            ]),
            toolDef("kouenPRStatus", "Get PR/CI status (checks, mergeable, review decision) for the current branch's PR in a repository — for an Orchestrator polling a Worker's progress (P44a)", [
                param("path", "string", "Path to the git repository (or worktree)"),
            ]),
            toolDef("kouenBrowserOpen", "Open a new browser pane. Check kouenList first to reuse existing panes (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("url", "string", "URL to load"),
                param("direction", "string", "Split direction: right, left, up, or down (optional)"),
            ]),
            toolDef("kouenBrowserNavigate", "Navigate an existing browser pane (preferred when panes already exist; get paneId from kouenList) (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
                param("url", "string", "URL to load"),
            ]),
            toolDef("kouenBrowserWait", "Wait for a browser pane to finish loading (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
                param("timeoutSeconds", "number", "Timeout in seconds (optional, default 30)"),
            ]),
            toolDef("kouenBrowserSnapshot", "Take a DOM snapshot and list interactive elements from a browser pane", [
                param("paneId", "string", "Browser pane UUID"),
                param("interactive", "boolean", "Include interactive elements only (optional)"),
            ]),
            toolDef("kouenBrowserInteract", "Interact (click, type, or scroll) with an element in a browser pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
                param("action", "string", "Interaction action: 'click', 'type', or 'scroll'"),
                param("elementId", "string", "Element ID from snapshot (e.g. 'e1')"),
                param("text", "string", "Text to type (optional, required if action is 'type')"),
            ]),
            toolDef("kouenBrowserClose", "Close an existing browser pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserScreenshot", "Take a screenshot of a browser pane and return base64 PNG", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserNetwork", "Get captured network requests (fetch/XHR) from a browser pane", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserCookies", "Get cookies from a browser pane", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserStorage", "Get localStorage or sessionStorage from a browser pane", [
                param("paneId", "string", "Browser pane UUID"),
                param("storageType", "string", "Storage type: 'local' or 'session'"),
            ]),
            toolDef("kouenBrowserEvaluate", "Evaluate a JavaScript expression in a browser pane and return the result (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
                param("script", "string", "JavaScript code to evaluate. Must return a JSON-serializable value or string."),
            ]),
            toolDef("kouenBrowserGoBack", "Navigate the browser pane back in history (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserGoForward", "Navigate the browser pane forward in history (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenBrowserReload", "Reload the current page in a browser pane (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("paneId", "string", "Browser pane UUID"),
            ]),
            toolDef("kouenFind", "Fuzzy search for files in the active session's working directory", [
                param("query", "string", "Query to filter files (optional)"),
            ]),
            toolDef("kouenGrep", "Search for regex matches in the active session's workspace", [
                param("query", "string", "Pattern to search for"),
                param("path", "string", "Directory path to search, relative or absolute (optional, default '.')"),
            ]),
            toolDef("kouenRecent", "List recently opened files in the workspace", []),
            toolDef("kouenErrors", "Get diagnostics/compile errors in the active session's workspace or a specific file", [
                param("path", "string", "Path to file to query diagnostics for (optional)"),
            ]),
            toolDef("kouenSpawnAgent", "Spawn a new Kouen terminal session and immediately launch an AI agent CLI (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("agent", "string", "Agent to launch: 'claude', 'codex', 'kiro', 'gemini', or 'cursor'"),
                param("workspaceId", "string", "Workspace UUID (optional, uses active workspace if omitted)"),
                param("cwd", "string", "Working directory for the new session (optional)"),
                param("worktreePath", "string", "Attach the new session's first tab to this git worktree path (optional) — makes it visible via kouenList's tabJSON"),
                param("parentRepoPath", "string", "The worktree's parent repo path (optional, paired with worktreePath)"),
                param("taskName", "string", "Display-name override for the tab, e.g. the Task title it's working on (optional)"),
            ]),
            toolDef("kouenSpawnWorker", "Spawn a Worker session, launch its agent CLI, and hand it a prompt in one atomic call — for an Orchestrator delegating a Task (P44a). Reliable alternative to kouenSpawnAgent + a manual follow-up send: polls for the shell to actually be ready before typing anything. 'cursor' is not supported (GUI launcher, not an interactive agent — use kouenSpawnAgent for it instead). Requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1", [
                param("agent", "string", "Agent to launch: 'claude', 'codex', 'kiro', or 'gemini' ('cursor' not supported here — see tool description)"),
                param("workspaceId", "string", "Workspace UUID (optional, uses active workspace if omitted)"),
                param("cwd", "string", "Working directory for the new session (optional)"),
                param("worktreePath", "string", "Attach the new session's first tab to this git worktree path (optional)"),
                param("parentRepoPath", "string", "The worktree's parent repo path (optional, paired with worktreePath)"),
                param("taskName", "string", "Display-name override for the tab, e.g. the Task title it's working on (optional)"),
                param("prompt", "string", "The prompt to type into the agent once it's ready"),
            ]),
            toolDef("kouenTaskList", "List Tasks — checklist items scoped to a session. Omit sessionId to list across every session (powers the Task Dashboard)", [
                param("sessionId", "string", "Session UUID to filter by (optional, omit for all sessions)"),
            ]),
            toolDef("kouenTaskGet", "Get a single Task by id", [
                param("id", "string", "Task UUID"),
            ]),
            toolDef("kouenTaskCreate", "Create a Task belonging to a session", [
                param("sessionId", "string", "Session UUID this Task belongs to"),
                param("title", "string", "Task title"),
            ]),
            toolDef("kouenTaskUpdate", "Update a Task's title, done state, and/or status", [
                param("id", "string", "Task UUID"),
                param("title", "string", "New title (optional)"),
                param("done", "boolean", "New done state (optional)"),
                param(
                    "status", "string",
                    "New status (optional): open, running, ciFailing, mergeReady, or done. Overrides 'done' if both are given."
                ),
            ]),
            toolDef("kouenTaskDelete", "Delete a Task", [
                param("id", "string", "Task UUID"),
            ]),
            toolDef("kouenWorktreeList", "List git worktrees for a repository (Kouen's worktree-per-branch-per-agent isolation)", [
                param("repoPath", "string", "Repository root path (contains .git)"),
            ]),
            toolDef("kouenWorktreeCreate", "Create an isolated git worktree for a repository (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("repoPath", "string", "Repository root path (contains .git)"),
                param("sessionId", "string", "Identifier used as the worktree folder name"),
                param("branch", "string", "Branch name to create/checkout (optional, detached HEAD if omitted)"),
                param("baseRef", "string", "Ref to branch from, e.g. 'origin/main' (optional, defaults to HEAD)"),
            ]),
            toolDef("kouenWorktreeRemove", "Remove a git worktree (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("repoPath", "string", "Repository root path (contains .git)"),
                param("worktreePath", "string", "Path to the worktree to remove"),
                param("force", "boolean", "Discard uncommitted changes in the worktree (optional, default false — never silently discards work)"),
            ]),
            toolDef("kouenHostList", "List configured remote hosts (Settings > Remote) reachable by SSH. Read-only — creating/editing a host stays a Settings-UI-only action", []),
            toolDef("kouenProjectsList", "List distinct git repo roots across every currently-open tab (name + path). Read-only, no registration step — reflects what's actually open, not a separately-maintained project list", []),
            toolDef("kouenAutomationList", "List Automations — scheduled agent launches", []),
            toolDef("kouenAutomationGet", "Get a single Automation by id", [
                param("id", "string", "Automation UUID"),
            ]),
            toolDef("kouenAutomationCreate", "Create an Automation. On fire, spawns a session in repoPath, launches agent, then types prompt (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("repoPath", "string", "Working directory to spawn the session in"),
                param("agent", "string", "Agent to launch: 'claude', 'codex', 'kiro', or 'gemini'"),
                param("prompt", "string", "Text typed into the agent after launch — e.g. \"ทำต่อ agent-memory/plans/p40.../dev-task-progress.md\" to resume a specific plan via this project's own continuation convention"),
                param("intervalMinutes", "number", "Minutes between auto-fires. 0 disables auto-fire (manual/run-now only)"),
                param("workspaceId", "string", "Workspace UUID to spawn in (optional, uses first workspace if omitted)"),
            ]),
            toolDef("kouenAutomationUpdate", "Update an Automation's repoPath/agent/prompt/intervalMinutes (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Automation UUID"),
                param("repoPath", "string", "New working directory (optional)"),
                param("agent", "string", "New agent (optional)"),
                param("prompt", "string", "New prompt text (optional)"),
                param("intervalMinutes", "number", "New auto-fire interval in minutes (optional)"),
            ]),
            toolDef("kouenAutomationDelete", "Delete an Automation (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Automation UUID"),
            ]),
            toolDef("kouenAutomationPause", "Pause an Automation's auto-fire schedule (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Automation UUID"),
            ]),
            toolDef("kouenAutomationResume", "Resume a paused Automation's auto-fire schedule (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Automation UUID"),
            ]),
            toolDef("kouenAutomationRunNow", "Fire an Automation immediately, bypassing its schedule and enabled state (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Automation UUID"),
            ]),
            toolDef("kouenRoutingRuleList", "List Agent Routing Rules — resolve agent:\"auto\" to a concrete AgentKind at spawn time (kouenSpawnAgent, Automations)", []),
            toolDef("kouenRoutingRuleCreate", "Create an Agent Routing Rule (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("kind", "string", "'path' (repo-path glob, checked first) or 'stack' (SignalFileRouter-detected stack name, checked only if no path rule matches)"),
                param("pattern", "string", "Glob pattern (kind=path, e.g. '~/Git/Company/**') or stack name (kind=stack, e.g. 'swift', 'node', 'python')"),
                param("targetAgent", "string", "AgentKind to route to: 'claude-code', 'codex', 'gemini', 'kiro', etc."),
                param("enabled", "boolean", "Whether this rule is active (optional, default true)"),
            ]),
            toolDef("kouenRoutingRuleUpdate", "Update an Agent Routing Rule's pattern/targetAgent/enabled (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Rule UUID"),
                param("pattern", "string", "New pattern (optional)"),
                param("targetAgent", "string", "New target AgentKind (optional)"),
                param("enabled", "boolean", "New enabled state (optional)"),
            ]),
            toolDef("kouenRoutingRuleDelete", "Delete an Agent Routing Rule (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("id", "string", "Rule UUID"),
            ]),
            toolDef("kouenRoutingRuleReorder", "Reorder Agent Routing Rules within one kind (path or stack) — first match wins by this order (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("kind", "string", "'path' or 'stack' — the group being reordered"),
                param("orderedIds", "array", "Rule UUIDs of this kind, in the desired priority order"),
            ]),
            toolDef("kouenCCRun", "Run Claude Code headlessly as a subprocess (not a visible pane) — one-shot prompt in, structured result out. Use for automations/analysis where nothing needs to watch it run; use kouenSpawnAgent instead for an interactive session a human will steer. Requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1", [
                param("prompt", "string", "Prompt to run"),
                param("cwd", "string", "Working directory"),
                param("profile", "string", "'readonly' (Read/Glob/Grep only, no writes) or 'edit' (Edit/Write + git-readonly Bash, rm/sudo/git-push denied). Optional, default 'edit'"),
                param("model", "string", "Model alias ('sonnet'/'opus'/'fable'/'haiku') or full name (optional, default: unset — inherits the user's own Claude Code config)"),
                param("effort", "string", "Reasoning effort: 'low'/'medium'/'high'/'xhigh'/'max' (optional, default: unset — inherits the user's own Claude Code config)"),
            ]),
            toolDef("kouenCCStatus", "Get/list/cancel kouenCCRun runs (requires MCP policy allowlist or KOUEN_MCP_ALLOW_CONTROL=1)", [
                param("action", "string", "'get' (default), 'list', or 'cancel'"),
                param("runId", "string", "Run id from kouenCCRun (required for 'get'/'cancel', optional for 'list')"),
            ]),
        ])])
    }

    func callTool(params: AnyCodable?) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .object(obj)? = params,
              case let .string(name)? = obj["name"],
              let arguments = obj["arguments"]
        else {
            return (nil, JSONRPCError(code: -32602, message: "Invalid params: expected {name, arguments}"))
        }
        let args: [String: AnyCodable]
        if case let .object(a) = arguments { args = a } else { args = [:] }

        switch name {
        case "kouenList": return await kouenList(args)
        case "kouenBoard": return await daemonTools.kouenBoard()
        case "openDiffReview": return await daemonTools.openDiffReview(args)
        case "readPaneOutput": return await readPaneOutput(args)
        case "kouenGetLastBlock": return await kouenGetBlock(args, requireBlockId: false)
        case "kouenGetBlock": return await kouenGetBlock(args, requireBlockId: true)
        case "setPaneLabel": return await setPaneLabel(args)
        case "sendPaneText": return await sendPaneText(args)
        case "sendPaneKeys": return await sendPaneKeys(args)
        case "spawnSession": return await spawnSession(args)
        case "splitPane": return await splitPane(args)
        case "closePane": return await closePane(args)
        case "waitForPaneOutput": return await waitForPaneOutput(args)
        case "readFile": return await readFile(args)
        case "writeFile": return await writeFile(args)
        case "listDirectory": return await listDirectory(args)
        case "runCommand": return await runCommand(args)
        case "gitStatus": return await gitStatus(args)
        case "gitDiff": return await gitDiff(args)
        case "gitLog": return await gitLog(args)
        case "kouenPRStatus": return await kouenPRStatus(args)
        case "kouenFind": return await kouenFind(args)
        case "kouenGrep": return await kouenGrep(args)
        case "kouenRecent": return await kouenRecent(args)
        case "kouenErrors": return await kouenErrors(args)
        case "kouenBrowserOpen": return await kouenBrowserOpen(args)
        case "kouenBrowserNavigate": return await kouenBrowserNavigate(args)
        case "kouenBrowserWait": return await kouenBrowserWait(args)
        case "kouenBrowserSnapshot": return await kouenBrowserSnapshot(args)
        case "kouenBrowserInteract": return await kouenBrowserInteract(args)
        case "kouenBrowserClose": return await kouenBrowserClose(args)
        case "kouenBrowserScreenshot": return await kouenBrowserScreenshot(args)
        case "kouenBrowserNetwork": return await kouenBrowserNetwork(args)
        case "kouenBrowserCookies": return await kouenBrowserCookies(args)
        case "kouenBrowserStorage": return await kouenBrowserStorage(args)
        case "kouenBrowserEvaluate": return await kouenBrowserEvaluate(args)
        case "kouenBrowserGoBack": return await kouenBrowserGoBack(args)
        case "kouenBrowserGoForward": return await kouenBrowserGoForward(args)
        case "kouenBrowserReload": return await kouenBrowserReload(args)
        case "kouenSpawnAgent": return await kouenSpawnAgent(args)
        case "kouenSpawnWorker": return await kouenSpawnWorker(args)
        case "kouenTaskList": return await kouenTaskList(args)
        case "kouenTaskGet": return await kouenTaskGet(args)
        case "kouenTaskCreate": return await kouenTaskCreate(args)
        case "kouenTaskUpdate": return await kouenTaskUpdate(args)
        case "kouenTaskDelete": return await kouenTaskDelete(args)
        case "kouenWorktreeList": return await kouenWorktreeList(args)
        case "kouenWorktreeCreate": return await kouenWorktreeCreate(args)
        case "kouenWorktreeRemove": return await kouenWorktreeRemove(args)
        case "kouenHostList": return await daemonTools.hostList()
        case "kouenProjectsList": return await daemonTools.projectsList()
        case "kouenAutomationList": return await daemonTools.automationList()
        case "kouenAutomationGet": return await kouenAutomationGet(args)
        case "kouenAutomationCreate": return await kouenAutomationCreate(args)
        case "kouenAutomationUpdate": return await kouenAutomationUpdate(args)
        case "kouenAutomationDelete": return await kouenAutomationDelete(args)
        case "kouenAutomationPause": return await kouenAutomationPause(args)
        case "kouenAutomationResume": return await kouenAutomationResume(args)
        case "kouenAutomationRunNow": return await kouenAutomationRunNow(args)
        case "kouenRoutingRuleList": return await daemonTools.routingRuleList()
        case "kouenRoutingRuleCreate": return await kouenRoutingRuleCreate(args)
        case "kouenRoutingRuleUpdate": return await kouenRoutingRuleUpdate(args)
        case "kouenRoutingRuleDelete": return await kouenRoutingRuleDelete(args)
        case "kouenRoutingRuleReorder": return await kouenRoutingRuleReorder(args)
        case "kouenCCRun": return await kouenCCRun(args)
        case "kouenCCStatus": return await kouenCCStatus(args)
        default:
            return (nil, JSONRPCError(code: -32602, message: "Unknown tool: \(name)"))
        }
    }

    // MARK: - File tools

    private func readFile(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return (nil, JSONRPCError(code: -32000, message: "Cannot read file: \(path)"))
        }
        return (toolResult(content), nil)
    }

    private func writeFile(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard resolvePolicy().isToolAllowed("writeFile") else {
            return (nil, resolvePolicy().disabledError(for: "writeFile"))
        }
        guard case let .string(path)? = args["path"],
              case let .string(content)? = args["content"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' or 'content' parameter"))
        }
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return (toolResult("Written \(content.count) bytes to \(path)"), nil)
        } catch {
            return (nil, JSONRPCError(code: -32000, message: "Write failed: \(error.localizedDescription)"))
        }
    }

    private func listDirectory(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return (nil, JSONRPCError(code: -32000, message: "Cannot list directory: \(path)"))
        }
        let listing = entries.sorted().joined(separator: "\n")
        return (toolResult(listing), nil)
    }

    // MARK: - Kouen daemon tools

    private func kouenList(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        let includePanes = boolArg(args["includePanes"], default: true)
        let includeAgents = boolArg(args["includeAgents"], default: true)
        return await daemonTools.kouenList(includePanes: includePanes, includeAgents: includeAgents)
    }

    private func readPaneOutput(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' parameter"))
        }
        let lines: Int?
        if case let .int(n)? = args["lines"] { lines = n } else { lines = nil }
        let escapeSequences = boolArg(args["escapeSequences"], default: false)
        let joinWrapped = boolArg(args["joinWrapped"], default: false)
        return await daemonTools.readPaneOutput(
            surfaceId: surfaceId,
            lines: lines,
            escapeSequences: escapeSequences,
            joinWrapped: joinWrapped
        )
    }

    private func kouenGetBlock(_ args: [String: AnyCodable], requireBlockId: Bool) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' parameter"))
        }
        var blockId: Int?
        if case let .int(n)? = args["blockId"] { blockId = n }
        if requireBlockId, blockId == nil {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'blockId' parameter"))
        }
        return await daemonTools.getBlock(surfaceId: surfaceId, blockId: blockId)
    }

    // MARK: - Task tools

    private func kouenTaskList(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        await daemonTools.taskList(sessionId: optionalStringArg(args["sessionId"]))
    }

    private func kouenTaskGet(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.taskGet(id: id)
    }

    private func kouenTaskCreate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(sessionId)? = args["sessionId"],
              case let .string(title)? = args["title"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'sessionId' or 'title' parameter"))
        }
        return await daemonTools.taskCreate(sessionId: sessionId, title: title)
    }

    private func kouenTaskUpdate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        let done: Bool?
        if case let .bool(d)? = args["done"] { done = d } else { done = nil }
        return await daemonTools.taskUpdate(
            id: id, title: optionalStringArg(args["title"]), done: done,
            status: optionalStringArg(args["status"])
        )
    }

    private func kouenTaskDelete(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.taskDelete(id: id)
    }

    // MARK: - Worktree tools

    private func kouenWorktreeList(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(repoPath)? = args["repoPath"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'repoPath' parameter"))
        }
        return await daemonTools.worktreeList(repoPath: repoPath)
    }

    private func kouenWorktreeCreate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(repoPath)? = args["repoPath"],
              case let .string(sessionId)? = args["sessionId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'repoPath' or 'sessionId' parameter"))
        }
        return await daemonTools.worktreeCreate(
            repoPath: repoPath,
            sessionID: sessionId,
            branch: optionalStringArg(args["branch"]),
            baseRef: optionalStringArg(args["baseRef"])
        )
    }

    private func kouenWorktreeRemove(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(repoPath)? = args["repoPath"],
              case let .string(worktreePath)? = args["worktreePath"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'repoPath' or 'worktreePath' parameter"))
        }
        let force = boolArg(args["force"], default: false)
        return await daemonTools.worktreeRemove(repoPath: repoPath, worktreePath: worktreePath, force: force)
    }

    // MARK: - Automation tools

    private func kouenAutomationGet(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.automationGet(id: id)
    }

    private func kouenAutomationCreate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(repoPath)? = args["repoPath"],
              case let .string(agent)? = args["agent"],
              case let .string(prompt)? = args["prompt"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'repoPath', 'agent', or 'prompt' parameter"))
        }
        let intervalMinutes = intArg(args["intervalMinutes"], default: 0)
        return await daemonTools.automationCreate(
            repoPath: repoPath, workspaceId: optionalStringArg(args["workspaceId"]),
            agent: agent, prompt: prompt, intervalMinutes: intervalMinutes
        )
    }

    private func kouenAutomationUpdate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        var intervalMinutes: Int?
        if case let .int(i)? = args["intervalMinutes"] { intervalMinutes = i }
        return await daemonTools.automationUpdate(
            id: id, repoPath: optionalStringArg(args["repoPath"]), agent: optionalStringArg(args["agent"]),
            prompt: optionalStringArg(args["prompt"]), intervalMinutes: intervalMinutes
        )
    }

    private func kouenAutomationDelete(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.automationDelete(id: id)
    }

    private func kouenAutomationPause(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.automationPause(id: id)
    }

    private func kouenAutomationResume(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.automationResume(id: id)
    }

    private func kouenAutomationRunNow(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.automationRunNow(id: id)
    }

    // MARK: - Agent Routing Rule tools

    private func kouenRoutingRuleCreate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(kind)? = args["kind"],
              case let .string(pattern)? = args["pattern"],
              case let .string(targetAgent)? = args["targetAgent"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'kind', 'pattern', or 'targetAgent' parameter"))
        }
        let enabled = boolArg(args["enabled"], default: true)
        return await daemonTools.routingRuleCreate(kind: kind, pattern: pattern, targetAgent: targetAgent, enabled: enabled)
    }

    private func kouenRoutingRuleUpdate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        var enabled: Bool?
        if case let .bool(e)? = args["enabled"] { enabled = e }
        return await daemonTools.routingRuleUpdate(
            id: id, pattern: optionalStringArg(args["pattern"]), targetAgent: optionalStringArg(args["targetAgent"]),
            enabled: enabled
        )
    }

    private func kouenRoutingRuleDelete(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(id)? = args["id"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'id' parameter"))
        }
        return await daemonTools.routingRuleDelete(id: id)
    }

    private func kouenRoutingRuleReorder(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(kind)? = args["kind"],
              case let .array(orderedIdsValue)? = args["orderedIds"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'kind' or 'orderedIds' parameter"))
        }
        let orderedIds = orderedIdsValue.compactMap { value -> String? in
            if case let .string(id) = value { return id }
            return nil
        }
        guard orderedIds.count == orderedIdsValue.count else {
            return (nil, JSONRPCError(code: -32602, message: "'orderedIds' must be an array of strings"))
        }
        return await daemonTools.routingRuleReorder(kind: kind, orderedIds: orderedIds)
    }

    private func setPaneLabel(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' parameter"))
        }
        var label: String?
        if case let .string(l)? = args["label"] { label = l }
        return await daemonTools.setPaneLabel(surfaceId: surfaceId, label: label)
    }

    private func sendPaneText(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .string(text)? = args["text"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'text' parameter"))
        }
        let bracketed = boolArg(args["bracketed"], default: false)
        return await daemonTools.sendPaneText(surfaceId: surfaceId, text: text, bracketed: bracketed)
    }

    private func sendPaneKeys(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .array(keysValue)? = args["keys"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'keys' parameter"))
        }
        let keys = keysValue.compactMap { value -> String? in
            if case let .string(key) = value { return key }
            return nil
        }
        guard keys.count == keysValue.count else {
            return (nil, JSONRPCError(code: -32602, message: "'keys' must be an array of strings"))
        }
        return await daemonTools.sendPaneKeys(surfaceId: surfaceId, keys: keys)
    }

    private func spawnSession(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(workspaceId)? = args["workspaceId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'workspaceId' parameter"))
        }
        return await daemonTools.spawnSession(
            workspaceId: workspaceId,
            cwd: optionalStringArg(args["cwd"]),
            name: optionalStringArg(args["name"]),
            shell: optionalStringArg(args["shell"]),
            label: optionalStringArg(args["label"])
        )
    }

    private func splitPane(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(tabId)? = args["tabId"],
              case let .string(paneId)? = args["paneId"],
              case let .string(direction)? = args["direction"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'tabId', 'paneId', or 'direction' parameter"))
        }
        return await daemonTools.splitPane(
            tabId: tabId,
            paneId: paneId,
            direction: direction,
            shell: optionalStringArg(args["shell"]),
            label: optionalStringArg(args["label"])
        )
    }

    private func closePane(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await daemonTools.closePane(paneId: paneId)
    }

    private func waitForPaneOutput(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(surfaceId)? = args["surfaceId"],
              case let .string(pattern)? = args["pattern"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'surfaceId' or 'pattern' parameter"))
        }
        let timeoutMs: Int?
        if case let .int(n)? = args["timeoutMs"] { timeoutMs = n } else { timeoutMs = nil }
        let fromNow = boolArg(args["fromNow"], default: true)
        return await daemonTools.waitForPaneOutput(
            surfaceId: surfaceId,
            pattern: pattern,
            timeoutMs: timeoutMs,
            fromNow: fromNow
        )
    }

    // MARK: - Terminal tools

    private func runCommand(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard resolvePolicy().isToolAllowed("runCommand") else {
            return (nil, resolvePolicy().disabledError(for: "runCommand"))
        }
        guard case let .string(command)? = args["command"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'command' parameter"))
        }
        let cwd: String?
        if case let .string(c)? = args["cwd"] { cwd = c } else { cwd = nil }

        let (stdout, stderr, code) = await shell(command, cwd: cwd)
        return (.object([
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(code == 0 ? stdout : "exit \(code)\n\(stderr)\n\(stdout)"),
            ])]),
        ]), nil)
    }

    // MARK: - Git tools

    private func gitStatus(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let (out, _, _) = await shell("git status --short", cwd: path)
        return (toolResult(out.isEmpty ? "Working tree clean" : out), nil)
    }

    private func gitDiff(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let staged = args["staged"] == .bool(true)
        let cmd = staged ? "git diff --cached" : "git diff"
        let (out, _, _) = await shell(cmd, cwd: path)
        return (toolResult(out.isEmpty ? "No changes" : out), nil)
    }

    private func gitLog(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let count: Int
        if case let .int(n)? = args["count"] { count = n } else { count = 10 }
        let (out, _, _) = await shell("git log --oneline -\(count)", cwd: path)
        return (toolResult(out.isEmpty ? "No commits" : out), nil)
    }

    /// Direct in-process `gh` shell-out via `GitHubCLIClient`, no daemon round-trip —
    /// same pattern as `gitStatus`/`gitDiff`/`gitLog` above. Offloaded to a background
    /// queue (`GitHubCLIClient.prForCurrentBranch` blocks on `Process.waitUntilExit()`)
    /// so it never stalls the calling Task, mirroring `shell()`'s own continuation shape.
    private func kouenPRStatus(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(path)? = args["path"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'path' parameter"))
        }
        let info: GitHubCLIClient.PRInfo? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: GitHubCLIClient().prForCurrentBranch(repoPath: path))
            }
        }
        guard let info else {
            return (toolResult("No PR found for the current branch (or gh unavailable/unauthenticated)"), nil)
        }
        return (toolResult(json: .object([
            "number": .int(info.number),
            "title": .string(info.title),
            "state": .string(info.state.rawValue),
            "url": .string(info.url),
            "headRefName": .string(info.headRefName),
            "baseRefName": .string(info.baseRefName),
            "isDraft": .bool(info.isDraft),
            "checksStatus": .string(info.checksStatus.rawValue),
            "mergeable": .bool(info.mergeable),
            "reviewDecision": info.reviewDecision.map(AnyCodable.string) ?? .null,
        ])), nil)
    }

    private func kouenFind(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard let cwd = await daemonTools.getActiveCWD() else {
            return (nil, JSONRPCError(code: -32000, message: "No active workspace or session found"))
        }
        let query = optionalStringArg(args["query"]) ?? ""
        let findCmd = "find . \\( -path '*/.git/*' -o -path '*/.build/*' -o -path '*/node_modules/*' -o -path '*/DerivedData/*' \\) -prune -o -type f -print"
        let cmd = query.isEmpty
            ? "\(findCmd) | sed 's#^./##' | head -200"
            : "\(findCmd) | sed 's#^./##' | grep -i -- \(ShellQuoting.quote(query)) | head -200"
        let (out, err, code) = await shell(cmd, cwd: cwd)
        if code != 0 {
            return (nil, JSONRPCError(code: -32000, message: err.isEmpty ? "find failed with exit code \(code)" : err))
        }
        return (toolResult(out), nil)
    }

    private func kouenGrep(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard let cwd = await daemonTools.getActiveCWD() else {
            return (nil, JSONRPCError(code: -32000, message: "No active workspace or session found"))
        }
        guard case let .string(query)? = args["query"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'query' parameter"))
        }
        let path = optionalStringArg(args["path"]) ?? "."
        let rg = "command -v rg >/dev/null 2>&1"
        let quotedQuery = ShellQuoting.quote(query)
        let quotedPath = ShellQuoting.quote(path)
        let cmd = "\(rg) && rg --line-number --column --no-heading --color=never -- \(quotedQuery) \(quotedPath) || grep -RIn -- \(quotedQuery) \(quotedPath)"
        let (out, err, code) = await shell(cmd, cwd: cwd)
        if code != 0 {
            return (nil, JSONRPCError(code: -32000, message: err.isEmpty ? "grep failed with exit code \(code)" : err))
        }
        return (toolResult(out), nil)
    }

    private func kouenRecent(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        let cliPath = BinaryRefresher.installedCLIPath.path
        let binary = FileManager.default.fileExists(atPath: cliPath) ? cliPath : "kouen"
        let cmd = "'\(binary)' recent"
        let (out, err, code) = await shell(cmd, cwd: nil)
        if code != 0 {
            return (nil, JSONRPCError(code: -32000, message: err.isEmpty ? "recent failed with exit code \(code)" : err))
        }
        return (toolResult(out), nil)
    }

    private func kouenErrors(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        let file = optionalStringArg(args["path"]) ?? "."
        let cliPath = BinaryRefresher.installedCLIPath.path
        let binary = FileManager.default.fileExists(atPath: cliPath) ? cliPath : "kouen"
        let cmd = "'\(binary)' lsp diagnostics '\(file)' --json"
        let (out, err, code) = await shell(cmd, cwd: nil)
        if code != 0 {
            return (nil, JSONRPCError(code: -32000, message: err.isEmpty ? "errors failed with exit code \(code)" : err))
        }
        return (toolResult(out), nil)
    }

    // MARK: - Browser tools

    private func kouenBrowserOpen(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(url)? = args["url"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'url' parameter"))
        }
        let direction = optionalStringArg(args["direction"])
        return await browserTools.kouenBrowserOpen(urlStr: url, directionStr: direction)
    }

    private func kouenBrowserNavigate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"],
              case let .string(url)? = args["url"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' or 'url' parameter"))
        }
        return await browserTools.kouenBrowserNavigate(paneIdStr: paneId, urlStr: url)
    }

    private func kouenBrowserWait(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        let timeoutSeconds: Double?
        if case let .double(d)? = args["timeoutSeconds"] {
            timeoutSeconds = d
        } else if case let .int(i)? = args["timeoutSeconds"] {
            timeoutSeconds = Double(i)
        } else {
            timeoutSeconds = nil
        }
        return await browserTools.kouenBrowserWait(paneIdStr: paneId, timeoutSeconds: timeoutSeconds)
    }

    private func kouenBrowserSnapshot(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        let interactive = boolArg(args["interactive"], default: false)
        return await browserTools.kouenBrowserSnapshot(paneIdStr: paneId, interactive: interactive)
    }

    private func kouenBrowserInteract(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"],
              case let .string(action)? = args["action"],
              case let .string(elementId)? = args["elementId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId', 'action', or 'elementId' parameter"))
        }
        let text = optionalStringArg(args["text"])
        return await browserTools.kouenBrowserInteract(paneIdStr: paneId, action: action, elementId: elementId, text: text)
    }

    private func kouenBrowserClose(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserClose(paneIdStr: paneId)
    }

    private func kouenBrowserScreenshot(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserScreenshot(paneIdStr: paneId)
    }

    private func kouenBrowserNetwork(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserNetwork(paneIdStr: paneId)
    }

    private func kouenBrowserCookies(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserCookies(paneIdStr: paneId)
    }

    private func kouenBrowserStorage(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"],
              case let .string(storageType)? = args["storageType"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' or 'storageType' parameter"))
        }
        return await browserTools.kouenBrowserStorage(paneIdStr: paneId, storageType: storageType)
    }

    private func kouenBrowserEvaluate(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"],
              case let .string(script)? = args["script"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' or 'script' parameter"))
        }
        return await browserTools.kouenBrowserEvaluate(paneIdStr: paneId, script: script)
    }

    private func kouenBrowserGoBack(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserGoBack(paneIdStr: paneId)
    }

    private func kouenBrowserGoForward(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserGoForward(paneIdStr: paneId)
    }

    private func kouenBrowserReload(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(paneId)? = args["paneId"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'paneId' parameter"))
        }
        return await browserTools.kouenBrowserReload(paneIdStr: paneId)
    }

    private func kouenSpawnAgent(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(agent)? = args["agent"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'agent' parameter"))
        }
        let workspaceId = optionalStringArg(args["workspaceId"])
        let cwd = optionalStringArg(args["cwd"])
        return await daemonTools.kouenSpawnAgent(
            agent: agent, workspaceId: workspaceId, cwd: cwd,
            worktreePath: optionalStringArg(args["worktreePath"]),
            parentRepoPath: optionalStringArg(args["parentRepoPath"]),
            taskName: optionalStringArg(args["taskName"])
        )
    }

    private func kouenSpawnWorker(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(agent)? = args["agent"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'agent' parameter"))
        }
        guard case let .string(prompt)? = args["prompt"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'prompt' parameter"))
        }
        return await daemonTools.kouenSpawnWorker(
            agent: agent, workspaceId: optionalStringArg(args["workspaceId"]),
            cwd: optionalStringArg(args["cwd"]),
            worktreePath: optionalStringArg(args["worktreePath"]),
            parentRepoPath: optionalStringArg(args["parentRepoPath"]),
            taskName: optionalStringArg(args["taskName"]),
            prompt: prompt
        )
    }

    private func kouenCCRun(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        guard case let .string(prompt)? = args["prompt"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'prompt' parameter"))
        }
        guard case let .string(cwd)? = args["cwd"] else {
            return (nil, JSONRPCError(code: -32602, message: "Missing 'cwd' parameter"))
        }
        return await daemonTools.kouenCCRun(
            prompt: prompt, cwd: cwd,
            profile: optionalStringArg(args["profile"]), model: optionalStringArg(args["model"]),
            effort: optionalStringArg(args["effort"])
        )
    }

    private func kouenCCStatus(_ args: [String: AnyCodable]) async -> (AnyCodable?, JSONRPCError?) {
        let action = optionalStringArg(args["action"]) ?? "get"
        return await daemonTools.kouenCCStatus(action: action, runId: optionalStringArg(args["runId"]))
    }

    // MARK: - Helpers

    private func shell(_ command: String, cwd: String?) async -> (String, String, Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]
                if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
                let outPipe = Pipe(); let errPipe = Pipe()
                process.standardOutput = outPipe; process.standardError = errPipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: (out, err, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", error.localizedDescription, -1))
                }
            }
        }
    }

    private func toolResult(_ text: String) -> AnyCodable {
        .object([
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(text),
            ])]),
        ])
    }

    private func toolResult(json value: AnyCodable) -> AnyCodable {
        let data = try? JSONEncoder().encode(value)
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return toolResult(text)
    }

    private func toolDef(_ name: String, _ description: String, _ properties: [AnyCodable]) -> AnyCodable {
        var props: [String: AnyCodable] = [:]
        var required: [AnyCodable] = []
        for prop in properties {
            if case let .object(p) = prop,
               case let .string(n)? = p["name"],
               case let .string(t)? = p["type"] {
                props[n] = .object(["type": .string(t), "description": p["description"] ?? .string("")])
                if !(isOptionalParam(p["description"])) {
                    required.append(.string(n))
                }
            }
        }
        return .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object(props),
                "required": .array(required),
            ]),
        ])
    }

    private func param(_ name: String, _ type: String, _ description: String) -> AnyCodable {
        .object(["name": .string(name), "type": .string(type), "description": .string(description)])
    }

    private func isOptionalParam(_ value: AnyCodable?) -> Bool {
        guard case let .string(desc)? = value else { return false }
        return desc.contains("optional")
    }

    private func boolArg(_ value: AnyCodable?, default defaultValue: Bool) -> Bool {
        guard case let .bool(b)? = value else { return defaultValue }
        return b
    }

    private func optionalStringArg(_ value: AnyCodable?) -> String? {
        guard case let .string(s)? = value else { return nil }
        return s
    }

    private func intArg(_ value: AnyCodable?, default defaultValue: Int) -> Int {
        guard case let .int(i)? = value else { return defaultValue }
        return i
    }
}
