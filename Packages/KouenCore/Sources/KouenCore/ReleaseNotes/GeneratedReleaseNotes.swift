// Generated from the CHANGELOG.md [4.9.0] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: "4.9.0",
        changelogDigest: "fd6e4b3bf6130556",
        sections: [
            Section(title: "Added", items: [
                "Approve/deny, quick-reply, exact-pane jump, per-event sounds (d590786)",
            ]),
            Section(title: "Fixed", items: [
                "Restore Liquid Glass transparency pipeline and finish browser-pane chrome (157e5aa)",
                "Enable arrow-key line editing in release-pipeline prompts (cc60fc3)",
                "Guard MobileBridgeServer reference for platforms without Network (9f7297f)",
            ]),
        ]
    )
}
