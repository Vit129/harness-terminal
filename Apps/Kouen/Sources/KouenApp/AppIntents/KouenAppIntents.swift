import AppIntents
import Foundation
import KouenCore

/// P8 Phase 7: expose core terminal control to the system Shortcuts app / Siri.
/// Runs in-process (no separate App Intents extension target) — `perform()` talks to
/// whichever of `SessionCoordinator.shared` (already-existing high-level coordinator
/// methods, when one exists) or `DaemonClient` (same lightweight IPC client `kouen-cli`
/// itself uses, for capabilities with no existing Swift-level helper) is the more direct
/// path, rather than inventing a second way to do something the app already does.

@available(macOS 13.0, *)
struct KouenShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: ["Run a command in \(.applicationName)"],
            shortTitle: "Run Command",
            systemImageName: "terminal"
        )
        AppShortcut(
            intent: SplitPaneIntent(),
            phrases: ["Split the pane in \(.applicationName)"],
            shortTitle: "Split Pane",
            systemImageName: "rectangle.split.2x1"
        )
        AppShortcut(
            intent: SwitchWorkspaceIntent(),
            phrases: ["Switch workspace in \(.applicationName)"],
            shortTitle: "Switch Workspace",
            systemImageName: "rectangle.stack"
        )
        AppShortcut(
            intent: GetTerminalOutputIntent(),
            phrases: ["Get terminal output from \(.applicationName)"],
            shortTitle: "Get Terminal Output",
            systemImageName: "text.alignleft"
        )
    }
}

/// Shared by every intent below: the daemon-tracked surface for whatever pane the GUI
/// currently considers active. Intents intentionally don't accept a raw pane-ID parameter
/// (Shortcuts has no sensible picker for one, and the active pane is what "run a command"
/// means in every other Kouen entry point — menu items, keyboard shortcuts, the notch).
@available(macOS 13.0, *)
@MainActor
private func requireActiveSurfaceID() throws -> SurfaceID {
    guard let id = SessionCoordinator.shared.activeSurfaceID else {
        throw KouenIntentError.noActivePane
    }
    return id
}

@available(macOS 13.0, *)
enum KouenIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case noActivePane
    case workspaceNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActivePane:
            return "Kouen has no active terminal pane right now."
        case .workspaceNotFound(let name):
            return "No Kouen workspace named \"\(name)\"."
        }
    }
}

@available(macOS 13.0, *)
struct RunCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Command"
    static let description = IntentDescription("Runs a shell command in Kouen's active terminal pane.")

    @Parameter(title: "Command")
    var command: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let surfaceID = try requireActiveSurfaceID()
        guard let host = SessionCoordinator.shared.terminalHostIfExists(for: surfaceID) else {
            throw KouenIntentError.noActivePane
        }
        host.sendInput(Data((command + "\n").utf8))
        return .result()
    }
}

@available(macOS 13.0, *)
enum SplitDirectionAppEnum: String, AppEnum {
    case horizontal
    case vertical

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Split Direction"
    static let caseDisplayRepresentations: [SplitDirectionAppEnum: DisplayRepresentation] = [
        .horizontal: "Horizontal",
        .vertical: "Vertical",
    ]

    var ipcDirection: SplitDirection {
        switch self {
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        }
    }
}

@available(macOS 13.0, *)
struct SplitPaneIntent: AppIntent {
    static let title: LocalizedStringResource = "Split Pane"
    static let description = IntentDescription("Splits Kouen's active pane, optionally running a command in the new one.")

    @Parameter(title: "Direction", default: .vertical)
    var direction: SplitDirectionAppEnum

    @Parameter(title: "Command", description: "Command to run in the new pane, if any.")
    var command: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try requireActiveSurfaceID() // fail fast with the same "no active pane" error
        let coordinator = SessionCoordinator.shared
        if let command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coordinator.splitActivePaneAndRun(direction: direction.ipcDirection, command: command)
        } else {
            coordinator.splitActivePane(direction: direction.ipcDirection)
        }
        return .result()
    }
}

@available(macOS 13.0, *)
struct SwitchWorkspaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Workspace"
    static let description = IntentDescription("Switches Kouen to the workspace with the given name.")

    @Parameter(title: "Workspace Name")
    var workspaceName: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let coordinator = SessionCoordinator.shared
        guard let workspace = coordinator.snapshot.workspaces.first(where: {
            $0.name.compare(workspaceName, options: .caseInsensitive) == .orderedSame
        }) else {
            throw KouenIntentError.workspaceNotFound(workspaceName)
        }
        coordinator.selectWorkspace(workspace.id)
        return .result()
    }
}

@available(macOS 13.0, *)
struct GetTerminalOutputIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Terminal Output"
    static let description = IntentDescription("Returns the visible text of Kouen's active terminal pane.")

    @Parameter(title: "Include Scrollback", default: false)
    var includeScrollback: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let surfaceID = try await MainActor.run { try requireActiveSurfaceID() }
        let response = try DaemonClient().request(
            .capturePane(surfaceID: surfaceID.uuidString, includeScrollback: includeScrollback)
        )
        guard case let .text(text) = response else {
            return .result(value: "")
        }
        return .result(value: text)
    }
}
