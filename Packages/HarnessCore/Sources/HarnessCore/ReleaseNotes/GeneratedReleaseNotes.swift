// Generated from the CHANGELOG.md [2.5.0] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "2.5.0",
        changelogDigest: "e73a7522174e7b15",
        sections: [
            Section(title: "Added", items: [
                "Full vi normal mode in file editor",
                "Vi : ex command mode",
                ":set relativenumber",
                "Inline * search highlight",
                "Jump list",
                "Keyboard navigation in file tree",
                "LSP activated in file editor",
                "⌘1–9 switches sidebar sessions",
                "zoxide integration in Switch Project",
                "clear-history tmux command",
                "word-separators option",
                "wrap-search option",
                "show-prompt-history",
                "resize-window -x <cols> -y <rows>",
                "list-sessions/windows/panes/clients -F <format>",
                "list-sessions/windows/panes/clients --json",
                "window-size option",
                "destroy-unattached option",
                "find-window -C from hooks",
                "resize-window IPC",
                ":bn/:bp navigate file tabs",
            ]),
            Section(title: "Changed", items: [
                "word-separators default: space + tab (tmux default extended with tab)",
                "applyEffectiveSize in DaemonServer reads window-size option to pick smallest/largest/latest client vote",
            ]),
        ]
    )
}
