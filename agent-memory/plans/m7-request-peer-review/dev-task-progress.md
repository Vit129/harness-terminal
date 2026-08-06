# M7 — Request Peer Review — Task Progress

Wayfinder ticket: [../m2-m9-competitive-features/wayfinder-map.md](../m2-m9-competitive-features/wayfinder-map.md) (M7).

**Scope cut, same discipline as M6:** iTerm2's real workgroup-review feature triggers
automatically on agent idle and auto-pastes the peer's response back. Both the reliable
idle-detection-as-a-trigger and the response-capture-and-paste-back round trip need
testing against a real running agent this session doesn't have time for. v1 ships the
asking step only — human-triggered menu command, peer picks up the request, human reads
the reply themselves. Still real value (automates a cited manual habit), honestly scoped.

## KouenApp — MainMenuBuilder.swift

- [x] "Request Peer Review" menu item (View menu)
- [x] `MenuTarget.firstPeerSurfaceID(among:excluding:hasAgent:)` — pure selection logic (first other-pane surface with an active agent), extracted for testability
- [x] `MenuTarget.requestPeerReview()` — finds peer via the above (using `AgentDetector.snapshot(forSurfaceKey:)` as the `hasAgent` check) among the active tab's leaves, types a fixed review-request prompt into it via `requestDaemon(.sendData(...))`; alerts if no peer found
- [x] **Live bugfix round 1** (2026-08-06): `AgentDetector` gate too narrow (OSC-26-only signal, missed Agy/Antigravity panes) — relaxed to accept any other pane (`hasAgent: { _ in true }`)
- [x] **Live bugfix round 2** (2026-08-06): after round 1, action produced zero visible effect (no alert, no prompt in peer pane) — root cause: `coord.activeSurfaceID` is a known-stale GUI cache (RL-043, see `agent-memory/knowledge/focus-persistence.md`) not reliably reset on tab/pane switches; the top guard could silently `return`, or a stale value could make `excluding:` fail to match either candidate, letting `.first` silently pick the wrong (requesting) pane. Fixed: resolve the active pane via daemon-authoritative `tab.activePaneID` instead, alert (never silently return) on every failure path including the browser-pane-active edge case, and added `NSLog("PEER_REVIEW_DEBUG: ...")` capturing activePaneID/activeSurfaceID/candidates/peer for the next live check.

## Tests

- [x] `Tests/KouenAppTests/MenuTargetPeerReviewTests.swift` (4 tests) — skips active surface, skips non-agent surfaces, nil when none qualify, nil on empty candidates

## Docs

- [x] `GLOSSARY.md` — "Request Peer Review" term, explicit contrast with iTerm2's full auto-trigger+auto-paste feature
- [x] `agent-memory/plans/INDEX.md` — M7 row added
- [x] `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` — M7 marked closed

## Verification

- [x] `swift build --product Kouen` — clean
- [x] `swift build --build-tests` — clean
- [x] `KouenAppTests.xctest` full suite — 254/254, 0 failures (250 baseline + 4 new)
- [x] `Tests/robot/run.sh` — 27/27 passed, end-of-session batch run (2026-08-05, covers M2-M9 combined)
- [ ] Live check: two real agent panes, Request Peer Review, confirm the prompt lands correctly in the peer pane — owed
