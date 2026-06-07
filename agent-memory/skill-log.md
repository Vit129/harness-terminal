# Skill Log — Improvement Proposals

<!-- Append-only. Never delete entries. -->

| Date | Skill | Problem | Proposed Change | Status |
|------|-------|---------|-----------------|--------|
| 2026-06-07 | AppKit/NSSplitView | Reordering subviews by removing both causes window collapse | Remove only one subview, reinsert with frame restoration — never remove both simultaneously | applied |
| 2026-06-07 | AppKit/NSButton | SoftIconButton with isTransparent=true doesn't forward rightMouseDown | Override rightMouseDown in SoftIconButton to pop up .menu if assigned | applied |
| 2026-06-07 | AppKit/Menu | NSApp.keyWindow can be nil when menu triggered via AppleScript or non-frontmost | Always use `NSApp.keyWindow ?? NSApp.mainWindow` in menu targets | applied |
| 2026-06-07 | Swift6/Compiler | sortSubviews closure with captured non-Sendable reference crashes compiler (signal 6) | Avoid closures that capture @MainActor refs in C-style comparators; use remove+add instead | applied |
