// Generated from the CHANGELOG.md [2.2.2] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "2.2.2",
        changelogDigest: "8767a2f5deba56e3",
        sections: [
            Section(title: "Fixed", items: [
                "File preview text rendering",
                "File preview background matches terminal",
                "File path handling",
            ]),
            Section(title: "Added", items: [
                "Draggable file editor divider",
                "Cmd-click file paths in terminal",
            ]),
        ]
    )
}
