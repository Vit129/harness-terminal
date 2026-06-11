import Foundation
import XCTest
@testable import HarnessTerminalEngine

/// OSC 133 command-duration timing that drives the "long command finished in a background window"
/// notification: the `C`/`B` mark starts the clock, `D` fires `onCommandFinished` with the elapsed
/// time + exit code. An `A`→`D` sequence with no command in between must not fire.
final class CommandFinishedTests: XCTestCase {
    func testFiresAfterCommandRunsWithExitCode() {
        let term = TerminalEmulator(cols: 20, rows: 4)
        var fired: (duration: TimeInterval, exit: Int?)?
        term.onCommandFinished = { fired = ($0, $1) }
        term.feed("\u{1b}]133;A\u{07}")    // prompt start
        term.feed("\u{1b}]133;C\u{07}")    // command output start (clock starts)
        term.feed("\u{1b}]133;D;0\u{07}")  // command finished, exit 0
        XCTAssertNotNil(fired)
        XCTAssertEqual(fired?.exit, 0)
        XCTAssertGreaterThanOrEqual(fired?.duration ?? -1, 0)
    }

    func testDoesNotFireForPromptWithNoCommand() {
        let term = TerminalEmulator(cols: 20, rows: 4)
        var fired = false
        term.onCommandFinished = { _, _ in fired = true }
        term.feed("\u{1b}]133;A\u{07}")   // prompt start
        term.feed("\u{1b}]133;D\u{07}")   // finished with no C/B (e.g. an empty Enter)
        XCTAssertFalse(fired)
    }

    func testReportsNonZeroExitCode() {
        let term = TerminalEmulator(cols: 20, rows: 4)
        var fired: (duration: TimeInterval, exit: Int?)?
        term.onCommandFinished = { fired = ($0, $1) }
        term.feed("\u{1b}]133;A\u{07}")
        term.feed("\u{1b}]133;C\u{07}")
        term.feed("\u{1b}]133;D;1\u{07}")
        XCTAssertEqual(fired?.exit, 1)
    }

    func testFullResetAbandonsInFlightCommandTiming() {
        let term = TerminalEmulator(cols: 20, rows: 4)
        var fired = false
        term.onCommandFinished = { _, _ in fired = true }
        term.feed("\u{1b}]133;C\u{07}") // command clock starts
        term.feed("\u{1b}c")             // RIS full reset
        term.feed("\u{1b}]133;D;0\u{07}")
        XCTAssertFalse(fired, "RIS must abandon the in-flight command clock")
    }

    func testNewPromptResetsTimerSoStaleCommandDoesNotFire() {
        // A fresh prompt (A) after a command must clear the clock, so a subsequent D with no new
        // C/B (an empty Enter) does not report the previous command again.
        let term = TerminalEmulator(cols: 20, rows: 4)
        var fireCount = 0
        term.onCommandFinished = { _, _ in fireCount += 1 }
        term.feed("\u{1b}]133;A\u{07}")
        term.feed("\u{1b}]133;C\u{07}")
        term.feed("\u{1b}]133;D;0\u{07}") // fires once
        term.feed("\u{1b}]133;A\u{07}")   // new prompt, clock cleared
        term.feed("\u{1b}]133;D;0\u{07}") // empty Enter — must not fire
        XCTAssertEqual(fireCount, 1)
    }

    func testCommandFinishedResetsTransientInputModes() {
        let term = TerminalEmulator(cols: 20, rows: 4)
        term.feed("\u{1b}]133;C\u{07}")
        term.feed("\u{1b}[?1000;1002;1003;1005;1006;1004;2004;2026;1h")
        term.feed("\u{1b}[>4;2m")
        term.feed("\u{1b}[>8u")
        term.feed("\u{1b}=")

        XCTAssertTrue(term.modes.mouseTrackingEnabled)
        XCTAssertTrue(term.modes.mouseSGR)
        XCTAssertTrue(term.modes.bracketedPaste)
        XCTAssertTrue(term.modes.focusReporting)
        XCTAssertTrue(term.modes.synchronizedOutput)
        XCTAssertEqual(term.modes.modifyOtherKeys, 2)
        XCTAssertEqual(term.modes.kittyKeyboardFlags, 8)
        XCTAssertTrue(term.modes.keypadApplication)

        term.feed("\u{1b}]133;D;0\u{07}")

        XCTAssertEqual(term.modes, TerminalModes())
    }
}
