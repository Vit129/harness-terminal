# แผนงานปรับปรุงประสิทธิภาพ Panel & Terminal Session (Performance Plan)

Status: **partially-done** — Phase 1–3 merged (`perf/panel-session-performance`, commit `c3db2d5`). Phase 4 (P2 async IPC) pending.

แผนงานนี้รวบรวมปัญหาด้านประสิทธิภาพที่พบจากการ code review ของ `HarnessSidebarPanelViewController`, `SessionCoordinator` และ `ContentAreaViewController` ทั้งหมด 6 ประเด็น รวมถึงฟีเจอร์ใหม่ **File Tree Auto-Update per Session** ที่ปัจจุบันยังไม่ถูก implement เรียงตามความสำคัญและความยากในการแก้ไข เพื่อให้ทีมสามารถวางแผนและลงมือแก้ไขได้อย่างมีระเบียบ

---

## 1. ภาพรวมสถาปัตยกรรม (Architecture Overview)

```text
MainSplitViewController
├── HarnessSidebarPanelViewController   (left rail)
│   ├── NSTableView — cachedSidebarRows (stored, O(1) per call ✅ fixed P1)
│   ├── WorkspaceFileTreeView           (session-aware ✅ fixed F1)
│   └── GitPanelView
└── ContentAreaViewController           (right content)
    ├── WindowTitleStripView
    ├── TerminalTabBarView
    └── PaneContainerView
        └── HarnessSplitView (recursive) → TerminalHostView (leaf)

SessionCoordinator (@MainActor singleton)
├── DaemonSessionService  ← blocking IPC on main thread (⚠️ P2 still pending)
├── TerminalPaneRegistry  [SurfaceID → TerminalHostView]
├── surfaceIndex: [SurfaceID → (tab, tabID)]  ← O(1) index ✅ fixed P3
└── snapshot: SessionSnapshot
```

---

## 2. ปัญหาและแนวทางแก้ไข (Issues & Fixes)

### ✅ 2.1 `sidebarRows` คำนวณซ้ำ O(N²) ทุกครั้งที่ reload ตาราง — DONE

**ไฟล์:** [`HarnessSidebarPanelViewController.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift) L44–58

**ปัญหา (verified):** computed property `sidebarRows` ถูก NSTableView delegate เรียกซ้ำ ~66 ครั้งต่อ `reloadData()` call เดียว (numberOfRows × 1 + heightOfRow × N + viewFor × visible). Inner loop ใช้ `groups.firstIndex(where:)` → O(N×G) ต่อ rebuild.

**แก้แล้ว:**
- เปลี่ยนเป็น `cachedSidebarRows: [SidebarSessionRow]` (stored property)
- `rebuildSidebarRows()` ใช้ `groupMap: [String: Int]` แทน `firstIndex(where:)` → O(1) lookup
- Rebuild เฉพาะใน `reload()`, `refreshMetadata()`, `selectSidebarTab()`, และ `collapsedGroups` toggle
- NSTableView delegate ทุกตัวอ่านจาก cache — O(1) ต่อ call

---

### ⚠️ 2.2 Blocking IPC บน Main Thread — PENDING (P2)

**ไฟล์:** [`SessionCoordinator.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift) L161–199, [`DaemonSessionService.swift`](file:///Users/supavit.cho/Git/harness-terminal/Packages/HarnessCore/Sources/HarnessCore/IPC/DaemonSessionService.swift)

**ปัญหา (verified):** `daemon.fetchSnapshot()` เป็น synchronous blocking call (2s timeout) บน `@MainActor`. ถูกเรียกจาก 40+ call sites ผ่าน `requestDaemon()`. ทุก user action → IPC round-trip บน main thread → UI stutter.

**แนวทางแก้ (ยังไม่ implement — deep refactor):**
- ทำให้ `DaemonSessionService.fetchSnapshot()` เป็น `async` (ห่อ blocking call ใน actor หรือ `Task.detached`)
- เปลี่ยน `syncFromDaemon` เป็น `async`
- อัปเดต 40+ call sites ให้ใช้ `Task { await syncFromDaemon() }`
- `DaemonClient` ปัจจุบัน guard ด้วย `NSLock` และ `@unchecked Sendable` — ต้องออกแบบ concurrency ใหม่อย่างระมัดระวัง

```swift
// Target API
@discardableResult
func syncFromDaemon(metadataOnly: Bool = false) async -> Bool {
    let remote: SessionSnapshot
    do {
        remote = try await daemon.fetchSnapshot()  // off-main wait
    } catch { ... }
    // All snapshot application stays on MainActor (implicit)
    snapshot = remote
    ...
}
```

> **ความยาก:** สูง — ต้องทำใน branch แยก พร้อม integration test ครบถ้วน

---

### ✅ 2.3 การ scan แบบ triple-nested ต่อ sync — DONE

**ไฟล์:** [`SessionCoordinator.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift) L216–232

**ปัญหา (verified):** 6 methods วน `workspaces → sessions → tabs → surfaceIDs` อย่างอิสระ ถูกเรียกทุก sync.

**แก้แล้ว:**
- เพิ่ม `surfaceIndex: [SurfaceID: (tab: Tab, tabID: TabID)]` stored property
- `buildSurfaceIndex(_ snap:)` สร้าง index ครั้งเดียวใน `syncFromDaemon` ทันที
- แทนที่ 6 methods ด้วย O(1) dict lookup:

| Method | Before | After |
|--------|--------|-------|
| `paneBorderContext(forSurface:)` | triple-nested scan | `surfaceIndex[sid]?.tab` |
| `tabAndPane(forSurface:)` | triple-nested scan | `surfaceIndex[sid]` |
| `paneCount(forSurface:)` | triple-nested scan | `surfaceIndex[sid]?.tab.rootPane.allSurfaceIDs().count` |
| `tabID(forSurface:)` | triple-nested scan | `surfaceIndex[sid]?.tabID` |
| `syncWaitingRings()` | flatMap triple scan | `surfaceIndex[sid]` |
| `refreshSyncSiblings()` | triple-nested + flatMap | deduplicated via `seenTabIDs` |

---

### ✅ 2.4 `applyThemeToAllHosts()` ทำงานทุก non-metadata sync — DONE

**ไฟล์:** [`SessionCoordinator.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift) L41–45, L182–190

**ปัญหา (verified):** ไม่มี guard — `applyTheme + applySettings + applyTerminalIdentity + pushBorderColors` ต่อ host ทุก tab/pane switch.

**แก้แล้ว:**
```swift
private var appliedThemeKey = ""

// In syncFromDaemon:
let themeKey = "\(snapshot.themeName)|\(settings.backgroundOpacity)|..."
if themeKey != appliedThemeKey {
    appliedThemeKey = themeKey
    applyThemeToAllHosts()
}
```

---

### ✅ 2.5 Split view double-layout เมื่อ switch tab — DONE

**ไฟล์:** [`ContentAreaViewController.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift) L408–419

**ปัญหา (verified):** `DispatchQueue.main.async` defer ทำให้ split view layout ที่ขนาดผิด (frame = .zero) ก่อน แล้ว resize → PTY double SIGWINCH + 1-frame flicker. Magic number `position > 50` ทำให้ pane แคบมากถูก skip.

**แก้แล้ว:**
```swift
build(node: firstNode, cwd: cwd, into: first)
build(node: secondNode, cwd: cwd, into: second)
split.layoutSubtreeIfNeeded()   // ← force layout synchronously
let totalSize = direction == .horizontal ? split.frame.width : split.frame.height
let position = totalSize * ratio
if position > 0, position < totalSize {   // ← proper bounds check
    split.setPosition(position, ofDividerAt: 0)
}
```

---

### ✅ 2.6 Metadata refresh probe ทุก tab ทุก 2 วินาที — DONE

**ไฟล์:** [`SessionCoordinator.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift) L1383–1420

**ปัญหา (verified):** probe ทุก tab ซ้ำซ้อนเมื่อหลาย session อยู่ใน directory เดียวกัน, interval 2s.

**แก้แล้ว:**
```swift
var probedCWDs = Set<String>()
let updates = work.compactMap { workspaceID, tab -> ... in
    let cwd = tab.cwd
    guard !probedCWDs.contains(cwd) else { return nil }  // ← dedup
    probedCWDs.insert(cwd)
    ...
}
// sleep: 2_000_000_000 → 5_000_000_000 ns
```

---

## 3. ฟีเจอร์ใหม่ — File Tree Auto-Update per Session (F1) ✅ DONE

### 3.1 Root Cause — แก้แล้วทั้งหมด

| # | ไฟล์ | ปัญหา | Status |
|---|------|-------|--------|
| A | [`WorkspaceFileTreeView.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift) | `guard path != rootPath` block refresh เมื่อ session เปลี่ยน | ✅ Fixed |
| B | [`FileTreeSwiftUIView.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/FileTreeSwiftUIView.swift) | `.task(id: rootPath)` ไม่ re-run เมื่อ branch เปลี่ยน | ✅ Fixed |
| C | [`FileTreeWatcher.swift`](file:///Users/supavit.cho/Git/harness-terminal/Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileTreeWatcher.swift) | `gitStatus` hardcoded `.unmodified` | ✅ Fixed |
| D | [`HarnessSidebarPanelViewController.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift) | `reload()` ส่งแค่ `cwd` ไม่มี session identity | ✅ Fixed |

### 3.2 สิ่งที่ implement แล้ว

#### F1-A — `WorkspaceFileTreeView.updateRoot(path:sessionID:)`
Guard เปลี่ยนเป็นตรวจทั้ง path และ sessionID — session ต่างกันใน repo เดียวกันจะ refresh เสมอ.

#### F1-B — `.task(id: "sessionID|rootPath")`
SwiftUI re-runs `loadRoot()` เมื่อ session เปลี่ยน ไม่ใช่แค่ path.

#### F1-C — [`GitStatusProvider`](file:///Users/supavit.cho/Git/harness-terminal/Packages/HarnessCore/Sources/HarnessCore/FileExplorer/GitStatusProvider.swift) (ไฟล์ใหม่)
Actor ที่ run `git status --porcelain -z` off-main, return `[String: GitStatusType]`. Handle non-git dirs gracefully.

#### F1-D — `FileTreeWatcher.scan(rootPath:gitStatus:)`
รับ optional pre-fetched status map และ merge เข้า `FileNode.gitStatus` ผ่าน `applyGitStatus()`.

#### F1-E — `loadRoot()` concurrent fetch
`async let gitStatus + async let rawNodes` → parallel, merge ก่อน render.

#### F1-F — Git status dots ใน `NodeRow`
| Status | Color | Extra |
|--------|-------|-------|
| `.modified` | 🟡 yellow | — |
| `.added` | 🟢 green | — |
| `.deleted` | 🔴 red | strikethrough |
| `.untracked` | ⚫ secondary | — |
| `.unmodified` | — | (hidden, no space) |

#### F1-G — FSEvents live watcher — **NOT YET IMPLEMENTED**
Branch switch live refresh ยังไม่ได้ทำ. File tree จะ refresh เมื่อ session switch หรือ manual tab change แต่ยังไม่ auto-refresh เมื่อ `git checkout` ใน terminal.

**Plan สำหรับ F1-G:**
```swift
// FileTreeWatcher.swift — เพิ่ม FSEvents
public actor FileTreeWatcher {
    private var eventStream: DispatchSourceFileSystemObject?

    public func startWatching(rootPath: String, onChange: @escaping () -> Void) {
        let fd = open(rootPath, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )
        var debounce: DispatchWorkItem?
        source.setEventHandler {
            debounce?.cancel()
            let work = DispatchWorkItem { onChange() }
            debounce = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        eventStream = source
    }

    public func stopWatching() {
        eventStream?.cancel()
        eventStream = nil
    }
}
```

---

## 4. ลำดับการดำเนินงาน (Execution Order) — Updated

```text
Phase 1 (Quick Wins) ✅ DONE — commit c3db2d5
  P1 sidebarRows cache
  P4 theme guard
  P6 metadata dedup

Phase 2 (Medium) ✅ DONE — commit c3db2d5
  P3 surface index dictionary
  P5 sync divider positioning

Phase 3 (New Feature — File Tree per Session) ✅ DONE — commit c3db2d5
  F1-A guard fix
  F1-B task id fix
  F1-C GitStatusProvider (new file)
  F1-D watcher merge
  F1-E loadRoot concurrent fetch
  F1-F UI color dots + strikethrough

Phase 3.5 (F1-G — FSEvents watcher) 🔲 TODO
  FileTreeWatcher.startWatching/stopWatching
  FileTreeSwiftUIView wires up watcher on .task appear/disappear

Phase 4 (Deep Refactor) 🔲 TODO
  P2 async IPC — separate branch, 40+ call sites
```

| Phase | ประเด็น | Status |
|-------|---------|--------|
| 1 (quick wins) | P1, P4, P6 | ✅ Done |
| 2 (medium) | P3, P5 | ✅ Done |
| 3 (new feature) | F1-A → F1-F | ✅ Done |
| 3.5 (FSEvents) | F1-G | 🔲 TODO |
| 4 (deep) | P2 | 🔲 TODO |

---

## 5. ไฟล์ที่แก้ไขแล้ว (Files Changed)

| ไฟล์ | ประเด็น | Commit |
|------|---------|--------|
| [`HarnessSidebarPanelViewController.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift) | P1, F1 integration | c3db2d5 |
| [`SessionCoordinator.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift) | P3, P4, P6 | c3db2d5 |
| [`ContentAreaViewController.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift) | P5 | c3db2d5 |
| [`WorkspaceFileTreeView.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift) | F1-A | c3db2d5 |
| [`FileTreeSwiftUIView.swift`](file:///Users/supavit.cho/Git/harness-terminal/Apps/Harness/Sources/HarnessApp/UI/FileTreeSwiftUIView.swift) | F1-B, F1-E, F1-F | c3db2d5 |
| [`FileTreeWatcher.swift`](file:///Users/supavit.cho/Git/harness-terminal/Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileTreeWatcher.swift) | F1-D | c3db2d5 |
| [`GitStatusProvider.swift`](file:///Users/supavit.cho/Git/harness-terminal/Packages/HarnessCore/Sources/HarnessCore/FileExplorer/GitStatusProvider.swift) | F1-C (new file) | c3db2d5 |

---

## 6. สิ่งที่ยังเหลือ (Remaining Work)

### F1-G — FSEvents watcher (live refresh)
ปัจจุบัน file tree refresh เมื่อ session switch แต่ยังไม่ auto-refresh เมื่อ `git checkout` ใน terminal window. ต้อง implement FSEvents watcher ใน `FileTreeWatcher` แล้วเชื่อมกับ `FileTreeSwiftUIView`.

### P2 — Async IPC refactor
`DaemonSessionService.fetchSnapshot()` ยังเป็น blocking call (2s timeout) บน main thread. การแก้ต้องอัปเดต 40+ call sites — ทำใน branch แยก

---

## 7. การตรวจสอบด้วย Manual Test Cases

**Performance fixes (P1–P6)**
* **P1 — Sidebar reload:** เปิด session จำนวนมาก (10+) และสลับ session อย่างรวดเร็ว sidebar ต้องตอบสนองทันทีโดยไม่มี jank
* **P3 — Sync time:** profiler ควรแสดง `syncFromDaemon` รวมเวลา O(1) สำหรับ surface lookup
* **P4 — Theme apply:** switch tab โดยไม่เปลี่ยน theme — `applyThemeToAllHosts` ไม่ควรถูกเรียก (ตรวจสอบผ่าน breakpoint)
* **P5 — Split divider:** เปิด tab ที่มี split panes แล้ว switch ไป-มา — ไม่ควรเห็น PTY resize flash
* **P6 — Git probe:** เปิด 5 session ใน directory เดียวกัน — git probe ควรรันครั้งเดียวต่อ directory ต่อรอบ

**File Tree Auto-Update (F1)**
* **F1 — Same directory, different branch:** เปิด 3 session ใน repo เดียวกัน (main, feat/A, feat/B) สลับไปแต่ละ session — file tree ต้องอัปเดตตามไฟล์ที่ต่างกันในแต่ละ branch
* **F1 — Git status dots:** แก้ไขไฟล์ใน session feat/A แล้ว save — ไฟล์นั้นต้องแสดง dot สีเหลือง (modified) ใน file tree
* **F1 — New file untracked:** สร้างไฟล์ใหม่ที่ยังไม่ได้ `git add` — file tree แสดง dot สีเทา (untracked)
* **F1 — Deleted file:** ลบไฟล์แล้ว stage (`git rm`) — ชื่อไฟล์แสดง strikethrough พร้อม dot สีแดง
