// Generated from the CHANGELOG.md [1.7.1] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "1.7.1",
        changelogDigest: "7b09ddecca6f97c7",
        sections: [
            Section(title: "Fixed", items: [
                "RIS left the saved cursor alive, so DECSC → RIS → DECRC restored pre-reset state",
                "A torn read in the hook registry could crash the daemon",
                "Copying a selection after scrollback eviction silently produced blank text",
                "Block/char selections dropped a wide (CJK) glyph when only its trailing cell was covered",
                "n/N in copy-mode search jumped to stale rows after scrollback eviction",
                "A wedged binary froze onboarding forever",
                "Settings fields could show a value the terminals weren't using",
                "bind -n (root-table) bindings ignored caps lock",
                "IME composition over a selection was indistinguishable from the selection",
                "select-pane/swap-pane -t silently misrouted bad targets to the next pane",
                "Status-line layout counted scalars, not columns",
                "harness-cli remote add could report success without persisting",
                "SSH tunnel failures all read as timeouts",
                "A dangling --ssh-arg was silently dropped",
                "Killed panes leaked their terminal views",
                "Hooks installed on Linux pointed at the macOS binary path",
                "Closing a session never cleaned its scoped environment",
                "A respawn racing the metadata scan could briefly publish the dead shell's cwd",
            ]),
            Section(title: "Added", items: [
                ".harnesstheme files now open in Harness",
                "Regression tests pinning the daemon-reconnect backoff policy, the OSC 9;4 stale-progress timeout, corrupt layout.json recovery, reap-generation eviction order, and the onboarding probe failure modes (~45 new tests)",
            ]),
        ]
    )
}
