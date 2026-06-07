/// Display-column measurement for the dependency-free core layer.
///
/// HarnessCore deliberately doesn't link the terminal engine, so it can't reach the engine's full
/// generated East-Asian-width table across the package boundary. This is a conservative copy of
/// the ranges that matter for the two HarnessCore call sites that measure columns: status-format
/// truncation (`#{=N:…}` in `FormatString`) and the welcome-banner box math (`TerminalBanner`).
/// Both share this one table so the two never drift apart.
enum DisplayWidth {
    /// Total display columns of `text` — wide CJK/emoji count as 2, combining marks and
    /// zero-width controls as 0, everything else as 1.
    static func columns(of text: String) -> Int {
        text.unicodeScalars.reduce(0) { $0 + width(of: $1) }
    }

    /// The longest prefix of `text` that fits in `maxColumns` display columns, cut on grapheme
    /// boundaries so a combining sequence or a wide glyph is never split mid-character (and so a
    /// 2-column glyph never overruns the requested width by a column).
    static func prefix(_ text: String, maxColumns: Int) -> String {
        guard maxColumns > 0 else { return "" }
        var used = 0
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            let w = character.unicodeScalars.reduce(0) { $0 + width(of: $1) }
            if used + w > maxColumns { break }
            used += w
            result.append(character)
        }
        return result
    }

    static func width(of scalar: Unicode.Scalar) -> Int {
        switch scalar.value {
        case 0x0300...0x036F, 0x20D0...0x20FF, 0xFE00...0xFE0F, 0x200B...0x200F:
            return 0 // combining marks, variation selectors, zero-width controls
        case 0x1100...0x115F, // Hangul jamo
             0x2E80...0xA4CF, // CJK radicals … Yi
             0xAC00...0xD7A3, // Hangul syllables
             0xF900...0xFAFF, // CJK compatibility ideographs
             0xFE30...0xFE4F, // CJK compatibility forms
             0xFF00...0xFF60, // fullwidth forms
             0xFFE0...0xFFE6,
             0x1F300...0x1FAFF, // emoji blocks
             0x20000...0x3FFFD: // CJK extensions
            return 2
        default:
            return 1
        }
    }
}
