// Generated from the CHANGELOG.md [2.3.0] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "2.3.0",
        changelogDigest: "23bac9ebd6dfaa8c",
        sections: [
            Section(title: "Added", items: [
                "Local workspace completion",
                "IDE Mode shortcut (⌘+⇧+D)",
                "Session state indicator",
                "IDE mode persistence",
                "Diff/patch syntax highlighting",
                "Git Changes click-to-preview",
                "Git History right-click menu",
            ]),
            Section(title: "Changed", items: [
                "P9 complexity reduction",
            ]),
            Section(title: "Fixed", items: [
                "Terminal flicker on file preview open/close (CASE-025)",
            ]),
        ]
    )
}
