// Generated from the CHANGELOG.md [2.4.0] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "2.4.0",
        changelogDigest: "e616359de7639db0",
        sections: [
            Section(title: "Added", items: [
                "Ctrl+R command history search",
                "Layout presets (⌘⌥1–5)",
                "Fuzzy file quick-open in command palette",
                "Switch Project section in command palette",
                "Workspace symbol search in command palette",
                "Git worktree → session tab integration",
                "Terminal cheatsheets",
            ]),
            Section(title: "Fixed", items: [
                "Split-pane close button closes the clicked pane, not the active one",
                "Text wrap incorrect in newly split panes",
                "Snapshot notification burst stacking",
            ]),
        ]
    )
}
