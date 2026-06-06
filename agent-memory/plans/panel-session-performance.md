# แผนงานปรับปรุงประสิทธิภาพ Panel & Terminal Session (Performance Plan)

Status: ready

แผนงานนี้รวบรวมปัญหาด้านประสิทธิภาพที่พบจากการ code review ของ `HarnessSidebarPanelViewController`, `SessionCoordinator` และ `ContentAreaViewController` ทั้งหมด 6 ประเด็น รวมถึงฟีเจอร์ใหม่ **File Tree Auto-Update per Session** ที่ปัจจุบันยังไม่ถูก implement เรียงตามความสำคัญและความยากในการแก้ไข เพื่อให้ทีมสามารถวางแผนและลงมือแก้ไขได้อย่างมีระเบียบ

---

## 1. ภาพรวมสถาปัตยกรรม (Architecture Overview)

```text
MainSplitViewController
├── HarnessSidebarPanelViewController   (left rail)
│   ├── NSTableView — sidebarRows (computed, O(N²) issue)
│   ├── WorkspaceFileTreeView
│   └── GitPanelView
└── ContentAreaViewController           (right content)
    ├── WindowTitleStripView
    ├── TerminalTabBarView
    └── PaneContainerView
        └── HarnessSplitView (recursive) → TerminalHostView (leaf)

SessionCoordinator (@MainActor singleton)
├── DaemonSessionService  ← blocking IPC on main thread
├── TerminalPaneRegistry  [SurfaceID → TerminalHostView]
└── snapshot: SessionSnapshot
         ↳ triple-nested scans per sync
```

---

## 2. ปัญหาและแนวทางแก้ไข (Issues & Fixes)

### 2.1 `sidebarRows` คำนวณซ้ำ O(N²) ทุกครั้งที่ reload ตาราง

**ไฟล์:** `HarnessSidebarPanelViewController.swift:61`

**ปัญหา:** `sidebarRows` เป็น computed property ที่ `NSTableView` เรียกซ้ำสำหรับทุก delegate method (`numberOfRows`, `heightOfRow`, `shouldSelectRow`, `isGroupRow`, `viewFor`) ต่อแถว — แต่ละครั้งสร้าง array ใหม่ทั้งหมด ผลคือ N แถว × O(sessions) งาน = O(N²) ต่อ reload หนึ่งครั้ง

**แนวทางแก้:**
- เปลี่ยน `sidebarRows` จาก computed property เป็น stored property `[SidebarSessionRow]`
- invalidate (คำนวณใหม่) เฉพาะใน `reload()`, `refreshMetadata()`, และ `sidebarTabChanged()`
- Delegate methods ทุกตัวอ่านจาก cache — O(1) ต่อ call

```swift
// Before
private var sidebarRows: [SidebarSessionRow] { ... build every call ... }

// After
private var cachedSidebarRows: [SidebarSessionRow] = []

private func rebuildSidebarRows() {
    cachedSidebarRows = buildRows()
}

// Call rebuildSidebarRows() inside reload() and refreshMetadata()
// All delegate methods use cachedSidebarRows instead of sidebarRows
```

**ความยาก:** ต่ำ (< 10 บรรทัดที่เปลี่ยน)

---

### 2.2 Blocking IPC บน Main Thread

**ไฟล์:** `SessionCoordinator.swift:162`

**ปัญหา:** `daemon.fetchSnapshot()` เป็น synchronous socket call ที่รันบน `@MainActor` — ทุก user action (tab switch, session click, pane select) เรียก `requestDaemon(...)` แล้ว `syncFromDaemon()` ต่อกันบน main thread ทำให้ run loop ค้างระหว่าง IPC round-trip ผู้ใช้จะเห็นเป็น UI stutter ที่มองเห็นได้ชัด

**แนวทางแก้:**
- ทำให้ `DaemonSessionService.fetchSnapshot()` เป็น `async` (ห่อ blocking call ใน `Task.detached` หรือ actor)
- เปลี่ยน `syncFromDaemon` เป็น `async` เรียกผ่าน `Task { await syncFromDaemon() }`
- การรอ IPC ย้ายออกจาก main thread; การ apply snapshot และ host update ยังอยู่บน `@MainActor`

```swift
// After
@discardableResult
func syncFromDaemon(metadataOnly: Bool = false) async -> Bool {
    let remote: SessionSnapshot
    do {
        remote = try await daemon.fetchSnapshot()  // off-main wait
    } catch { ... }
    // All snapshot application stays on MainActor (implicit from @MainActor class)
    snapshot = remote
    ...
}
```

**ความยาก:** กลาง (async refactor ของ `DaemonSessionService` + call sites ทั้งหมด)

---

### 2.3 การ scan แบบ triple-nested ต่อ sync

**ไฟล์:** `SessionCoordinator.swift` — `paneCount(forSurface:)`, `tabID(forSurface:)`, `tabAndPane(forSurface:)`, `paneBorderContext(forSurface:)`, `syncWaitingRings()`, `refreshSyncSiblings()`

**ปัญหา:** แต่ละ method วน loop `workspaces → sessions → tabs → surfaceIDs` อย่างอิสระ ทั้งหมดถูกเรียกจาก `syncFromDaemon` หรือ `setActiveSurface` ทุก sync งานรวมคือ O(W × S × T × P) ซ้ำกัน ~6 ครั้งต่อ sync call

**แนวทางแก้:**
- หลัง fetch snapshot สร้าง index `[SurfaceID: Tab]` และ `[SurfaceID: TabID]` ครั้งเดียวใน `syncFromDaemon`
- ส่ง index ให้ทุก scan method — ลดแต่ละ method เป็น O(1) lookup

```swift
// Build once per sync
private func buildSurfaceIndex(_ snap: SessionSnapshot) -> [SurfaceID: Tab] {
    var index: [SurfaceID: Tab] = [:]
    for workspace in snap.workspaces {
        for session in workspace.sessions {
            for tab in session.tabs {
                for sid in tab.rootPane.allSurfaceIDs() {
                    index[sid] = tab
                }
            }
        }
    }
    return index
}
```

**ความยาก:** ต่ำ (เพิ่ม 2 dictionary builds + ส่งผ่าน callers)

---

### 2.4 `applyThemeToAllHosts()` ทำงานทุก non-metadata sync

**ไฟล์:** `SessionCoordinator.swift:183`

**ปัญหา:** `applyThemeToAllHosts()` วน loop host ทั้งหมดและเรียก `applyTheme`, `applySettings`, `applyTerminalIdentity`, `pushBorderColors` ต่อ host แม้ theme และ settings ไม่เปลี่ยน ถูก trigger ทุก tab switch, session switch, และ pane selection

**แนวทางแก้:**

```swift
// Add guard at the top of the non-metadataOnly block:
let themeChanged = remote.themeName != snapshot.themeName
if !metadataOnly && (themeChanged || settingsVersion != appliedSettingsVersion) {
    applyThemeToAllHosts()
    appliedSettingsVersion = settingsVersion
}
```

เก็บ `appliedSettingsVersion: Int` เพิ่มขึ้นเมื่อ `settings` เปลี่ยนจริง

**ความยาก:** ต่ำ (5–8 บรรทัด)

---

### 2.5 Split view double-layout เมื่อ switch tab

**ไฟล์:** `ContentAreaViewController.swift:412`

**ปัญหา:** หลัง build split view hierarchy ตำแหน่ง divider ถูก set ผ่าน `DispatchQueue.main.async` ทำให้ panes layout ที่ขนาดผิดก่อน แล้วจึง resize ทีหลัง — trigger PTY `SIGWINCH` + Metal rerender ทุก tab switch

**แนวทางแก้:** คำนวณตำแหน่ง divider แบบ synchronous โดยใช้ `layoutSubtreeIfNeeded()`:

```swift
// Replace async block with:
build(node: firstNode, cwd: cwd, into: first)
build(node: secondNode, cwd: cwd, into: second)
split.layoutSubtreeIfNeeded()
let size = direction == .horizontal ? split.frame.width : split.frame.height
let position = size * ratio
if position > 50 { split.setPosition(position, ofDividerAt: 0) }
```

**ความยาก:** ต่ำ (ลบ async block + เพิ่ม `layoutSubtreeIfNeeded()`)

---

### 2.6 Metadata refresh probe ทุก tab ทุก 2 วินาที

**ไฟล์:** `SessionCoordinator.swift:1383`

**ปัญหา:** `startMetadataRefresh()` รัน git branch probe สำหรับทุก tab ใน active workspace ทุก 2 วินาที แต่ละ probe คือ disk I/O (`git rev-parse`) session จำนวนมากหมายถึง N probes / 2s บน background thread พร้อม main-thread marshal ผลลัพธ์ทุกตัว

**แนวทางแก้:**
- Deduplicate โดย CWD — ข้าม tab ที่ใช้ directory เดียวกันกับที่ probe แล้วในรอบนั้น
- เพิ่ม interval จาก 2s เป็น 5s
- ติดตาม `lastProbed: [String: Date]` (keyed by CWD) เพื่อ throttle

```swift
var probedCWDs = Set<String>()
let work = await MainActor.run { ... }
for (workspaceID, tab) in work {
    let cwd = tab.cwd
    guard !probedCWDs.contains(cwd) else { continue }
    probedCWDs.insert(cwd)
    // run probe for this cwd
}
```

**ความยาก:** ต่ำ (เพิ่ม Set dedup + เปลี่ยน interval)

---

---

## 3. ฟีเจอร์ใหม่ — File Tree Auto-Update per Session (F1)

### 3.1 ปัญหาที่พบในปัจจุบัน (Root Cause Analysis)

ตอนนี้ file tree ไม่ update ตาม session ที่ active อยู่เพราะมีช่องโหว่ 4 จุด:

```text
Session 1 (main)   ─┐
Session 2 (feat/A) ─┼─ cwd เหมือนกัน (/project)
Session 3 (feat/B) ─┘
         │
         ▼
WorkspaceFileTreeView.updateRoot(path:)
         │
         ▼
guard path != rootPath else { return }   ← EXIT EARLY ทุกครั้ง
         │ (path เหมือนกัน แต่ branch ต่างกัน)
         ▼
FileTreeWatcher.scan(rootPath:)
         │
         ▼
FileNode.gitStatus = .unmodified         ← ไม่เคย populate จริง
```

**4 ช่องโหว่หลัก:**

| # | ไฟล์ | ปัญหา |
|---|------|-------|
| A | `WorkspaceFileTreeView.swift:24` | `guard path != rootPath` block refresh เมื่อ session เปลี่ยนแต่ path เหมือนเดิม |
| B | `FileTreeSwiftUIView.swift:34` | `.task(id: rootPath)` ไม่ re-run เมื่อ branch เปลี่ยน (id เหมือนเดิม) |
| C | `FileTreeWatcher.swift:49` | `gitStatus` ถูก hardcode เป็น `.unmodified` ไม่เคย probe จริง |
| D | `HarnessSidebarPanelViewController.swift:587` | `reload()` ส่งแค่ `cwd` ไม่มี session identity |

---

### 3.2 สถาปัตยกรรมหลังแก้ไข (Target Architecture)

```text
Session switch (reload)
       │
       ▼
WorkspaceFileTreeView.updateRoot(path:, sessionID:)
       │
       ├─ sessionID เปลี่ยน → force refresh เสมอ (แม้ path เหมือนเดิม)
       │
       ▼
FileTreeSwiftUIView
  .task(id: sessionID + rootPath)  ← react ต่อ session change
       │
       ├─ 1. scan filesystem  (FileTreeWatcher.scan)
       └─ 2. fetch git status (GitStatusProvider.status)
                 │
                 ▼
         git status --porcelain -z
                 │
                 ▼
         [RelPath: GitStatusType]  ← merge เข้า FileNode.gitStatus
                 │
                 ▼
         แสดงสี dot ข้างชื่อไฟล์
         ● modified (yellow)
         ● added    (green)
         ● deleted  (red/strikethrough)
         ● untracked (gray)

FS Watcher (FSEvents)
  watchPath = rootPath
  debounce  = 500ms
       │
       ▼
  trigger reload เมื่อ git checkout / file change
```

---

### 3.3 แผนการ implement ทีละขั้น (Implementation Steps)

#### Step F1-A — แก้ guard ใน `WorkspaceFileTreeView`

```swift
// WorkspaceFileTreeView.swift

func updateRoot(path: String, sessionID: SessionID) {
    // Force refresh when session changes, even if path is the same.
    // Different sessions can be on different git branches sharing the same root.
    guard path != rootPath || sessionID != lastSessionID else { return }
    rootPath = path
    lastSessionID = sessionID
    hostingView.rootView = FileTreeSwiftUIView(
        rootPath: path,
        sessionID: sessionID,
        watcher: watcher
    )
}

private var lastSessionID: SessionID?
```

#### Step F1-B — เพิ่ม sessionID ใน `.task` id ของ `FileTreeSwiftUIView`

```swift
// FileTreeSwiftUIView.swift

struct FileTreeSwiftUIView: View {
    let rootPath: String
    let sessionID: SessionID        // ← เพิ่มใหม่
    let watcher: FileTreeWatcher
    @State private var rootNodes: [FileTreeNode] = []

    var body: some View {
        List { ... }
        .task(id: "\(sessionID)|\(rootPath)") {  // ← react ต่อ session change
            await loadRoot()
        }
    }
}
```

#### Step F1-C — สร้าง `GitStatusProvider` (actor ใหม่)

```swift
// Packages/HarnessCore/Sources/HarnessCore/FileExplorer/GitStatusProvider.swift

public actor GitStatusProvider {
    /// Run `git status --porcelain -z` and return a map of
    /// relative path → GitStatusType. Returns empty on non-git dirs.
    public func status(rootPath: String) async -> [String: GitStatusType] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", rootPath, "status", "--porcelain", "-z"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()   // suppress stderr
        do {
            try process.run()
            process.waitUntilExit()
        } catch { return [:] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return parse(data)
    }

    private func parse(_ data: Data) -> [String: GitStatusType] {
        guard let raw = String(data: data, encoding: .utf8) else { return [:] }
        var result: [String: GitStatusType] = [:]
        // porcelain -z: entries separated by NUL, each "XY path"
        for entry in raw.split(separator: "\0") {
            guard entry.count > 3 else { continue }
            let xy = entry.prefix(2)
            let path = String(entry.dropFirst(3))
            let status: GitStatusType
            switch xy.last {          // use the working-tree status (Y column)
            case "M": status = .modified
            case "A": status = .added
            case "D": status = .deleted
            case "?": status = .untracked
            default:  status = .unmodified
            }
            result[path] = status
        }
        return result
    }
}
```

#### Step F1-D — รวม git status เข้า `FileTreeWatcher.scan`

```swift
// FileTreeWatcher.swift

public func scan(rootPath: String, gitStatus: [String: GitStatusType] = [:]) async throws -> [FileNode] {
    let nodes = try scanDirectory(atPath: rootPath)
    guard !gitStatus.isEmpty else { return nodes }
    return nodes.map { node in
        let rel = String(node.path.dropFirst(rootPath.count + 1))
        var updated = node
        updated.gitStatus = gitStatus[rel] ?? .unmodified
        return updated
    }
}
```

#### Step F1-E — เรียก GitStatusProvider ใน `FileTreeSwiftUIView.loadRoot`

```swift
private func loadRoot() async {
    let statusProvider = GitStatusProvider()
    async let gitStatus = statusProvider.status(rootPath: rootPath)
    async let rawNodes = (try? watcher.scan(rootPath: rootPath)) ?? []
    let (status, nodes) = await (gitStatus, rawNodes)
    let merged = nodes.map { node -> FileNode in
        let rel = String(node.path.dropFirst(rootPath.count + 1))
        var n = node
        n.gitStatus = status[rel] ?? .unmodified
        return n
    }
    rootNodes = merged.map { FileTreeNode(node: $0) }
}
```

#### Step F1-F — แสดงสี git status ใน `NodeRow`

```swift
// FileTreeSwiftUIView.swift — NodeRow

private func gitDot(_ status: GitStatusType) -> some View {
    let color: Color = switch status {
    case .modified:   .yellow
    case .added:      .green
    case .deleted:    .red
    case .untracked:  .secondary
    case .unmodified: .clear
    }
    return Circle().fill(color).frame(width: 6, height: 6)
}

private func rowLabel(systemImage: String) -> some View {
    HStack(spacing: 4) {
        Image(systemName: systemImage)
        Text(node.node.name)
            .strikethrough(node.node.gitStatus == .deleted)
        Spacer()
        gitDot(node.node.gitStatus)
    }
    .help(node.node.path)
    ...
}
```

#### Step F1-G — เพิ่ม FSEvents watcher (live refresh เมื่อ branch เปลี่ยน)

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

### 3.4 Integration point ใน Sidebar

```swift
// HarnessSidebarPanelViewController.swift — reload()

if let cwd = snap.activeWorkspace?.activeTab?.cwd,
   let sessionID = snap.activeWorkspace?.activeSessionID {
    fileTreeView.updateRoot(path: cwd, sessionID: sessionID)  // ← ส่ง sessionID
    gitPanelView.updateRoot(path: cwd)
}
```

---

## 4. ลำดับการดำเนินงาน (Execution Order)

```text
Phase 1 (Quick Wins)
  P1 sidebarRows cache  ──┐
  P4 theme guard        ──┼── ไม่มี prerequisite, แก้ได้ทันที
  P6 metadata dedup     ──┘

Phase 2 (New Feature — File Tree per Session)
  F1-A guard fix          ──┐
  F1-B task id fix        ──┤
  F1-C GitStatusProvider  ──┼── ทำพร้อมกันได้, ไม่มี dependency ซ้อนกัน
  F1-D watcher merge      ──┤
  F1-E loadRoot update    ──┤ (depends on F1-C, F1-D)
  F1-F UI color dots      ──┤ (depends on F1-E)
  F1-G FSEvents watcher   ──┘

Phase 3 (Medium)
  P3 surface index ── ไม่มี prerequisite

Phase 4 (Deep Refactor)
  P2 async IPC ── ทำหลัง P3

Phase 5 (UX Polish)
  P5 sync divider ── ไม่มี prerequisite
```

| Phase | ประเด็น | Prerequisite |
|-------|---------|-------------|
| 1 (quick wins)   | P1, P4, P6 | ไม่มี |
| 2 (new feature)  | F1-A → F1-G | ทำตามลำดับ A→B→C→D→E→F→G |
| 3 (medium)       | P3         | ไม่มี |
| 4 (deep)         | P2         | P3 เสร็จแล้ว |
| 5 (UX polish)    | P5         | ไม่มี |

---

## 5. ไฟล์ที่ต้องแก้ไข (Files Touched)

| ไฟล์ | ประเด็น |
|------|---------|
| `Apps/Harness/Sources/HarnessApp/UI/HarnessSidebarPanelViewController.swift` | P1, F1-G (integration) |
| `Apps/Harness/Sources/HarnessApp/Services/SessionCoordinator.swift` | P2, P3, P4, P6 |
| `Apps/Harness/Sources/HarnessApp/UI/ContentAreaViewController.swift` | P5 |
| `Apps/Harness/Sources/HarnessApp/UI/WorkspaceFileTreeView.swift` | F1-A |
| `Apps/Harness/Sources/HarnessApp/UI/FileTreeSwiftUIView.swift` | F1-B, F1-E, F1-F |
| `Packages/HarnessCore/Sources/HarnessCore/FileExplorer/FileTreeWatcher.swift` | F1-D, F1-G |
| `Packages/HarnessCore/Sources/HarnessCore/FileExplorer/GitStatusProvider.swift` | F1-C (ไฟล์ใหม่) |
| `Packages/HarnessCore/Sources/HarnessCore/IPC/DaemonSessionService.swift` | P2 |

---

## 6. การตรวจสอบด้วย Manual Test Cases

**Performance fixes (P1–P6)**
* **P1 — Sidebar reload:** เปิด session จำนวนมาก (10+) และสลับ session อย่างรวดเร็ว sidebar ต้องตอบสนองทันทีโดยไม่มี jank
* **P2 — IPC stutter:** switch tab อย่างต่อเนื่องและวัด main thread idle time ด้วย Instruments — ไม่ควรมี block > 16ms
* **P3 — Sync time:** profiler ควรแสดง `syncFromDaemon` รวมเวลา O(1) สำหรับ surface lookup แทนที่จะเป็น O(N)
* **P4 — Theme apply:** switch tab โดยไม่เปลี่ยน theme — `applyThemeToAllHosts` ไม่ควรถูกเรียก (ตรวจสอบผ่าน breakpoint หรือ signpost)
* **P5 — Split divider:** เปิด tab ที่มี split panes แล้ว switch ไป-มา — ไม่ควรเห็น PTY resize flash
* **P6 — Git probe:** เปิด 5 session ใน directory เดียวกัน — git probe ควรรันครั้งเดียวต่อ directory ต่อรอบ (ตรวจสอบผ่าน log)

**File Tree Auto-Update (F1)**
* **F1 — Same directory, different branch:** เปิด 3 session ใน repo เดียวกัน (main, feat/A, feat/B) สลับไปแต่ละ session — file tree ต้องอัปเดตตามไฟล์ที่ต่างกันในแต่ละ branch
* **F1 — Git status dots:** แก้ไขไฟล์ใน session feat/A แล้ว save — ไฟล์นั้นต้องแสดง dot สีเหลือง (modified) ใน file tree ของ session นั้น แต่ session main ยังเป็น unmodified
* **F1 — New file untracked:** สร้างไฟล์ใหม่ที่ยังไม่ได้ `git add` — file tree แสดง dot สีเทา (untracked)
* **F1 — Branch switch live update:** รัน `git checkout feat/B` ใน terminal ของ session — file tree ต้อง refresh ภายใน ~500ms โดยอัตโนมัติ (FSEvents debounce)
* **F1 — Deleted file:** ลบไฟล์แล้ว stage (`git rm`) — ชื่อไฟล์แสดง strikethrough พร้อม dot สีแดง
