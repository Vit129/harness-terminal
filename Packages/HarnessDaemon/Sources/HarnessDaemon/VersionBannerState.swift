import Foundation
import HarnessCore

/// Which one-shot banner the next freshly created surface should show.
enum PendingVersionBanner: Equatable {
    /// First run on this machine — no prior layout and no version state.
    case welcome
    /// The build bumped since the last shown banner (or the state predates the feature).
    case whatsNew
}

/// Persistence + policy for the one-shot first-run / post-update terminal banner.
/// `version-state.json` records the last build whose banner was shown; `SurfaceRegistry`
/// consumes the pending banner on the first *user-created* surface (new tab/session/split/
/// `createSurface`) — never on a boot restore, so existing panes are never spammed after a
/// daemon restart.
struct VersionBannerStore {
    let url: URL

    init(url: URL = HarnessPaths.versionStateURL) {
        self.url = url
    }

    private struct State: Codable {
        var lastSeenBuild: Int
        var lastSeenVersion: String
    }

    /// nil for a missing or unreadable file — `decidePending` treats both as "never shown".
    func loadLastSeenBuild() -> Int? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(State.self, from: data))?.lastSeenBuild
    }

    /// Returns whether the ack reached disk — a false return means the banner decision
    /// would replay on the next daemon start, so the caller schedules a retry.
    @discardableResult
    func markSeen(build: Int = HarnessVersion.build, version: String = HarnessVersion.short) -> Bool {
        guard let data = try? JSONEncoder().encode(State(lastSeenBuild: build, lastSeenVersion: version)) else {
            return false
        }
        return HarnessPaths.atomicWrite(data, to: url, label: "version-state")
    }

    static func decidePending(
        lastSeenBuild: Int?,
        currentBuild: Int,
        hadExistingLayout: Bool
    ) -> PendingVersionBanner? {
        guard let lastSeenBuild else {
            // No state: a fresh machine gets the welcome; an existing layout means the
            // user updated from a build that predates the banner — show what's new.
            return hadExistingLayout ? .whatsNew : .welcome
        }
        return lastSeenBuild < currentBuild ? .whatsNew : nil
    }
}
