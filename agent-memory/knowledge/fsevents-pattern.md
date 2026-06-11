# FSEvents Recursive Watcher Pattern (Swift)

Used in: `FileTreeWatcher`, `GitPanelView`
Cases: CASE-016, CASE-021

## When to use

Use FSEventStreamCreate instead of DispatchSource when:
- Need recursive directory watching (nested file add/delete/modify)
- DispatchSource only detects top-level changes in a directory

## Single-file watch (DispatchSource is enough)

For watching **one file** (not a directory), `FSEventStreamCreate`'s recursion isn't
needed — `DispatchSource.makeFileSystemObjectSource` on an `O_EVTONLY` fd is simpler
and sufficient. See `FileChangeWatcher` (Services/FileExplorer), used by
`FileEditorView`/`FileViewerViewController` (CASE-022):

```swift
let fd = open(path, O_EVTONLY)
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd,
    eventMask: [.write, .delete, .rename, .extend, .attrib],
    queue: .main
)
source.setEventHandler { /* debounce, then reload */ }
source.setCancelHandler { close(fd) }
source.resume()
```

Re-open the path (cancel + restart the source) on every reload — this re-arms the
watch and survives editors that save atomically (write temp file, rename over
original), since the stale fd's source would otherwise stop firing. If the reload
target is a reused `QLPreviewView`, call `refreshPreviewItem()` rather than
re-assigning the same `previewItem` URL (QuickLook caches renders by URL).

## Full Swift Actor Pattern

```swift
import CoreServices

// 1. Context class — bridges Swift closure to @convention(c) callback
private final class WatcherContext: @unchecked Sendable {
    let onChange: @MainActor () -> Void
    init(onChange: @MainActor @escaping () -> Void) { self.onChange = onChange }
}

// 2. Storage fields (nonisolated(unsafe) if inside actor)
private nonisolated(unsafe) var watchStream: FSEventStreamRef?
private nonisolated(unsafe) var contextPointer: UnsafeMutableRawPointer?

// 3. Start watching
func startWatching(path: String, onChange: @MainActor @escaping () -> Void) {
    stopWatching()
    let ctx = WatcherContext(onChange: onChange)
    let ptr = UnsafeMutableRawPointer(Unmanaged.passRetained(ctx).toOpaque())
    contextPointer = ptr

    var context = FSEventStreamContext(version: 0, info: ptr, retain: nil, release: nil, copyDescription: nil)

    let callback: FSEventStreamCallback = { _, clientInfo, _, _, _, _ in
        guard let clientInfo else { return }
        let wrapper = Unmanaged<WatcherContext>.fromOpaque(clientInfo).takeUnretainedValue()
        Task { @MainActor in wrapper.onChange() }
    }

    guard let stream = FSEventStreamCreate(
        nil, callback, &context,
        [path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        0.5, // latency seconds
        FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes
        )
    ) else {
        Unmanaged<WatcherContext>.fromOpaque(ptr).release()
        contextPointer = nil
        return
    }

    FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
    FSEventStreamStart(stream)
    watchStream = stream
}

// 4. Stop + release (always call before dealloc)
func stopWatching() {
    if let stream = watchStream {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        watchStream = nil
    }
    if let ptr = contextPointer {
        Unmanaged<WatcherContext>.fromOpaque(ptr).release()
        contextPointer = nil
    }
}
```

## Codex Fix Prompt Template

When giving this pattern to Agy/Codex for a new watcher:

```
Replace [ClassName].startWatching() DispatchSource watcher with FSEventStreamCreate recursive watcher:
- Import CoreServices
- Add WatcherContext class (@unchecked Sendable) holding onChange closure
- Replace watchSource/watchFd fields with watchStream: FSEventStreamRef? + contextPointer: UnsafeMutableRawPointer? (both nonisolated(unsafe))
- In startWatching(): FSEventStreamCreate on [path], flags: FileEvents|NoDefer|UseCFTypes, latency 0.5s, schedule on DispatchQueue.global(qos: .utility)
- Callback: @convention(c), pass onChange via Unmanaged.passRetained pattern (see FileTreeWatcher.swift for reference)
- In stopWatching(): FSEventStreamStop → Invalidate → Release → release contextPointer
```
