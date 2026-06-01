import CoreText
import XCTest
@testable import HarnessTerminalRenderer

final class GlyphRasterizerTests: XCTestCase {
    private struct ShapedGlyphSignature: Equatable {
        var glyph: CGGlyph
        var utf16Index: Int
        var fontName: String
        var fontSize: CGFloat
    }

    // Menlo ships with every macOS, so these tests are environment-stable.
    private let rasterizer = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)

    func testMetricsArePositiveAndMonospace() {
        let m = rasterizer.metrics()
        XCTAssertGreaterThan(m.width, 0)
        XCTAssertGreaterThan(m.height, 0)
        XCTAssertGreaterThan(m.ascent, 0)
        XCTAssertGreaterThan(m.descent, 0)
        // Line height should be at least ascent + descent.
        XCTAssertGreaterThanOrEqual(m.height, (m.ascent + m.descent).rounded(.up) - 1)
    }

    func testRasterizesLetterWithInk() {
        guard let glyph = rasterizer.rasterize(codepoint: UInt32(UnicodeScalar("A").value)) else {
            return XCTFail("expected a glyph for 'A'")
        }
        XCTAssertGreaterThan(glyph.width, 0)
        XCTAssertGreaterThan(glyph.height, 0)
        XCTAssertEqual(glyph.coverage.count, glyph.width * glyph.height)
        XCTAssertTrue(glyph.coverage.contains { $0 > 0 }, "glyph should have non-zero coverage")
        // 'A' sits above the baseline.
        XCTAssertGreaterThan(glyph.bearingY, 0)
    }

    func testSpaceHasNoInk() {
        XCTAssertNil(rasterizer.rasterize(codepoint: UInt32(UnicodeScalar(" ").value)))
    }

    func testBoldVariantRasterizes() {
        let normal = rasterizer.rasterize(codepoint: UInt32(UnicodeScalar("W").value))
        let bold = rasterizer.rasterize(codepoint: UInt32(UnicodeScalar("W").value), bold: true)
        XCTAssertNotNil(normal)
        XCTAssertNotNil(bold)
    }

    func testFallbackRendersCJK() {
        // Menlo lacks CJK; this exercises the CTFontCreateForString fallback path.
        let glyph = rasterizer.rasterize(codepoint: 0x4E16) // 世
        XCTAssertNotNil(glyph)
        XCTAssertTrue(glyph?.coverage.contains { $0 > 0 } ?? false)
    }

    func testInvalidScalarReturnsNil() {
        XCTAssertNil(rasterizer.rasterize(codepoint: 0xD800)) // lone surrogate
    }

    // MARK: Shaping (ligature path)

    func testShapeEmptyIsEmpty() {
        XCTAssertTrue(rasterizer.shape("", bold: false, italic: false).isEmpty)
    }

    func testShapePlainTextMapsOneGlyphPerCharacterInOrder() {
        // No ligatures in Menlo: "ab" shapes to 2 glyphs whose source indices are 0 and 1,
        // so each lands on its own cell (grid alignment preserved).
        let shaped = rasterizer.shape("ab", bold: false, italic: false)
        XCTAssertEqual(shaped.count, 2)
        XCTAssertEqual(shaped.map(\.utf16Index), [0, 1])
        for sg in shaped {
            XCTAssertNotNil(rasterizer.rasterize(glyph: sg.glyph, font: sg.font))
        }
    }

    func testShapedRunCacheHitsOnRepeat() {
        let rasterizer = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)

        _ = rasterizer.shape("office => != ->", bold: false, italic: false)
        XCTAssertEqual(rasterizer.shapedRunStats.entries, 1)
        XCTAssertEqual(rasterizer.shapedRunStats.misses, 1)
        XCTAssertEqual(rasterizer.shapedRunStats.hits, 0)

        _ = rasterizer.shape("office => != ->", bold: false, italic: false)
        XCTAssertEqual(rasterizer.shapedRunStats.entries, 1)
        XCTAssertEqual(rasterizer.shapedRunStats.misses, 1)
        XCTAssertEqual(rasterizer.shapedRunStats.hits, 1)
    }

    func testShapedRunCacheKeysBoldAndItalicSeparately() {
        let rasterizer = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)

        _ = rasterizer.shape("status => ready", bold: false, italic: false)
        _ = rasterizer.shape("status => ready", bold: true, italic: false)
        _ = rasterizer.shape("status => ready", bold: false, italic: true)

        XCTAssertEqual(rasterizer.shapedRunStats.entries, 3)
        XCTAssertEqual(rasterizer.shapedRunStats.misses, 3)
        XCTAssertEqual(rasterizer.shapedRunStats.hits, 0)
    }

    func testShapedRunCacheIsScopedByFontSize() {
        let small = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)
        let large = GlyphRasterizer(fontFamily: "Menlo", size: 18, scale: 2)

        let smallFirst = small.shape("abc =>", bold: false, italic: false)
        _ = small.shape("abc =>", bold: false, italic: false)
        let largeFirst = large.shape("abc =>", bold: false, italic: false)

        XCTAssertEqual(small.shapedRunStats.misses, 1)
        XCTAssertEqual(small.shapedRunStats.hits, 1)
        XCTAssertEqual(large.shapedRunStats.misses, 1)
        XCTAssertEqual(large.shapedRunStats.hits, 0)
        XCTAssertEqual(signature(smallFirst).map(\.utf16Index), signature(largeFirst).map(\.utf16Index))
        XCTAssertNotEqual(signature(smallFirst).map(\.fontSize), signature(largeFirst).map(\.fontSize))
    }

    func testCachedAndUncachedShapeResultsMatch() {
        let cached = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)
        let uncached = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)

        let text = "office -> != <="
        let uncachedResult = uncached.shape(text, bold: false, italic: false)
        let first = cached.shape(text, bold: false, italic: false)
        let second = cached.shape(text, bold: false, italic: false)

        XCTAssertEqual(signature(first), signature(uncachedResult))
        XCTAssertEqual(signature(second), signature(uncachedResult))
        XCTAssertEqual(cached.shapedRunStats.misses, 1)
        XCTAssertEqual(cached.shapedRunStats.hits, 1)
    }

    func testShapedRunCacheDoesNotExceedCap() {
        let rasterizer = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2, shapedRunCacheLimit: 8)

        for i in 0 ..< 12 {
            _ = rasterizer.shape("run-\(i)", bold: false, italic: false)
        }

        XCTAssertEqual(rasterizer.shapedRunStats.entries, 8)
        XCTAssertEqual(rasterizer.shapedRunStats.misses, 12)
        XCTAssertEqual(rasterizer.shapedRunStats.evictions, 4)
    }

    private func signature(_ shaped: [GlyphRasterizer.ShapedGlyph]) -> [ShapedGlyphSignature] {
        shaped.map {
            ShapedGlyphSignature(
                glyph: $0.glyph,
                utf16Index: $0.utf16Index,
                fontName: CTFontCopyPostScriptName($0.font) as String,
                fontSize: CTFontGetSize($0.font)
            )
        }
    }
}
