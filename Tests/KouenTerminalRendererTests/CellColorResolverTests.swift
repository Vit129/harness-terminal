import XCTest
import KouenCore
@testable import KouenTerminalRenderer
import KouenTerminalEngine
import KouenTheme

final class ANSIPaletteTests: XCTestCase {
    private let palette = ANSIPalette(base16: KouenThemeCatalog.theme(named: "Dracula")!.palette)

    func testBaseSixteenComeFromTheme() {
        let base = KouenThemeCatalog.theme(named: "Dracula")!.palette
        for i in 0 ..< 16 {
            XCTAssertEqual(palette.color(at: i), base[i], "base color \(i)")
        }
    }

    func testColorCubeCorners() {
        // 16 = (0,0,0); 231 = (255,255,255).
        XCTAssertEqual(palette.color(at: 16), RGBColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(palette.color(at: 231), RGBColor(red: 255, green: 255, blue: 255))
    }

    func testColorCubePureRed() {
        // r=5,g=0,b=0 -> index 16 + 36*5 = 196 -> (255,0,0).
        XCTAssertEqual(palette.color(at: 196), RGBColor(red: 255, green: 0, blue: 0))
    }

    func testColorCubeLowLevel() {
        // r=g=b=1 -> index 16 + 36 + 6 + 1 = 59 -> (95,95,95).
        XCTAssertEqual(palette.color(at: 59), RGBColor(red: 95, green: 95, blue: 95))
    }

    func testGrayscaleRamp() {
        XCTAssertEqual(palette.color(at: 232), RGBColor(red: 8, green: 8, blue: 8))
        XCTAssertEqual(palette.color(at: 255), RGBColor(red: 238, green: 238, blue: 238))
    }

    func testIndexClamping() {
        XCTAssertEqual(palette.color(at: -5), palette.color(at: 0))
        XCTAssertEqual(palette.color(at: 999), palette.color(at: 255))
    }
}

final class CellColorResolverTests: XCTestCase {
    private let theme = KouenThemeCatalog.theme(named: "Dracula")!
    private var resolver: CellColorResolver { CellColorResolver(theme: theme) }

    func testDefaultsWhenUnset() {
        let r = resolver.resolve(TerminalGridCell(codepoint: 0x41))
        XCTAssertEqual(r.foreground, theme.foreground)
        XCTAssertEqual(r.background, theme.background)
    }

    func testPaletteForeground() {
        let r = resolver.resolve(TerminalGridCell(codepoint: 0x41, foreground: .palette(4)))
        XCTAssertEqual(r.foreground, theme.palette[4])
    }

    func testTrueColorPassesThrough() {
        let r = resolver.resolve(TerminalGridCell(codepoint: 0x41, foreground: .rgb(r: 1, g: 2, b: 3)))
        XCTAssertEqual(r.foreground, RGBColor(red: 1, green: 2, blue: 3))
    }

    func testResolverBytesStayGamutFree() {
        let cell = TerminalGridCell(
            codepoint: 0x41,
            foreground: .rgb(r: 1, g: 2, b: 3),
            background: .rgb(r: 255, g: 0, b: 0)
        )
        let resolved = resolver.resolve(cell)

        for mode in [TerminalColorRenderingMode.accurate, .vivid] {
            _ = RenderColor(resolved.background, renderingMode: mode, gamut: .auto)
            XCTAssertEqual(resolver.resolve(cell), resolved)
            XCTAssertEqual(resolved.foreground, RGBColor(red: 1, green: 2, blue: 3))
            XCTAssertEqual(resolved.background, RGBColor(red: 255, green: 0, blue: 0))
        }
    }

    func testBoldBrightensLowPalette() {
        // Bold + fg palette 1 -> bright variant (palette 9).
        let r = resolver.resolve(TerminalGridCell(codepoint: 0x41, foreground: .palette(1), bold: true))
        XCTAssertEqual(r.foreground, theme.palette[9])
    }

    func testBoldDoesNotBrightenTrueColor() {
        let r = resolver.resolve(TerminalGridCell(codepoint: 0x41, foreground: .rgb(r: 10, g: 20, b: 30), bold: true))
        XCTAssertEqual(r.foreground, RGBColor(red: 10, green: 20, blue: 30))
    }

    func testBoldBrightenDisabled() {
        let plain = CellColorResolver(theme: theme, boldBrightens: false)
        let r = plain.resolve(TerminalGridCell(codepoint: 0x41, foreground: .palette(1), bold: true))
        XCTAssertEqual(r.foreground, theme.palette[1])
    }

    func testFaintDimsTowardBackground() {
        let cell = TerminalGridCell(codepoint: 0x41, foreground: .palette(7), faint: true)
        let expected = theme.palette[7].blended(toward: theme.background, fraction: 0.5)
        XCTAssertEqual(resolver.resolve(cell).foreground, expected)
    }

    func testInverseSwapsForegroundAndBackground() {
        let cell = TerminalGridCell(codepoint: 0x41, foreground: .palette(1), background: .palette(4), inverse: true)
        let r = resolver.resolve(cell)
        XCTAssertEqual(r.foreground, theme.palette[4])
        XCTAssertEqual(r.background, theme.palette[1])
    }

    func testInvisibleMatchesForegroundToBackground() {
        let cell = TerminalGridCell(codepoint: 0x41, foreground: .palette(1), background: .palette(4), invisible: true)
        let r = resolver.resolve(cell)
        XCTAssertEqual(r.foreground, r.background)
        XCTAssertEqual(r.foreground, theme.palette[4])
    }

    // MARK: Minimum contrast (T5)

    func testContrastRatioBlackOnWhiteIsMax() {
        let white = KouenTheme.RGBColor(red: 255, green: 255, blue: 255)
        let black = KouenTheme.RGBColor(red: 0, green: 0, blue: 0)
        XCTAssertEqual(CellColorResolver.contrastRatio(black, white), 21, accuracy: 0.01)
        XCTAssertEqual(CellColorResolver.contrastRatio(white, white), 1, accuracy: 0.01)
    }

    func testMinimumContrastOfOneIsByteIdentical() {
        // ratio 1 = off: a low-contrast gray-on-gray cell is left exactly as the default resolver leaves it.
        let off = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                    defaultForeground: theme.foreground, defaultBackground: theme.background)
        let on = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                   defaultForeground: theme.foreground, defaultBackground: theme.background,
                                   minimumContrast: 1)
        let cell = TerminalGridCell(codepoint: 0x41,
                                    foreground: .rgb(r: 90, g: 90, b: 90), background: .rgb(r: 80, g: 80, b: 80))
        XCTAssertEqual(off.resolve(cell), on.resolve(cell))
    }

    func testMinimumContrastLiftsLowContrastForeground() {
        let resolver = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                         defaultForeground: theme.foreground, defaultBackground: theme.background,
                                         minimumContrast: 7)
        // Dark gray text on a near-black background — well below ratio 7.
        let cell = TerminalGridCell(codepoint: 0x41,
                                    foreground: .rgb(r: 60, g: 60, b: 60), background: .rgb(r: 10, g: 10, b: 10))
        let r = resolver.resolve(cell)
        XCTAssertGreaterThanOrEqual(CellColorResolver.contrastRatio(r.foreground, r.background), 7 - 0.05)
        // The background is untouched; only the foreground is lifted (toward white on a dark bg).
        XCTAssertEqual(r.background, RGBColor(red: 10, green: 10, blue: 10))
        XCTAssertGreaterThan(Int(r.foreground.red), 60)
    }

    func testMinimumContrastSkipsConcealedCells() {
        let resolver = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                         defaultForeground: theme.foreground, defaultBackground: theme.background,
                                         minimumContrast: 7)
        let cell = TerminalGridCell(codepoint: 0x41, foreground: .palette(1), background: .palette(4), invisible: true)
        let r = resolver.resolve(cell)
        XCTAssertEqual(r.foreground, r.background) // conceal still wins (fg == bg)
    }

    /// Regression: ANSI-art content (pixel-art banners, gradients) routinely uses the
    /// `faint` SGR attribute on explicit truecolor values as a legitimate shading
    /// technique — not as a "de-emphasize this UI text" signal. The ghost-text contrast
    /// floor must only kick in for cells with NO explicit color (default fg + faint, or
    /// the literal ANSI-8 grey convention some autosuggestion themes use), or it corrupts
    /// deliberately dark/faint art pixels into washed-out high-contrast blocks.
    func testGhostContrastFloorDoesNotCorruptExplicitlyColoredFaintCells() {
        let resolver = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                         defaultForeground: theme.foreground, defaultBackground: theme.background,
                                         minimumContrast: 3.5)
        // A deliberately dark truecolor pixel (art shading), faint, on a near-black canvas —
        // exactly the shape of an ANSI pixel-art gradient's shadow tone.
        let artPixel = TerminalGridCell(codepoint: 0x20,
                                        foreground: .rgb(r: 40, g: 30, b: 60),
                                        background: .rgb(r: 5, g: 5, b: 5),
                                        faint: true)
        let expected = RGBColor(red: 40, green: 30, blue: 60).blended(
            toward: RGBColor(red: 5, green: 5, blue: 5), fraction: resolver.faintFraction
        )
        XCTAssertEqual(resolver.resolve(artPixel).foreground, expected,
                       "explicit truecolor + faint must NOT be force-lifted to 4.5:1 contrast")

        // The actual ghost-text pattern this floor targets: no explicit color at all.
        let ghostText = TerminalGridCell(codepoint: 0x20, foreground: .none, background: .rgb(r: 5, g: 5, b: 5), faint: true)
        XCTAssertGreaterThanOrEqual(
            CellColorResolver.contrastRatio(resolver.resolve(ghostText).foreground, resolver.resolve(ghostText).background),
            4.5 - 0.05,
            "default-colored faint text (real ghost/autosuggestion text) still gets the legibility floor"
        )
    }

    /// Regression, captured verbatim from the "agy" (Antigravity CLI) pixel-art banner's raw
    /// ANSI stream: `\x1b[38;2;242;146;46;48;2;246;145;46m▀` — a half-block glyph with fg/bg
    /// set to deliberately near-identical warm tones for smooth shading. No `faint` attribute
    /// anywhere in the tool's output — this goes through the plain (non-faint) minimumContrast
    /// path and was getting corrected toward white/black at this user's minimumContrast: 3.5.
    func testGraphicsGlyphsExemptFromContrastFloor() {
        let resolver = CellColorResolver(palette: ANSIPalette(base16: theme.palette),
                                         defaultForeground: theme.foreground, defaultBackground: theme.background,
                                         minimumContrast: 3.5)
        let upperHalfBlock: UInt32 = 0x2580
        let pixel = TerminalGridCell(codepoint: upperHalfBlock,
                                     foreground: .rgb(r: 242, g: 146, b: 46),
                                     background: .rgb(r: 246, g: 145, b: 46))
        XCTAssertEqual(resolver.resolve(pixel).foreground, RGBColor(red: 242, green: 146, blue: 46),
                       "block-drawing glyph's intentionally near-identical fg/bg must not be pulled apart for contrast")

        // A normal letter with the exact same low-contrast color pair still gets corrected —
        // this only exempts graphics glyphs, not every low-contrast cell.
        let letter = TerminalGridCell(codepoint: 0x41, // 'A'
                                      foreground: .rgb(r: 242, g: 146, b: 46),
                                      background: .rgb(r: 246, g: 145, b: 46))
        XCTAssertNotEqual(resolver.resolve(letter).foreground, RGBColor(red: 242, green: 146, blue: 46),
                          "ordinary text with the same low-contrast pair should still be lifted")
    }
}
