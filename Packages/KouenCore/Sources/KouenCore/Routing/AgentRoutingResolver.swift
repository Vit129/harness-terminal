import Foundation
import KouenIPC
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Resolves `agent: "auto"` to a concrete `AgentKind` at spawn time. Pure function, no
/// I/O — callers (`kouenSpawnAgent`, Automation fire) pass in the already-loaded rule list.
/// Two-phase, first-match-wins within each phase:
///   1. Repo-path glob rules (`kind == .path`), ascending `order`.
///   2. `SignalFileRouter`-detected stack rules (`kind == .stack`), ascending `order` —
///      only consulted if no path rule matched.
///   3. `defaultAgent` — no rule matched.
public enum AgentRoutingResolver {
    public static func resolve(
        cwd: String?, rules: [AgentRoutingRule], defaultAgent: AgentKind
    ) -> AgentKind {
        guard let cwd else { return defaultAgent }
        let enabled = rules.filter(\.enabled)

        let pathRules = enabled.filter { $0.kind == .path }.sorted { $0.order < $1.order }
        for rule in pathRules {
            let pattern = (rule.pattern as NSString).expandingTildeInPath
            if fnmatch(pattern, cwd, 0) == 0 { return rule.targetAgent }
        }

        if let profile = SignalFileRouter.detectProfile(at: cwd) {
            let stackRules = enabled.filter { $0.kind == .stack }.sorted { $0.order < $1.order }
            for rule in stackRules where rule.pattern == profile.stack {
                return rule.targetAgent
            }
        }

        return defaultAgent
    }
}
