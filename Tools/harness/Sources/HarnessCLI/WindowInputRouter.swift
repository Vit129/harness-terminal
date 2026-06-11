import Foundation
import HarnessCore

/// Pure key/mouse input routing extracted from WindowAttachClient.
/// Stateless decode functions — testable without sockets or PTY.
enum WindowInputRouter {
    enum KeySpecDecode: Equatable {
        case complete(KeySpec)
        case incomplete
        case literalPrefix
        case invalid
    }

    /// Decode the bytes captured after the prefix into a single `KeySpec`. Handles
    /// printable keys, `C-<letter>` control bytes, `M-<key>` (ESC-prefixed), and the
    /// CSI/SS3 arrow keys with xterm modifier encodings — so the prefix table's
    /// `Up`/`S-Left`/… bindings resolve over a raw TTY, including split reads.
    static func decodeKeySpec(_ bytes: [UInt8]) -> KeySpecDecode {
        guard let first = bytes.first else { return .incomplete }
        if first == 0x01 && bytes.count == 1 { return .literalPrefix }

        if first == 0x1b { // ESC
            if bytes.count == 1 { return .incomplete }
            let second = bytes[1]
            if second == UInt8(ascii: "[") || second == UInt8(ascii: "O") {
                return decodeCSI(bytes)
            }
            if let scalar = printableScalar(second) {
                return .complete(KeySpec(key: String(scalar), modifiers: .option))
            }
            return .invalid
        }

        // Control bytes 0x01–0x1a → C-a … C-z. (A leading prefix byte is consumed
        // before we ever get here, so 0x01 only reaches this as a command key.)
        if first >= 0x01 && first <= 0x1a {
            let letter = Character(UnicodeScalar(first + 0x60))
            return .complete(KeySpec(key: String(letter), modifiers: .control))
        }
        if first == 0x7f { return .complete(KeySpec(key: "BSpace")) }
        if let scalar = printableScalar(first) {
            return .complete(KeySpec(key: String(scalar)))
        }
        return .invalid
    }

    static func decodeCSI(_ bytes: [UInt8]) -> KeySpecDecode {
        // Forms: ESC [ A  |  ESC O A  |  ESC [ 1 ; <mod> <letter>
        guard bytes.count >= 3 else { return .incomplete }
        func arrowKey(_ b: UInt8) -> String? {
            switch b {
            case UInt8(ascii: "A"): return "Up"
            case UInt8(ascii: "B"): return "Down"
            case UInt8(ascii: "C"): return "Right"
            case UInt8(ascii: "D"): return "Left"
            default: return nil
            }
        }
        let third = bytes[2]
        if let key = arrowKey(third) { return .complete(KeySpec(key: key)) }
        if third == UInt8(ascii: "1") {
            guard bytes.count >= 4 else { return .incomplete }
            guard bytes[3] == UInt8(ascii: ";") else { return .invalid }
            guard bytes.count >= 6 else { return .incomplete }
            guard let key = arrowKey(bytes[5]) else { return .invalid }
            return .complete(KeySpec(key: key, modifiers: modifiers(fromXtermCode: bytes[4])))
        }
        return .invalid
    }

    static func modifiers(fromXtermCode code: UInt8) -> KeySpec.Modifiers {
        // xterm: code = 1 + (shift=1 | alt=2 | ctrl=4). "2"=shift, "3"=alt, "5"=ctrl, "6"=ctrl+shift.
        let value = Int(code) - Int(UInt8(ascii: "0")) - 1
        var mods = KeySpec.Modifiers()
        if value & 1 != 0 { mods.insert(.shift) }
        if value & 2 != 0 { mods.insert(.option) }
        if value & 4 != 0 { mods.insert(.control) }
        return mods
    }

    static func printableScalar(_ byte: UInt8) -> Unicode.Scalar? {
        (byte >= 0x20 && byte < 0x7f) ? Unicode.Scalar(byte) : nil
    }
}
