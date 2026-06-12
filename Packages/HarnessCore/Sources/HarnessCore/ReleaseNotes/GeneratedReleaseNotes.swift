// Generated from the CHANGELOG.md [2.5.2] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "2.5.2",
        changelogDigest: "d54fac674446fc16",
        sections: [
            Section(title: "Fixed", items: [
                "Metal surface memory leak on pane close",
                "Vi mode crash on malformed clipboard content",
                "⌘1–9 method rename",
            ]),
        ]
    )
}
