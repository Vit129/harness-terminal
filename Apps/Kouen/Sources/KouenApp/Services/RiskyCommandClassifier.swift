import Foundation

/// M6: local heuristic risk classifier for agent-run shell commands. Pure, no I/O, no
/// LLM call — a keyword/pattern blocklist, not a semantic judge against the original
/// request the way iTerm2's actual feature works (that needs a second LLM call and
/// intercepting/holding the command *before* it runs, which requires buffering PTY
/// input ahead of the Enter keystroke — a much larger, riskier change this session
/// didn't have time to build and verify safely). This is advisory-only: it fires
/// AFTER the command already ran (hooked off `onCommandFinished`, OSC 133 `D`), so it
/// can never actually block anything — it's a "heads up" notification, not a gate.
/// Documented scope cut, not a claim of prevention.
enum RiskyCommandClassifier {
    /// Ordered, case-insensitive substring/regex checks. Kept small and legible —
    /// this is a coarse heads-up, not exhaustive security scanning.
    private static let patterns: [String] = [
        #"rm\s+-[a-z]*r[a-z]*f"#,          // rm -rf, rm -fr, rm -Rf, ...
        #"rm\s+-[a-z]*f[a-z]*r"#,
        #"git\s+push\s+.*--force"#,
        #"git\s+push\s+.*-f\b"#,
        #"git\s+reset\s+--hard"#,
        #"drop\s+(table|database)"#,
        #"delete\s+from\s+\w+\s*;?\s*$"#,   // DELETE FROM x with no WHERE clause
        #"truncate\s+table"#,
        #"chmod\s+(-\S*\s+)?777"#,
        #"curl\s+.*\|\s*(sudo\s+)?(ba)?sh"#,
        #"wget\s+.*\|\s*(sudo\s+)?(ba)?sh"#,
        #":\(\)\{.*\};:"#,                  // fork bomb
        #"sudo\s+rm\b"#,
        #">\s*/dev/sd[a-z]"#,
    ]

    private static let regexes: [NSRegularExpression] = patterns.compactMap {
        try? NSRegularExpression(pattern: $0, options: .caseInsensitive)
    }

    static func isRisky(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return regexes.contains { $0.firstMatch(in: trimmed, range: range) != nil }
    }
}
