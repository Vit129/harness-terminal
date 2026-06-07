#!/usr/bin/env swift
// Regenerates Packages/HarnessCore/Sources/HarnessCore/ReleaseNotes/GeneratedReleaseNotes.swift
// from the top release block of CHANGELOG.md.
//
//   swift Scripts/generate-release-notes.swift     (or: make release-notes)
//
// Run in release prep AFTER updating CHANGELOG.md, alongside the HarnessVersion.swift bump.
// Two guards catch a forgotten run: ReleaseNotesGuardTests (version + changelog digest) and
// the package-app.sh version check.
//
// Per bullet, the banner line is the bullet's bold lead phrase (the changelog convention)
// or, failing that, its first sentence — markdown stripped. `TerminalBanner` truncates to
// the pane width at render time, so no length cap is applied here.

import Foundation

// MARK: - Locate files (script lives in Scripts/, repo root is its parent)

let scriptURL = URL(fileURLWithPath: #filePath)
let root = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let changelogURL = root.appendingPathComponent("CHANGELOG.md")
let outputURL = root.appendingPathComponent(
    "Packages/HarnessCore/Sources/HarnessCore/ReleaseNotes/GeneratedReleaseNotes.swift")

guard let changelog = try? String(contentsOf: changelogURL, encoding: .utf8) else {
    FileHandle.standardError.write(Data("error: cannot read \(changelogURL.path)\n".utf8))
    exit(1)
}

// MARK: - Extract the top release block: "## [x.y.z] - date" up to the next "## ["

func firstMatch(_ pattern: String, in text: String) -> [String]? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }
    return (0 ..< match.numberOfRanges).map { index in
        guard let r = Range(match.range(at: index), in: text) else { return "" }
        return String(text[r])
    }
}

guard let headerRange = changelog.range(of: #"(?m)^## \[[^\]]+\] - .*$"#, options: [.regularExpression]) else {
    FileHandle.standardError.write(Data("error: no '## [x.y.z] - date' heading in CHANGELOG.md\n".utf8))
    exit(1)
}
let afterHeader = changelog[headerRange.upperBound...]
let blockEnd = afterHeader.range(of: "\n## [", options: [.literal])?.lowerBound ?? afterHeader.endIndex
// The digested block = heading line + body, trailing whitespace trimmed. The guard test
// recomputes this digest from the repo CHANGELOG.md with the same extraction.
let block = String(changelog[headerRange.lowerBound ..< blockEnd])
    .trimmingCharacters(in: .whitespacesAndNewlines)

guard let header = firstMatch(#"## \[([^\]]+)\] - (\S+)"#, in: block), header.count >= 3 else {
    FileHandle.standardError.write(Data("error: cannot parse version from changelog heading\n".utf8))
    exit(1)
}
let version = header[1]

// MARK: - FNV-1a 64 (must stay byte-identical to ReleaseNotes.digest — the guard test
// compares this script's output against HarnessCore's implementation on every run)

func digest(of text: String) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01b3
    }
    return String(format: "%016llx", hash)
}

// MARK: - Parse sections + bullets

struct Section { let title: String; var items: [String] }

func stripMarkdown(_ text: String) -> String {
    var result = text
    // [text](url) → text
    while let match = firstMatch(#"\[([^\]]+)\]\(([^)]+)\)"#, in: result), match.count >= 2 {
        result = result.replacingOccurrences(of: match[0], with: match[1])
    }
    result = result.replacingOccurrences(of: "**", with: "")
    result = result.replacingOccurrences(of: "`", with: "")
    return result
}

/// The display line for one bullet: bold lead phrase if present, else first sentence.
func summarize(_ bullet: String) -> String {
    var body = bullet
    if body.hasPrefix("**"), let close = body.range(of: "**", range: body.index(body.startIndex, offsetBy: 2) ..< body.endIndex) {
        body = String(body[body.index(body.startIndex, offsetBy: 2) ..< close.lowerBound])
    } else if let sentenceEnd = body.range(of: ". ") {
        body = String(body[..<sentenceEnd.lowerBound])
    }
    body = stripMarkdown(body)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
    while let last = body.last, ".,;:—".contains(last) {
        body.removeLast()
    }
    return body.trimmingCharacters(in: .whitespaces)
}

var sections: [Section] = []
var currentBullet: String?

func flushBullet() {
    guard let bullet = currentBullet, !sections.isEmpty else { currentBullet = nil; return }
    let summary = summarize(bullet)
    if !summary.isEmpty { sections[sections.count - 1].items.append(summary) }
    currentBullet = nil
}

for rawLine in block.split(separator: "\n", omittingEmptySubsequences: false).dropFirst() {
    let line = String(rawLine)
    if line.hasPrefix("### ") {
        flushBullet()
        sections.append(Section(title: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces), items: []))
    } else if line.hasPrefix("- ") {
        flushBullet()
        currentBullet = String(line.dropFirst(2))
    } else if currentBullet != nil, line.hasPrefix("  "), !line.trimmingCharacters(in: .whitespaces).isEmpty {
        currentBullet! += " " + line.trimmingCharacters(in: .whitespaces)
    } else if !line.hasPrefix(" ") {
        flushBullet()
    }
}
flushBullet()

guard sections.contains(where: { !$0.items.isEmpty }) else {
    FileHandle.standardError.write(Data("error: parsed no bullets from the \(version) block\n".utf8))
    exit(1)
}

// MARK: - Emit GeneratedReleaseNotes.swift

func swiftLiteral(_ text: String) -> String {
    var escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
    escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

var out = """
// Generated from the CHANGELOG.md [\(version)] block by Scripts/generate-release-notes.swift.
// DO NOT EDIT BY HAND — regenerate in release prep after updating CHANGELOG.md:
//   swift Scripts/generate-release-notes.swift
// Drift guards: ReleaseNotesGuardTests (version + changelog digest), package-app.sh.

extension ReleaseNotes {
    public static let current = ReleaseNotes(
        version: \(swiftLiteral(version)),
        changelogDigest: \(swiftLiteral(digest(of: block))),
        sections: [

"""
for section in sections where !section.items.isEmpty {
    out += "            Section(title: \(swiftLiteral(section.title)), items: [\n"
    for item in section.items {
        out += "                \(swiftLiteral(item)),\n"
    }
    out += "            ]),\n"
}
out += """
        ]
    )
}

"""

do {
    try out.write(to: outputURL, atomically: true, encoding: .utf8)
    print("wrote \(outputURL.path) (\(version), \(sections.map { "\($0.title): \($0.items.count)" }.joined(separator: ", ")))")
} catch {
    FileHandle.standardError.write(Data("error: cannot write \(outputURL.path): \(error)\n".utf8))
    exit(1)
}
