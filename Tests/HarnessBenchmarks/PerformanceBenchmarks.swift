import Foundation
import HarnessCore
import HarnessTerminalEngine
@testable import HarnessTerminalRenderer
@testable import HarnessTerminalKit
import HarnessTheme
import Metal
import XCTest

/// Performance baselines for Harness's hot paths. These exist to catch regressions, not to
/// gate CI — `measure {}` runs each body ~10×, which is too slow for the default suite, so the
/// whole file is opt-in. Run with:
///
///     HARNESS_BENCHMARKS=1 swift test --filter HarnessBenchmarks
///
/// Xcode/`xctest` prints the per-iteration time and tracks it against a stored baseline.
///
/// Workloads are sized to finish quickly even in an unoptimized debug build (`measure {}` runs
/// each body ~10×). For headline absolute numbers, build release: `swift test -c release
/// --filter HarnessBenchmarks` (still gated on HARNESS_BENCHMARKS=1).
final class PerformanceBenchmarks: XCTestCase {
    private let theme = HarnessThemeCatalog.theme(named: "Dracula")!

    private func skipUnlessEnabled() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HARNESS_BENCHMARKS"] == "1",
            "Set HARNESS_BENCHMARKS=1 to run performance benchmarks."
        )
    }

    private func timedNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        return DispatchTime.now().uptimeNanoseconds &- start
    }

    private func printBenchmark(_ name: String, nanos: UInt64, fields: [(String, String)] = []) {
        let extras = fields.map { ",\"\($0.0)\":\($0.1)" }.joined()
        print("{\"benchmark\":\"\(name)\",\"nanos\":\(nanos)\(extras)}")
    }

    private func makeMetalDevice() throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        return device
    }

    private func makeTarget(_ device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: TerminalMetalRenderer.pixelFormat, width: width, height: height, mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        return device.makeTexture(descriptor: desc)
    }

    private func filledSnapshot(cols: Int, rows: Int) -> TerminalGridSnapshot {
        let term = HarnessGridTerminal(cols: cols, rows: rows)!
        let chunk = "abcdefghijklmnopqrstuvwxyz0123456789"
        var stream = "\u{1b}[?25l"
        for row in 0 ..< rows {
            var line = ""
            while line.count < cols { line += chunk }
            let color = 31 + (row % 7)
            let background = 40 + (row % 8)
            stream += "\u{1b}[\(row + 1);1H\u{1b}[\(color);\(background)m\(String(line.prefix(cols)))"
        }
        term.feed(stream)
        return term.readGrid()!
    }

    private func frame(cols: Int, rows: Int) -> TerminalFrame {
        FrameBuilder(theme: theme).build(filledSnapshot(cols: cols, rows: rows))
    }

    private func makeAtlas(device: MTLDevice, rasterizer: GlyphRasterizer? = nil) throws -> GlyphAtlas {
        let rasterizer = rasterizer ?? GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)
        return try XCTUnwrap(GlyphAtlas(device: device, rasterizer: rasterizer), "GlyphAtlas failed to build")
    }

    @discardableResult
    private func encodeAndWait(renderer: TerminalMetalRenderer, frame: TerminalFrame, target: MTLTexture) -> TerminalRenderStats {
        guard let commandBuffer = renderer.encode(
            frame,
            target: target,
            clearColor: RenderColor(red: 0, green: 0, blue: 0, alpha: 1),
            origin: (0, 0),
            gamma: 1,
            ligatures: false
        ) else {
            XCTFail("encode")
            return renderer.stats
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return renderer.stats
    }

    /// A representative ~1 MiB stream: colored SGR runs, cursor moves, newlines, and UTF-8 —
    /// the kind of output a build log or a TUI produces.
    private func syntheticStream(targetBytes: Int) -> [UInt8] {
        var s = ""
        var i = 0
        while s.utf8.count < targetBytes {
            let color = 31 + (i % 7)
            s += "\u{1b}[\(color);1mline \(i)\u{1b}[0m: the quick brown fox — café ☕ 0123456789\r\n"
            if i % 24 == 23 { s += "\u{1b}[2J\u{1b}[H" } // periodic clear+home, like a redraw
            i += 1
        }
        return Array(s.utf8)
    }

    private struct SurfaceMainThreadStallSample {
        var totalNanos: UInt64
        var feedNanos: UInt64
        var frameBuildNanos: UInt64
        var bytes: Int
        var cells: Int
        var historyLines: Int
    }

    /// Mirrors today's surface hot path: PTY bytes are parsed on the main thread, then the next
    /// frame snapshot/damage/build is also produced on the main thread. This is Task 8's gate:
    /// if this number is not a real stall, the off-main pipeline should not be enabled.
    @MainActor
    private func sampleSurfaceMainThreadStall(bytes: [UInt8], cols: Int = 160, rows: Int = 48) -> SurfaceMainThreadStallSample {
        let term = TerminalEmulator(cols: cols, rows: rows)
        term.maxScrollbackLines = 10_000
        let builder = FrameBuilder(theme: theme)

        let start = DispatchTime.now().uptimeNanoseconds
        let feedStart = DispatchTime.now().uptimeNanoseconds
        term.feed(bytes)
        let feedNanos = DispatchTime.now().uptimeNanoseconds &- feedStart

        let frameBuildStart = DispatchTime.now().uptimeNanoseconds
        let grid = term.readGrid()
        let damage = term.consumeDamage()
        let frame = builder.build(grid, region: nil, imageProvider: { _ in nil }, reusing: nil, damage: damage)
        let frameBuildNanos = DispatchTime.now().uptimeNanoseconds &- frameBuildStart

        return SurfaceMainThreadStallSample(
            totalNanos: DispatchTime.now().uptimeNanoseconds &- start,
            feedNanos: feedNanos,
            frameBuildNanos: frameBuildNanos,
            bytes: bytes.count,
            cells: frame.cells.count,
            historyLines: term.historyCount
        )
    }

    private struct SurfaceOffMainStallSample {
        var mainNanos: UInt64
        var workerDrainNanos: UInt64
        var bytes: Int
        var cells: Int
    }

    @MainActor
    private func sampleSurfaceOffMainStall(data: Data) -> SurfaceOffMainStallSample {
        let view = HarnessTerminalSurfaceView(offMainParserFramePipeline: true)
        view.testingResizeGrid(cols: 160, rows: 48)

        let mainStart = DispatchTime.now().uptimeNanoseconds
        view.receive(data)
        let mainNanos = DispatchTime.now().uptimeNanoseconds &- mainStart

        let workerStart = DispatchTime.now().uptimeNanoseconds
        view.testingWaitForEmulatorIdle()
        let workerDrainNanos = DispatchTime.now().uptimeNanoseconds &- workerStart

        let grid = view.testingReadGridSnapshot()
        return SurfaceOffMainStallSample(
            mainNanos: mainNanos,
            workerDrainNanos: workerDrainNanos,
            bytes: data.count,
            cells: grid.cols * grid.rows
        )
    }

    // MARK: - VT parser / emulator throughput

    func testVTParseThroughput256KiB() throws {
        try skipUnlessEnabled()
        let bytes = syntheticStream(targetBytes: 256 * 1024)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
        printBenchmark("vt_parse_throughput_256kib", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
    }

    @MainActor
    func testSurfaceMainThreadStall4MiB() throws {
        try skipUnlessEnabled()
        let bytes = syntheticStream(targetBytes: 4 * 1024 * 1024)
        let sample = sampleSurfaceMainThreadStall(bytes: bytes)
        XCTAssertEqual(sample.cells, 160 * 48)
        printBenchmark(
            "surface_main_thread_stall_4mib",
            nanos: sample.totalNanos,
            fields: [
                ("feedNanos", "\(sample.feedNanos)"),
                ("frameBuildNanos", "\(sample.frameBuildNanos)"),
                ("bytes", "\(sample.bytes)"),
                ("cells", "\(sample.cells)"),
                ("historyLines", "\(sample.historyLines)"),
            ]
        )

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            _ = sampleSurfaceMainThreadStall(bytes: bytes)
        }
    }

    @MainActor
    func testSurfaceOffMainMainThreadStall4MiB() throws {
        try skipUnlessEnabled()
        let data = Data(syntheticStream(targetBytes: 4 * 1024 * 1024))
        let sample = sampleSurfaceOffMainStall(data: data)
        XCTAssertEqual(sample.cells, 160 * 48)
        printBenchmark(
            "surface_off_main_thread_stall_4mib",
            nanos: sample.mainNanos,
            fields: [
                ("workerDrainNanos", "\(sample.workerDrainNanos)"),
                ("bytes", "\(sample.bytes)"),
                ("cells", "\(sample.cells)"),
            ]
        )

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            _ = sampleSurfaceOffMainStall(data: data)
        }
    }

    /// Pure printable-ASCII lines + CRLF — the best case for the ASCII run fast path (no escapes,
    /// no high bytes, so the parser batches each line into one run).
    private func asciiStream(targetBytes: Int) -> [UInt8] {
        var s = ""
        var i = 0
        while s.utf8.count < targetBytes {
            s += "line \(i): the quick brown fox jumps over the lazy dog 0123456789\r\n"
            i += 1
        }
        return Array(s.utf8)
    }

    /// SGR-colored ASCII: escapes punctuate the stream, but the text between them is printable
    /// ASCII that still flows through the run fast path.
    private func ansiAsciiStream(targetBytes: Int) -> [UInt8] {
        var s = ""
        var i = 0
        while s.utf8.count < targetBytes {
            let color = 31 + (i % 7)
            s += "\u{1b}[\(color);1mline \(i)\u{1b}[0m the quick brown fox jumps 0123456789\r\n"
            i += 1
        }
        return Array(s.utf8)
    }

    /// Print-dominated ASCII: no newlines, so it wraps to fill a tall screen instead of scrolling
    /// (scroll is O(cols×rows) per line and would otherwise mask the print cost the fast path
    /// targets).
    private func wrapStream(targetBytes: Int) -> [UInt8] {
        var a = [UInt8](); a.reserveCapacity(targetBytes)
        let chunk = Array("the quick brown fox jumps over the lazy dog 0123456789 ".utf8)
        while a.count < targetBytes { a.append(contentsOf: chunk) }
        return a
    }

    /// Parse + write 256 KiB of plain ASCII — exercises the printable-ASCII run fast path.
    func testVTParsePlainASCII256KiB() throws {
        try skipUnlessEnabled()
        let bytes = asciiStream(targetBytes: 256 * 1024)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
        printBenchmark("vt_parse_plain_ascii_256kib", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
    }

    /// Parse + write 256 KiB of ANSI-colored ASCII — runs of ASCII between SGR escapes.
    func testVTParseAnsiColoredASCII256KiB() throws {
        try skipUnlessEnabled()
        let bytes = ansiAsciiStream(targetBytes: 256 * 1024)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
        printBenchmark("vt_parse_ansi_colored_ascii_256kib", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 120, rows: 40)
            term.feed(bytes)
        }
    }

    /// The run fast path on print-heavy ASCII. Compare against
    /// `testVTParseScalarBaselinePrintHeavyASCII` (same bytes, per-byte scalar path) to see the
    /// speedup directly — the run path is measurably faster here (scalar ≈ 1.3× the time, release).
    func testVTParseRunPathPrintHeavyASCII() throws {
        try skipUnlessEnabled()
        let bytes = wrapStream(targetBytes: 1024 * 1024)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 120, rows: 10_000)
            term.feed(bytes)
        }
        printBenchmark("vt_parse_run_path_print_heavy_ascii", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 120, rows: 10_000)
            term.feed(bytes)
        }
    }

    /// Baseline for `testVTParseRunPathPrintHeavyASCII`: identical input driven one byte at a time
    /// through the scalar path (no run batching), so the two measured averages bracket the win.
    func testVTParseScalarBaselinePrintHeavyASCII() throws {
        try skipUnlessEnabled()
        let bytes = wrapStream(targetBytes: 1024 * 1024)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 120, rows: 10_000)
            term.feedScalarwise(bytes)
        }
        printBenchmark("vt_parse_scalar_baseline_print_heavy_ascii", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 120, rows: 10_000)
            term.feedScalarwise(bytes)
        }
    }

    // MARK: - readGrid snapshot cost (per-frame, per attached compositor client)

    func testReadGridSnapshotFullScreen() throws {
        try skipUnlessEnabled()
        let term = HarnessGridTerminal(cols: 200, rows: 60)!
        term.feed(syntheticStream(targetBytes: 128 * 1024))
        let nanos = timedNanos {
            for _ in 0 ..< 40 { _ = term.readGrid() }
        }
        printBenchmark("read_grid_snapshot_full_screen", nanos: nanos, fields: [("cells", "\(200 * 60 * 40)")])
        measure {
            for _ in 0 ..< 40 { _ = term.readGrid() }
        }
    }

    // MARK: - Scrollback append + replay (steady state, at the cap)

    func testScrollbackSteadyStateAtCap() throws {
        try skipUnlessEnabled()
        // Feed well past the scrollback cap so eviction runs on most lines — the steady-state
        // hot path for a long-running shell. With amortized batch eviction this is ~O(1)/line;
        // a regression to per-line front-removal would be O(cap)/line and blow up here.
        var lines = ""
        for i in 0 ..< 6_000 { lines += "scrollback row \(i) with some trailing content\r\n" }
        let bytes = Array(lines.utf8)
        let nanos = timedNanos {
            let term = TerminalEmulator(cols: 80, rows: 24)
            term.maxScrollbackLines = 1_000
            term.feed(bytes)
            _ = term.readGrid(scrollbackOffset: 500)
        }
        printBenchmark("scrollback_steady_state_at_cap", nanos: nanos, fields: [("bytes", "\(bytes.count)")])
        measure {
            let term = TerminalEmulator(cols: 80, rows: 24)
            term.maxScrollbackLines = 1_000
            term.feed(bytes)
            _ = term.readGrid(scrollbackOffset: 500)
        }
    }

    // MARK: - IPC codec round trip (large capture-pane / sendData payload)

    func testIPCCodecRoundTrip4MiB() throws {
        try skipUnlessEnabled()
        let payload = Data(repeating: 0x41, count: 4 * 1024 * 1024)
        let envelope = IPCEnvelope(request: .sendData(surfaceID: UUID().uuidString, data: payload))
        let nanos = timedNanos {
            guard var framed = try? IPCCodec.encode(envelope) else { return XCTFail("encode") }
            _ = try? IPCCodec.decodeRequest(from: &framed)
        }
        printBenchmark("ipc_codec_round_trip_4mib", nanos: nanos, fields: [("bytes", "\(payload.count)")])
        measure {
            guard var framed = try? IPCCodec.encode(envelope) else { return XCTFail("encode") }
            _ = try? IPCCodec.decodeRequest(from: &framed)
        }
    }

    // MARK: - Compositor frame build (split layout → diffed ANSI)

    func testCompositorFrameBuildFourPanes() throws {
        try skipUnlessEnabled()
        func snapshot(_ cols: Int, _ rows: Int) -> TerminalGridSnapshot {
            let t = HarnessGridTerminal(cols: cols, rows: rows)!
            t.feed("\u{1b}[32mpane content\u{1b}[0m\r\n" + String(repeating: "x", count: cols * 2))
            return t.readGrid()!
        }
        let comp = GridCompositor(cols: 160, rows: 48)
        let g = snapshot(79, 23)
        let panes = [
            CompositorPane(rect: PaneRect(paneID: UUID(), surfaceID: UUID(), x: 0, y: 0, cols: 79, rows: 23), grid: g, isActive: true),
            CompositorPane(rect: PaneRect(paneID: UUID(), surfaceID: UUID(), x: 81, y: 0, cols: 79, rows: 23), grid: g, isActive: false),
            CompositorPane(rect: PaneRect(paneID: UUID(), surfaceID: UUID(), x: 0, y: 25, cols: 79, rows: 23), grid: g, isActive: false),
            CompositorPane(rect: PaneRect(paneID: UUID(), surfaceID: UUID(), x: 81, y: 25, cols: 79, rows: 23), grid: g, isActive: false),
        ]
        let nanos = timedNanos {
            for i in 0 ..< 40 {
                comp.invalidate()
                _ = comp.render(panes: panes, status: "harness · bench \(i)")
            }
        }
        printBenchmark("compositor_frame_build_four_panes", nanos: nanos, fields: [("panes", "4"), ("frames", "40")])
        measure {
            for i in 0 ..< 40 {
                comp.invalidate() // force a full frame, not a no-op diff
                _ = comp.render(panes: panes, status: "harness · bench \(i)")
            }
        }
    }

    // MARK: - Frame builder and renderer stats

    private func runFrameBuildBenchmark(name: String, cols: Int, rows: Int) throws {
        try skipUnlessEnabled()
        let snapshot = filledSnapshot(cols: cols, rows: rows)
        let builder = FrameBuilder(theme: theme)
        let nanos = timedNanos {
            _ = builder.build(snapshot)
        }
        printBenchmark(name, nanos: nanos, fields: [("cells", "\(cols * rows)")])
        measure {
            _ = builder.build(snapshot)
        }
    }

    func testBuildFrame80x24() throws {
        try runFrameBuildBenchmark(name: "build_frame_80x24", cols: 80, rows: 24)
    }

    func testBuildFrame160x48() throws {
        try runFrameBuildBenchmark(name: "build_frame_160x48", cols: 160, rows: 48)
    }

    func testBuildFrame240x80() throws {
        try runFrameBuildBenchmark(name: "build_frame_240x80", cols: 240, rows: 80)
    }

    func testRenderEncodeStats160x48() throws {
        try skipUnlessEnabled()
        let device = try makeMetalDevice()
        let renderer = try XCTUnwrap(
            TerminalMetalRenderer(device: device, fontFamily: "Menlo", fontSize: 14, scale: 2),
            "TerminalMetalRenderer failed to build"
        )
        let frame = frame(cols: 160, rows: 48)
        let size = renderer.surfacePixelSize(columns: 160, rows: 48)
        let target = try XCTUnwrap(makeTarget(device, width: size.width, height: size.height), "no texture")

        let stats = encodeAndWait(renderer: renderer, frame: frame, target: target)
        printBenchmark(
            "render_encode_stats_160x48",
            nanos: stats.encodeNanos,
            fields: [
                ("cells", "\(stats.cells)"),
                ("bgInstances", "\(stats.bgInstances)"),
                ("bgSpans", "\(stats.bgSpans)"),
                ("bgCells", "\(stats.bgCells)"),
                ("glyphInstances", "\(stats.glyphInstances)"),
                ("decoInstances", "\(stats.decoInstances)"),
                ("imageInstances", "\(stats.imageInstances)"),
                ("atlasPages", "\(stats.atlasPages)"),
            ]
        )
        measure {
            encodeAndWait(renderer: renderer, frame: frame, target: target)
        }
    }

    // MARK: - Glyph atlas cache

    func testGlyphAtlasASCIIWarmPath() throws {
        try skipUnlessEnabled()
        let device = try makeMetalDevice()
        let atlas = try makeAtlas(device: device)
        let keys = (33 ... 126).map { GlyphKey(codepoint: UInt32($0), bold: false, italic: false) }
        for key in keys { _ = atlas.entry(for: key) }

        let before = atlas.stats
        let nanos = timedNanos {
            for _ in 0 ..< 200 {
                for key in keys { _ = atlas.entry(for: key) }
            }
        }
        let after = atlas.stats
        printBenchmark(
            "glyph_atlas_ascii_warm_path",
            nanos: nanos,
            fields: [
                ("entries", "\(after.entries)"),
                ("hits", "\(after.hits - before.hits)"),
                ("misses", "\(after.misses - before.misses)"),
                ("pages", "\(after.pages)"),
            ]
        )
        measure {
            for _ in 0 ..< 200 {
                for key in keys { _ = atlas.entry(for: key) }
            }
        }
    }

    func testGlyphAtlasMixedUnicodePath() throws {
        try skipUnlessEnabled()
        let device = try makeMetalDevice()
        let rasterizer = GlyphRasterizer(fontFamily: "Menlo", size: 14, scale: 2)
        let keys = "AéΩ世Ж中λ✓".unicodeScalars.map {
            GlyphKey(codepoint: $0.value, bold: false, italic: false)
        }
        func runLookups(_ atlas: GlyphAtlas) {
            for key in keys { _ = atlas.entry(for: key) }
            for key in keys { _ = atlas.entry(for: key) }
        }

        let atlas = try makeAtlas(device: device, rasterizer: rasterizer)
        let before = atlas.stats
        let nanos = timedNanos {
            runLookups(atlas)
        }
        let after = atlas.stats
        printBenchmark(
            "glyph_atlas_mixed_unicode_path",
            nanos: nanos,
            fields: [
                ("entries", "\(after.entries)"),
                ("hits", "\(after.hits - before.hits)"),
                ("misses", "\(after.misses - before.misses)"),
                ("pages", "\(after.pages)"),
            ]
        )
        measure {
            guard let atlas = GlyphAtlas(device: device, rasterizer: rasterizer) else {
                return XCTFail("GlyphAtlas failed to build")
            }
            runLookups(atlas)
        }
    }
}
