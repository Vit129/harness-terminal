import SwiftUI
import KouenCore
import KouenSettings
import KouenTerminalKit

/// Observable bridge between KouenSettings (value type) and SwiftUI views.
/// Reads from SessionCoordinator on every snapshot notification; writes through
/// the same coordinator so the live surfaces update exactly as the AppKit VC did.
@Observable @MainActor
final class SettingsModel {
    var settings: KouenSettings = SessionCoordinator.shared.settings
    var keepSessions: Bool = SessionCoordinator.shared.snapshot.keepSessionsOnQuit
    var currentThemeName: String = SessionCoordinator.shared.snapshot.themeName
    let themeNames: [String] = ThemeManager.allThemeNames()

    @ObservationIgnored
    nonisolated(unsafe) private var snapshotObserver: Any?

    init() {
        snapshotObserver = NotificationCenter.default.addObserver(
            forName: NotificationBus.shared.snapshotChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let hasPayload = note.userInfo?["payload"] is SnapshotChangedPayload
            Task { @MainActor in
                guard let self, hasPayload else { return }
                self.settings = SessionCoordinator.shared.settings
                self.keepSessions = SessionCoordinator.shared.snapshot.keepSessionsOnQuit
                self.currentThemeName = SessionCoordinator.shared.snapshot.themeName
            }
        }
    }

    deinit {
        if let snapshotObserver {
            NotificationCenter.default.removeObserver(snapshotObserver)
        }
    }

    /// Write a single KouenSettings field, persist to disk, and apply to live terminals.
    func update<T>(_ keyPath: WritableKeyPath<KouenSettings, T>, _ value: T) {
        SessionCoordinator.shared.settings[keyPath: keyPath] = value
        try? SessionCoordinator.shared.settings.save()
        SessionCoordinator.shared.applySettingsToHosts()
        settings = SessionCoordinator.shared.settings
    }

    func setKeepSessions(_ keep: Bool) {
        SessionCoordinator.shared.requestDaemon(.setKeepSessionsOnQuit(keep))
        keepSessions = keep
    }

    func setTheme(_ name: String) {
        SessionCoordinator.shared.setTheme(name)
    }

    func useThemeColors() {
        SessionCoordinator.shared.setTheme(currentThemeName)
    }

    func resetToDefaults() {
        SessionCoordinator.shared.settings.resetToImportedConfig(imported: TerminalConfigImporter.load())
        try? SessionCoordinator.shared.settings.save()
        SessionCoordinator.shared.applySettingsToHosts()
        settings = SessionCoordinator.shared.settings
    }
}
