---
name: no-gimmick-feature-policy
description: "User rejected remaining competitive gaps (cross-platform GUI, team sharing/cloud sync, plugin ecosystem, GPU shader customization) as gimmicks — Kouen only builds features that see real usage"
metadata: 
  node_type: memory
  type: project
  originSessionId: e8ee5776-51d2-4c0b-a994-70edf584af3a
  modified: 2026-07-26T12:22:18.638Z
---

On 2026-07-26, after reviewing `agent-memory/knowledge/meta/competitive-position.md`'s remaining open gaps, user said: "ที่เหลือไม่ทำ ปิดไปให้หมด เราเน้น feature ที่ใช้งานเท่านั้น ไม่เอา gimmick" (don't build the rest, close them all — we only focus on features that actually get used, no gimmicks).

Closed explicitly (moved from "open gap" to "deliberate positioning difference, rejected"):
- Cross-platform GUI (Win/Linux)
- Team sharing / cloud sync
- Extensions/plugins ecosystem
- GPU shader customization (already leaned this way in P40 for a security reason — user-authored GLSL/arbitrary MSL compilation at runtime — now also rejected on the gimmick-policy grounds)

**Why:** user's standing product philosophy for this project is usage-driven feature selection, not competitor-checkbox parity. A feature only earns a build slot if it solves something Kouen's own actual workflow needs — matching a competitor's marketing bullet is not sufecient justification on its own.

**How to apply:** in future competitive-gap sweeps (`p3x-competitive-feature-gaps.md`-style plans) or when [[review-new-features-against-lessons]]-style review surfaces "competitor X has feature Y", don't propose building it just because a competitor has it. Only propose if there's an independent signal of real user need (an actual friction point hit during real use, not "parity for parity's sake"). Community-size and similar non-feature gaps were never actionable and stay out of scope regardless.
