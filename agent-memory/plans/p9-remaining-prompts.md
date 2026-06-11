# P9 Remaining Tasks — Agent Prompts

Use these prompts to hand off the remaining refactoring work.
Each task is self-contained with context, constraints, and verification steps.

---

## Task #2: HarnessCLI.swift — Extract verb handler groups

### Prompt

```
Refactor `Tools/harness/Sources/HarnessCLI/HarnessCLI.swift` (1,841 LOC) by extracting handler
function implementations into extension files. The `main()` switch dispatch stays in the original
file — only the `static func handle*` / `static func print*` bodies move out.

Create these extension files at the same directory level:

1. `HarnessCLI+Session.swift` — handleNewSession, handleNewTab, handleNewSplit,
   handleSelectWorkspace, handleSelectTab, handleSelectSession, handleHasSession,
   printWorkspaces, printSessions, printSurfaces, printWindows, printPanes, printSnapshot,
   resolveWorkspaceID, resolveSession, snapshot

2. `HarnessCLI+Pane.swift` — handlePaneCommand, handleSwapPane, handleResizePane,
   handleCopyMode, handleSendKeys, handleCapturePane, handlePipePane, handleWaitFor,
   handleSelectPane, handleBreakPane, handleJoinPane, handleMovePane, handleRenumberWindows,
   handleRespawnPane, handleRotateWindow, handleSelectLayout, handleCycleLayout,
   handleLinkWindow, handleUnlinkWindow

3. `HarnessCLI+Buffer.swift` — handleSetBuffer, handleListBuffers, handleShowBuffer,
   handleDeleteBuffer, handlePasteBuffer, handleSaveBuffer, handleLoadBuffer

4. `HarnessCLI+Keys.swift` — handleBindKey, handleUnbindKey, handleListKeys, parseKeyTableArgs

5. `HarnessCLI+Hooks.swift` — handleBindHook, handleUnbindHook, handleListHooks, parseBindHook

6. `HarnessCLI+Options.swift` — handleSetOption, handleShowOptions, handleSetEnvironment,
   handleShowEnvironment, callingPaneTarget, requireSessionID

7. `HarnessCLI+Server.swift` — handleKillServer, handleStartServer, isLiveHarnessDaemon,
   handleDetachClient, printDaemonStats, printClients, handleRemote, runDaemonForeground

8. `HarnessCLI+Info.swift` — printVersion, printUsage, printColorCheck, printThemePreview,
   printCompletions, runDoctor, handleDetectAgent, handleInstallHooks,
   handleInstallShellIntegration, handleRenameTab, handleRenameSession, handleRenameWorkspace

Keep in the original file:
- `@main struct HarnessCLI` with `static func main()` (the switch dispatch)
- Shared utilities: `flagValue`, `flagIsDangling`, `optionalUUIDFlag`, `checkedRequest`,
  `emit`, `positionalArgs`, `makeClient`, `resolveEndpoint`, `resolvedCLIPath`,
  `parseDetachSequence`, `resolveDetachSequence`, `installCLI`, `copyExecutable`
- The `DetachKeys` enum, `OptionalUUID` enum, `CLIInstallLocator` enum

Each extension file:
- `import Foundation` + `import HarnessCore` (+ others as needed per function)
- `extension HarnessCLI { ... }`
- Keep `static func` signatures identical — no behavior change

Constraints:
- Zero behavior change. Same CLI interface. All existing tests must pass.
- Run `swift build` after extraction and fix any access-level issues
  (some functions are `private static` — promote to `static` when moving to extension files,
  since Swift extensions can't have `private` members of the original type).
- Run `swift test --filter HarnessCLITests` to verify.
```

---

## Task #3: WindowAttachClient — Extract WindowInputRouter

### Prompt

```
Extract pure input-routing logic from `Tools/harness/Sources/HarnessCLI/WindowAttachClient.swift`
(1,566 LOC) into a testable type.

Create `Tools/harness/Sources/HarnessCLI/WindowInputRouter.swift`:

```swift
/// Pure key/mouse input routing extracted from WindowAttachClient.
/// Stateless decode functions — testable without sockets or PTY.
enum WindowInputRouter {
    // Move these static functions here (they're already static/pure):
    // - decodeKeySpec(_ bytes: [UInt8]) -> KeySpecDecode
    // - decodeCSI(_ bytes: [UInt8]) -> KeySpecDecode
    // - modifiers(fromXtermCode code: UInt8) -> KeySpec.Modifiers
    // - printableScalar(_ byte: UInt8) -> Unicode.Scalar?

    // Also move the KeySpecDecode enum here.
}
```

Then update WindowAttachClient to call `WindowInputRouter.decodeKeySpec(...)` etc.

Additionally, create `Tests/HarnessCLITests/WindowInputRouterTests.swift`:

```swift
// Test cases:
// - testDecodeKeySpecArrowKeys (ESC [ A/B/C/D → Up/Down/Right/Left)
// - testDecodeKeySpecModifiedArrows (ESC [ 1 ; 5 C → Ctrl+Right)
// - testDecodeKeySpecControlBytes (0x01-0x1a → C-a through C-z)
// - testDecodeKeySpecPrintable (0x20-0x7e → literal char)
// - testDecodeKeySpecEscPrefixed (ESC + printable → M-<char>)
// - testDecodeKeySpecIncomplete (partial sequences → .incomplete)
// - testDecodeKeySpecInvalid (unrecognized → .invalid)
// - testDecodeKeySpecBackspace (0x7f → BSpace)
```

Constraints:
- No behavior change. Existing HarnessCLITests must still pass.
- `swift build && swift test --filter HarnessCLITests`
```

---

## Task #4: SurfaceRegistry — Extract HookExecutor and FormatContextBuilder

### Prompt

```
Decompose `Packages/HarnessDaemon/Sources/HarnessDaemon/SurfaceRegistry.swift` (1,848 LOC)
by extracting two focused helpers. Both are called ONLY under the registry's lock, so they
take explicit parameters rather than accessing registry state directly.

### A) Create `Packages/HarnessDaemon/Sources/HarnessDaemon/FormatContextBuilder.swift`:

```swift
import HarnessCore

/// Builds a FormatContext from snapshot state. Extracted from SurfaceRegistry for clarity.
/// Called under registryLock — all inputs are passed explicitly.
enum FormatContextBuilder {
    static func build(
        snapshot: SessionSnapshot,
        editor: SessionEditor,
        surfaceKey: String?,
        clientName: String?,
        sessions: [String: RealPty],  // for PTY-backed live fields
        attachedClientCount: Int?
    ) -> FormatContext {
        // Move the body of SurfaceRegistry.buildFormatContext() here.
        // All the same logic — resolving workspace/session/tab, paneActive,
        // extended fields (panePID, paneCurrentCommand, paneWidth/Height, historyBytes),
        // paneDead, paneExitStatus, sessionID, windowID, sessionWindows, windowPanes,
        // windowActive, sessionGroup, sessionAttached, serverPID.
    }
}
```

Then change `SurfaceRegistry.buildFormatContext()` to:
```swift
public func buildFormatContext(surfaceKey: String? = nil, clientName: String? = nil) -> FormatContext {
    FormatContextBuilder.build(
        snapshot: editor.snapshot, editor: editor,
        surfaceKey: surfaceKey, clientName: clientName,
        sessions: sessions, attachedClientCount: attachedClientCountProvider?()
    )
}
```

### B) Create `Packages/HarnessDaemon/Sources/HarnessDaemon/HookExecutor.swift`:

```swift
import Foundation
import HarnessCore

/// Fires hooks asynchronously after the registry lock is released.
/// Extracted from SurfaceRegistry for single-responsibility.
final class HookExecutor {
    private let hookRegistry: HookRegistry
    private let hookQueue: DispatchQueue

    init(hookRegistry: HookRegistry, hookQueue: DispatchQueue) {
        self.hookRegistry = hookRegistry
        self.hookQueue = hookQueue
    }

    func fire(_ event: HookEvent, context: FormatContext) {
        hookQueue.async { [weak self] in self?.hookRegistry.fire(event, context: context) }
    }
}
```

Then change `SurfaceRegistry.fireHookLocked` to use `hookExecutor.fire(event, context: resolved)`.

Constraints:
- `SurfaceRegistry` remains `@unchecked Sendable` with same lock discipline.
- Both new types are accessed ONLY under `registryLock` — document this.
- No new `@unchecked Sendable` types (FormatContextBuilder is an enum, HookExecutor is
  internal and only called under lock).
- `swift build && swift test --filter HarnessDaemonTests`
```

---

## Verification Checklist (all tasks)

After completing any task:
1. `swift build` — must succeed with zero errors
2. `swift test` — full suite must pass
3. `git diff --stat` — confirm no unintended changes outside the target files
4. The largest file in the target group should be measurably smaller (≥50 LOC reduction)
