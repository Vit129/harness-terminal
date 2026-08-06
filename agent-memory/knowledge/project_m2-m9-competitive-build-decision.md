---
name: m2-m9-competitive-build-decision
description: "User approved building all 8 M2-M9 competitive gaps (2026-07-26 monthly refresh) despite none having individually-validated real-usage friction — a scoped exception to the no-gimmick policy, not a reversal of it"
metadata:
  type: project
  originSessionId: 8de6ccb9-df4a-4ceb-a3e2-36408bd20460
  modified: 2026-08-05
---

On 2026-08-05, after reviewing `agent-memory/knowledge/meta/competitive-position.md`'s
M1-M9 list (2026-07-26 monthly refresh, previously flagged "not yet triaged, don't
auto-build"), user said: "M2,3,4,5,6,7,8,9 ก็น่าทำทั้งหมดเลยนะ" then confirmed
"ทำหมดเลยค่อยๆทำไล่ตั้งแต่ M2-9" after full per-item explanation was given.

**Decision:** build all 8 (M2 through M9), in order, one at a time across sessions.
M1 (Warp Cloud Agent Runners) stays rejected — architecture mismatch (cloud vs
local-daemon), not part of this approval.

**Why:** explicitly asked "is this a real reversal of the 2026-07-26 no-gimmick
policy, or just browsing?" — user chose "explain each one" then approved all 8 after
reading the detail, not a snap decision. See [[no-gimmick-feature-policy]] — that
memory's rejected set (cross-platform GUI, cloud sync, plugins, GPU shader) is
unrelated to M2-M9 and stays rejected; this is a separate, scoped approval for a
specific list, not a general policy change. Treat future never-before-seen
competitor gaps as still needing the no-gimmick bar — this decision does not
pre-approve M10+ or any future refresh's findings.

**How to apply:** each of M2-M9 gets its own `interview`→`dev-architect`→
`task-design`→implement pass (routed via `wayfinder` since it spans multiple
sessions), in the stated order. Don't re-litigate "is this a gimmick" per item —
that question was already answered for this specific list. A brand new competitive
gap surfacing later still goes through the normal no-gimmick bar.

M2-M9 detail (source: `competitive-position.md` 2026-07-26 refresh):
- M2: Warp custom model router — per-request LLM routing rules, UI editor
- M3: cmux Browser Design Mode — human click-to-edit/annotate in browser pane
- M4: cmux Fork Conversation — branch a running agent session (with context) into a new split/tab
- M5: cmux saved workspace layouts — named reusable split-arrangement templates
- M6: iTerm2 AI safety-check — per-command agent-action judged against original request, risky ones held for approval
- M7: iTerm2 workgroup review automation — auto peer-review request on agent idle, auto-paste result
- M8: Supacode PR worktree status inspector + approval-waiver step
- M9: Superset rich input composer — multi-line, @file mention, slash commands
