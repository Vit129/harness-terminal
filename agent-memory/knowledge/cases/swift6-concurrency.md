# CASE — Swift 6 / Concurrency

Grep target: `grep -n "CASE-\|<keyword>" knowledge/cases/swift6-concurrency.md`

| ID | Trigger | Fix |
|----|---------|-----|
| CASE-013 | MainActor.assumeIsolated inside DispatchQueue.main.async | `Task { @MainActor in }` or `.main` queue directly |
| CASE-032 | SwiftUI crash (swift_getObjectType) on session switch | `@Observable` class + `@Bindable var` — never replace rootView struct mid-layout |
| CASE-040 | RL-040 zombie crashes (layout/resetCursorRects/etc) | `nonisolated` + `assumeIsolated` on ALL @objc callbacks, retire-hold 1.5s, NSEvent monitor, guard window!=nil. See `knowledge/bugs/zombie-crash-macos26.md` |
| CASE-055 | RL-040 zombie crash recurring despite retire-hold | Override `removeFromSuperview()` on HarnessTerminalSurfaceView — catches ALL removal paths |
| CASE-067 | SIGBUS in FileTreeWatcher FSEvents callback (RL-075) | Dedicated serial DispatchQueue per stream, defer context release onto it |
