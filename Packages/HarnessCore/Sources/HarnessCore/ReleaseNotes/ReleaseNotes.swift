import Foundation

/// One released version's notes, rendered into the post-update terminal banner
/// (`TerminalBanner.whatsNew`). The shipped values live in `GeneratedReleaseNotes.swift`,
/// emitted from the top CHANGELOG.md release block by `Scripts/generate-release-notes.swift` —
/// regenerate (never hand-edit) whenever the changelog gains a release section.
public struct ReleaseNotes: Equatable, Sendable {
    public struct Section: Equatable, Sendable {
        /// Keep a Changelog heading — "Added", "Fixed", …
        public let title: String
        /// One line per changelog bullet: the bullet's bold lead phrase (or first
        /// sentence), markdown stripped. Length-capped at render time, not here.
        public let items: [String]

        public init(title: String, items: [String]) {
            self.title = title
            self.items = items
        }
    }

    /// Matches `HarnessVersion.short` for the shipped build (enforced by
    /// `ReleaseNotesGuardTests` and the `package-app.sh` version guard).
    public let version: String
    /// `ReleaseNotes.digest` of the exact CHANGELOG.md block these notes were generated
    /// from, so a post-generation changelog edit fails the drift guard test.
    public let changelogDigest: String
    public let sections: [Section]

    public init(version: String, changelogDigest: String, sections: [Section]) {
        self.version = version
        self.changelogDigest = changelogDigest
        self.sections = sections
    }

    /// FNV-1a 64-bit over UTF-8, hex-encoded. Not cryptographic — a content-drift
    /// fingerprint shared by the generator script and the guard test. The script embeds
    /// its own copy of this function; if the two ever diverge the guard test fails on the
    /// very next generation, so the duplication is self-policing.
    public static func digest(of text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }
}
