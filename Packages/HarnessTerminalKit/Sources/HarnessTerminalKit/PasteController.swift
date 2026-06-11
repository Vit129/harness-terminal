import AppKit
import HarnessCore

/// Handles paste operations (text, images, file drops) for the terminal surface.
/// Extracted from `HarnessTerminalSurfaceView+Find.swift` to reduce file size.
@MainActor
enum PasteController {
    /// If the pasteboard holds a valid image, write it to the pasted-images directory as a PNG and
    /// return the file path. Prefers raw PNG bytes; converts TIFF / other image reps via a bitmap
    /// rep. Returns nil when there's no usable image.
    static func writePastedImage(from pasteboard: NSPasteboard) -> String? {
        guard let png = pngImageData(from: pasteboard) else { return nil }
        let dir = HarnessPaths.pastedImagesDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        prunePastedImages(in: dir)
        let stamp = Int(Date().timeIntervalSince1970)
        let url = dir.appendingPathComponent("pasted-\(stamp)-\(UUID().uuidString.prefix(8)).png")
        do { try png.write(to: url); return url.path } catch { return nil }
    }

    /// Best-effort PNG bytes for whatever image the pasteboard carries (screenshot = PNG/TIFF).
    static func pngImageData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png), NSBitmapImageRep(data: png) != nil {
            return png
        }
        let tiff = pasteboard.data(forType: .tiff) ?? NSImage(pasteboard: pasteboard)?.tiffRepresentation
        if let tiff, let rep = NSBitmapImageRep(data: tiff) {
            return rep.representation(using: .png, properties: [:])
        }
        return nil
    }

    /// Drop pasted-image files older than a day so the directory can't grow unbounded.
    static func prunePastedImages(in dir: URL, olderThan maxAge: TimeInterval = 24 * 60 * 60) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        ) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for url in entries {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? fm.removeItem(at: url) }
        }
    }

    /// Unsafe = contains a line break (would run as a command without bracketed paste) or another
    /// control character. Newlines are already normalized to `\r` before this check.
    static func isUnsafePaste(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value < 0x20 && $0 != "\t" }
    }

    /// Normalize line endings for terminal paste (CR-LF and LF → CR).
    static func normalizedForPaste(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: "\r")
           .replacingOccurrences(of: "\n", with: "\r")
    }
}
