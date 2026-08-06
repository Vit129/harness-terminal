---
name: feedback-interview-gate-call-first
description: "Always call Skill(interview) as the very first tool call of any task that may need Edit/Write, before attempting the edit — avoids the interview-gate.py deny-then-retry cycle"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f64c0a40-8298-47fb-84fb-caa70d7e9614
---

Call `Skill(interview)` proactively as the first tool call of any coding task in a fresh session — before attempting any `Edit`/`Write` — instead of attempting the edit first and reacting to the gate's deny.

**Why:** `~/.claude/hooks/interview-gate.py` (a `PreToolUse` hook on `Edit`/`Write`) scans the session transcript for a `Skill(interview)` tool_use and denies the edit if absent, enforcing `~/.claude/rules/routing.md`'s "interview is the entry point for every task, no exceptions." It fires once per session transcript — correct/expected behavior, not a bug. User confirmed (2026-07-12) they want the policy kept exactly as-is (no hook change) after hitting the deny-then-retry stumble 3-4 times; the fix is my own discipline, not the gate. See [[feedback_review-new-features-against-lessons]] for the sibling discipline of running a lessons-check pass after new-feature work.

<!-- TODO(maintenance 2026-08-02): [[feedback_review-new-features-against-lessons]] is a broken link — no such memory file exists under agent-memory/. Write it if this sibling discipline is still wanted, or drop the link if it was never created. -->

**How to apply:** At the start of any kouen-terminal task where code edits are plausible, call `Skill(interview)` before the first `Edit`/`Write` attempt of the session — even for a one-line/trivial fix (its own Step 0 fast-paths trivial scope in one line, it does not block). Don't wait to get denied first.
