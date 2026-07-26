import Foundation

/// The distinct events Kouen can raise a desktop notification for. This is the single
/// source of truth for the user-facing "which events notify me" list: the Settings UI
/// builds one toggle per case, and `SessionCoordinator` gates each banner on the matching
/// case via `KouenSettings.isEventEnabled(_:)`. Add a case here and a new, fully wired
/// toggle appears — no scattered edits.
///
/// `rawValue` is the persisted key in `KouenSettings.notificationEvents`, so the spellings
/// below are part of the on-disk format — don't rename them without a migration.
public enum NotificationEvent: String, CaseIterable, Codable, Sendable {
    /// An agent asked for approval or is otherwise waiting on the user (the explicit
    /// `kouen-cli notify` path and tabs that transition to `.waiting`).
    case agentWaiting
    /// A detected agent stopped producing output (the working → idle/awaiting edge).
    case agentFinished
    /// A program rang the terminal bell (`\a`).
    case bell
    /// A foreground command that ran past `commandFinishedThresholdSeconds` finished in a
    /// pane the user wasn't watching.
    case commandFinished

    /// Settings-row label.
    public var title: String {
        switch self {
        case .agentWaiting: return "Agent needs input"
        case .agentFinished: return "Agent finished"
        case .bell: return "Terminal bell"
        case .commandFinished: return "Command finished"
        }
    }

    /// Settings-row hint shown under the label.
    public var detail: String {
        switch self {
        case .agentWaiting: return "When an agent asks for approval or is waiting on you."
        case .agentFinished: return "When a detected agent stops producing output."
        case .bell: return "When a program rings the terminal bell."
        case .commandFinished: return "When a long command finishes in a background pane."
        }
    }

    /// Default when the user hasn't made an explicit choice. Mirrors the pre-existing
    /// behavior: agent/bell events were on by default; command-finished was opt-in.
    public var defaultEnabled: Bool {
        switch self {
        case .agentWaiting, .agentFinished, .bell: return true
        case .commandFinished: return false
        }
    }

    /// Named system sound (`/System/Library/Sounds/*.aiff`, resolved by `NSSound(named:)` —
    /// no bundled asset needed) played for this event, distinct per case so the user can
    /// tell "agent needs you" apart from "agent finished" without looking. `agentWaiting` is
    /// deliberately the sharpest/most attention-grabbing since it's the one actionable case.
    public var soundName: String {
        switch self {
        case .agentWaiting: return "Ping"
        case .agentFinished: return "Glass"
        case .bell: return "Tink"
        case .commandFinished: return "Pop"
        }
    }
}
