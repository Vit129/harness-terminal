# Design — M3: Browser Design Mode

Wayfinder ticket: `agent-memory/plans/m2-m9-competitive-features/wayfinder-map.md` (M3).
GLOSSARY.md: "Design Mode" term added during interview pass.

**Scope decision (made solo, overnight autonomous session — flag for morning review):**
cmux's Browser Design Mode may include source-file round-tripping (edit in browser →
diff written back to the app's actual CSS/component file). That requires framework
awareness, source maps, and a file-write path this session has no time to design safely
overnight. v1 here is **visual-preview-only**: live JS style edits in the WKWebView,
never persisted, "Copy CSS" as the only export (manual paste by the human). This is a
deliberate, smaller slice — not a misunderstanding of the source feature. Revisit if the
user wants source round-tripping; that's a separate, larger ticket.

PRODUCT.md check: fits "Multi-agent awareness" / general terminal-for-agent-workflows
scope loosely — this one is human-facing UX inside the existing browser pane, not
agent-facing. No conflict with Out of Scope.

## Strategic Design

No new bounded context — this extends the existing **Browser Pane** capability
(`BrowserPaneView.swift`, already houses agent-facing snapshot/interact/network/cookies
methods). Design Mode is a new human-facing interaction mode on the same WKWebView,
following the exact same JS-injection + `WKScriptMessageHandler` pattern already used
for console capture (`kouenConsoleLog`) and the compositor-relayout kick
(`kouenCompositorKick`).

## Tactical Design

No new persisted domain model — this is pure UI/JS interaction state, not a daemon-owned
resource (unlike M2's rules). State lives entirely in `BrowserPaneView`:

```swift
private var isDesignModeActive = false
private var designModePopover: NSPopover?
```

Selected-element payload (JS → native, via `kouenDesignModeSelect` message):
```json
{
  "tag": "button", "id": "submit-btn", "className": "btn btn-primary",
  "bounds": {"x":120,"y":340,"width":80,"height":32},
  "styles": {
    "color":"rgb(255,255,255)", "backgroundColor":"rgb(37,99,235)",
    "fontSize":"14px", "fontWeight":"600", "padding":"8px 16px",
    "margin":"0px", "border":"1px solid rgb(37,99,235)",
    "width":"80px", "height":"32px"
  }
}
```
Decoded into a `DesignModeElementInfo: Codable` struct in `BrowserPaneView.swift` (or a
small sibling file) — same `evaluateJS` → `JSONDecoder` pattern as `snapshot(interactive:)`.

## Logical Design

### Toolbar button
New `designModeButton: SoftIconButton` (mirrors `viewSourceButton`/`darkModeButton`
exactly — `configureNavigationButton`, added to `toolbarStack`, 24pt width constraint).
Symbol: `"cursorarrow.rays"` (SF Symbol, distinct from existing icons). Tooltip:
"Design Mode". Toggles `isDesignModeActive`; `contentTintColor` reflects active state
(same pattern as `darkModeButton`'s `isWebDarkModeForced` tint at line ~392).

### JS injection (on toggle ON, via `evaluateJS`, not a persistent `WKUserScript` —
unlike console/network capture, this only runs while the human has the mode open)
```js
(function(){
  if (window.__kouenDesignModeActive) return;
  window.__kouenDesignModeActive = true;
  var overlay = document.createElement('div');
  overlay.id = '__kouenDesignOverlay';
  overlay.style.cssText = 'position:fixed;pointer-events:none;z-index:2147483647;' +
    'border:2px solid #2563eb;background:rgba(37,99,235,0.08);display:none;';
  document.body.appendChild(overlay);
  function onMove(e) {
    var r = e.target.getBoundingClientRect();
    Object.assign(overlay.style, {display:'block', left:r.x+'px', top:r.y+'px',
      width:r.width+'px', height:r.height+'px'});
  }
  function onClick(e) {
    e.preventDefault(); e.stopPropagation();
    var el = e.target, cs = getComputedStyle(el);
    var props = ['color','backgroundColor','fontSize','fontWeight','padding','margin','border','width','height'];
    var styles = {}; props.forEach(function(p){ styles[p] = cs[p]; });
    window.webkit.messageHandlers.kouenDesignModeSelect.postMessage({
      tag: el.tagName.toLowerCase(), id: el.id, className: el.className,
      bounds: {x:Math.round(r.x=el.getBoundingClientRect().x), y:0, width:0, height:0}, // see note
      styles: styles
    });
  }
  document.addEventListener('mousemove', onMove, true);
  document.addEventListener('click', onClick, true);
  window.__kouenDesignModeCleanup = function(){
    document.removeEventListener('mousemove', onMove, true);
    document.removeEventListener('click', onClick, true);
    overlay.remove();
    window.__kouenDesignModeActive = false;
  };
})();
```
(Bounds computation in the sketch above is abbreviated — implementer fills in the real
`getBoundingClientRect()` object, same shape as `snapshot()`'s `bounds` field.)
On toggle OFF: `evaluateJS("window.__kouenDesignModeCleanup && window.__kouenDesignModeCleanup()")`.

### Native message handler
`controller0.add(WeakScriptMessageHandler(self), name: "kouenDesignModeSelect")` —
registered once at webview setup time (alongside the existing two), guarded internally
by `isDesignModeActive` so it's a no-op when the mode is off (mirrors nothing currently
in the file — new small guard). Add a case in the existing
`userContentController(_:didReceive:)` switch (`BrowserPaneView.swift:1322-1369`).

### Popover UI
On receiving a selection: build an `NSPopover` (content: `NSViewController` wrapping an
`NSStackView` of labeled `NSTextField`s, one per style property in the payload), anchored
to the click point (convert JS `bounds` → view coordinates the same way existing
`bounds` data is already used for MCP snapshot overlays, if any such conversion exists —
otherwise anchor to the toolbar's design-mode button as a simpler fallback for v1).
Each field's `NSTextField.action` re-runs:
```swift
evaluateJS("document.querySelector('[data-kouen-design-ref]').style.\(prop) = '\(value)'")
```
(Element re-identified via a `data-kouen-design-ref` attribute stamped on select, same
technique `snapshot()` already uses with `data-kouen-ref`.)
A "Copy CSS" `NSButton` at the popover's bottom builds a CSS rule block from the current
field values and calls the existing pasteboard pattern (`copyURLClicked`'s
`NSPasteboard.general` calls) + `Toast.show("CSS copied", in: self)`.

### Cleanup on toggle off / pane close
`isDesignModeActive = false`, close `designModePopover`, run the JS cleanup above. Wire
into `closePaneClicked` too (pane could close while mode is active).

## Next Step
`task-design` (Dev section):
1. `designModeButton` + toolbar wiring
2. JS injection string (full, un-abbreviated) + toggle on/off `evaluateJS` calls
3. `kouenDesignModeSelect` message handler case + `DesignModeElementInfo` decode
4. Popover UI (view controller, text fields, live-apply action, Copy CSS button)
5. Cleanup wiring (toggle off, pane close)
6. Regression test: at minimum a unit test on CSS-rule-block string building from a
   sample `DesignModeElementInfo` (the one piece of this feature with no WKWebView
   dependency — the rest needs a live WebKit runtime, same testing ceiling P28's browser
   features already have per `architecture/browser-devtools-api.md`'s own Testing section:
   "UI: open browser pane → should load... requires Harness app running")
