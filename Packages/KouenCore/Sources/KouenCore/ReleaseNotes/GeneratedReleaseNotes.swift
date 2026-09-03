// Generated from the CHANGELOG.md [4.15.0] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "4.15.0",
        changelogDigest: "c72cb1d216f4ad96",
        sections: [
            Section(title: "Added", items: [
                "Interactive drag-to-scroll support for terminal and file tree sidebar scrollbars with hover expansion",
            ]),
            Section(title: "Fixed", items: [
                "Prevent terminal scrollback history from being wiped on ESC[3J erase-saved-lines sequence",
            ]),
        ]
    )
}
