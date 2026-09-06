import XCTest
@testable import KouenCore

final class ExperienceModeTests: XCTestCase {
    func testFreshInstallDefaultsToPlain() {
        // The memberwise init is the fresh-install path (via makeDefaults). New users get the
        // simplest experience — a fast native terminal.
        XCTAssertEqual(KouenSettings().experienceMode, .plain)
        XCTAssertNil(KouenSettings().kouenControlsEnabled)
    }

    func testLegacyFileWithoutModeMigratesToFull() throws {
        // A settings file written before modes existed belongs to a user who already had the
        // prefix + status line. Decoding must default the absent key to `.full` so upgrading
        // never strips features — NOT to the fresh-install `.plain`.
        let legacy = #"{"fontSize":16,"fontFamily":"Menlo","defaultShell":"/bin/zsh","defaultCWD":"/Users/x","transparentTitlebar":true,"sidebarVisible":true,"backgroundOpacity":0.6,"backgroundBlur":16,"windowPaddingX":14,"windowPaddingY":14,"prefixKey":"ctrl-a","scrollbackLines":10000,"cursorStyle":"block","cursorBlink":true,"copyOnSelect":true,"paletteHex":[null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null],"agentColorOverrides":{},"systemNotificationsEnabled":true,"notificationSoundEnabled":true,"vividColors":true,"linearBlending":false,"applyThemeToTerminalOutput":false,"ligatures":true,"showStatusLine":true}"#
        let settings = try JSONDecoder().decode(KouenSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(settings.experienceMode, .full)
        XCTAssertTrue(settings.showsKouenControls)
    }

    func testShowsKouenControlsDerivesFromMode() {
        XCTAssertFalse(KouenSettings(experienceMode: .plain).showsKouenControls)
        XCTAssertFalse(KouenSettings(experienceMode: .persistent).showsKouenControls)
        XCTAssertTrue(KouenSettings(experienceMode: .full).showsKouenControls)
        XCTAssertFalse(KouenSettings(experienceMode: .agent).showsKouenControls)
    }

    func testKouenControlsOverrideWinsOverMode() {
        // Persistent/Agent users can opt into the prefix + status line without leaving their mode.
        XCTAssertTrue(KouenSettings(experienceMode: .agent, kouenControlsEnabled: true).showsKouenControls)
        // …and a Full Terminal user can turn the controls off without switching modes.
        XCTAssertFalse(KouenSettings(experienceMode: .full, kouenControlsEnabled: false).showsKouenControls)
    }

    func testEffectivePrefixKey() {
        // Kouen controls hidden → no prefix at all, regardless of the stored key.
        XCTAssertNil(KouenSettings(prefixKey: "ctrl-a", experienceMode: .plain).effectivePrefixKey)
        // Kouen controls visible → honor the stored key.
        XCTAssertEqual(KouenSettings(prefixKey: "ctrl-b", experienceMode: .full).effectivePrefixKey, "ctrl-b")
        // Kouen controls visible but a blanked key → disabled (fixes the old fall-back-to-Ctrl-A bug).
        XCTAssertNil(KouenSettings(prefixKey: "", experienceMode: .full).effectivePrefixKey)
        XCTAssertNil(KouenSettings(prefixKey: "   ", experienceMode: .full).effectivePrefixKey)
    }

    func testPersistenceDefaultsByMode() {
        XCTAssertFalse(ExperienceMode.plain.persistsSessionsByDefault)
        XCTAssertTrue(ExperienceMode.persistent.persistsSessionsByDefault)
        XCTAssertTrue(ExperienceMode.full.persistsSessionsByDefault)
        XCTAssertTrue(ExperienceMode.agent.persistsSessionsByDefault)
    }

    func testModeSurvivesEncodeDecodeRoundTrip() throws {
        var settings = KouenSettings(experienceMode: .agent, kouenControlsEnabled: true)
        settings.prefixKey = "ctrl-b"
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(KouenSettings.self, from: data)
        XCTAssertEqual(decoded.experienceMode, .agent)
        XCTAssertEqual(decoded.kouenControlsEnabled, true)
    }

    func testLegacyTmuxControlsKeyDecodesIntoKouenControls() throws {
        let legacy = #"{"experienceMode":"agent","tmuxControlsEnabled":true}"#
        let decoded = try JSONDecoder().decode(KouenSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.experienceMode, .agent)
        XCTAssertEqual(decoded.kouenControlsEnabled, true)
        XCTAssertTrue(decoded.showsKouenControls)
    }

    func testResetToImportedConfigPreservesMode() {
        // "Reset to defaults" changes appearance, not behavior — the experience must stick.
        var settings = KouenSettings(experienceMode: .full)
        settings.resetToImportedConfig(imported: nil)
        XCTAssertEqual(settings.experienceMode, .full)
    }

    // MARK: - Per-component (decoupled) chrome overrides

    func testPerComponentDefaultsByMode() {
        // Prefix + status line default on only for Full; the notch defaults off for every mode.
        XCTAssertTrue(ExperienceMode.full.showsPrefixByDefault)
        XCTAssertTrue(ExperienceMode.full.showsStatusLineByDefault)
        XCTAssertFalse(ExperienceMode.plain.showsPrefixByDefault)
        XCTAssertFalse(ExperienceMode.plain.showsStatusLineByDefault)
        XCTAssertFalse(ExperienceMode.agent.notchEnabledByDefault)
        XCTAssertFalse(ExperienceMode.full.notchEnabledByDefault)
    }

    func testGranularOverridesDecouplePrefixFromStatusLine() {
        // A Plain terminal can show a status line without arming the prefix…
        let s = KouenSettings(experienceMode: .plain, statusLineEnabled: true)
        XCTAssertTrue(s.effectiveStatusLineEnabled)
        XCTAssertFalse(s.effectivePrefixKeyEnabled)
        XCTAssertNil(s.effectivePrefixKey)
        // …and a Full Terminal can drop the prefix while keeping the status line.
        let f = KouenSettings(experienceMode: .full, prefixKeyEnabled: false)
        XCTAssertFalse(f.effectivePrefixKeyEnabled)
        XCTAssertTrue(f.effectiveStatusLineEnabled)
    }

    func testGranularOverrideFallsBackToUmbrellaThenMode() {
        // nil granular → legacy umbrella → mode default. The umbrella lifts both components.
        let umbrella = KouenSettings(experienceMode: .agent, kouenControlsEnabled: true)
        XCTAssertTrue(umbrella.effectivePrefixKeyEnabled)
        XCTAssertTrue(umbrella.effectiveStatusLineEnabled)
        // A finer override beats the umbrella for just that component.
        let mixed = KouenSettings(experienceMode: .agent, kouenControlsEnabled: true, prefixKeyEnabled: false)
        XCTAssertFalse(mixed.effectivePrefixKeyEnabled)
        XCTAssertTrue(mixed.effectiveStatusLineEnabled)
    }

    func testGranularOverridesSurviveRoundTrip() throws {
        let settings = KouenSettings(experienceMode: .plain, prefixKeyEnabled: true, statusLineEnabled: false)
        let decoded = try JSONDecoder().decode(KouenSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.prefixKeyEnabled, true)
        XCTAssertEqual(decoded.statusLineEnabled, false)
        XCTAssertTrue(decoded.effectivePrefixKeyEnabled)
        XCTAssertFalse(decoded.effectiveStatusLineEnabled)
    }

    func testPlainModeWithNoExplicitToggleShowsStatusLine() throws {
        // Migration scenario: user on plain mode, never touched the status line toggle in the
        // new SwiftUI Settings panel → statusLineEnabled=nil, kouenControlsEnabled=nil.
        // Before 71e3c05 the chain fell to showsStatusLineByDefault=false and hid the band.
        // The fix falls back to showStatusLine (default true) so the band stays visible.
        let json = #"{"experienceMode":"plain","showStatusLine":true}"#
        let s = try JSONDecoder().decode(KouenSettings.self, from: Data(json.utf8))
        XCTAssertNil(s.statusLineEnabled)
        XCTAssertNil(s.kouenControlsEnabled)
        XCTAssertTrue(s.effectiveStatusLineEnabled, "plain mode + showStatusLine=true should show status line")
    }

    func testPlainModeWithExplicitlyDisabledLegacyToggleHidesStatusLine() throws {
        // If the user actively disabled showStatusLine under the old AppKit Settings, honour it.
        let json = #"{"experienceMode":"plain","showStatusLine":false}"#
        let s = try JSONDecoder().decode(KouenSettings.self, from: Data(json.utf8))
        XCTAssertFalse(s.effectiveStatusLineEnabled, "plain mode + showStatusLine=false should hide status line")
    }

    func testLegacyFileWithoutGranularOverridesPreservesBehavior() throws {
        // Older files have no prefixKeyEnabled/statusLineEnabled → nil, so behavior is preserved
        // through the umbrella fallback (umbrella off ⇒ both components off, even for Full).
        let legacy = #"{"experienceMode":"tmux","kouenControlsEnabled":false}"#
        let decoded = try JSONDecoder().decode(KouenSettings.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.prefixKeyEnabled)
        XCTAssertNil(decoded.statusLineEnabled)
        XCTAssertFalse(decoded.effectivePrefixKeyEnabled)
        XCTAssertFalse(decoded.effectiveStatusLineEnabled)
    }
}
