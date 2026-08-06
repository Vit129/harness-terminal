import Foundation

/// Lightweight wrapper around the `gh` CLI for PR and CI status queries.
/// Requires `gh` to be installed and authenticated.
public struct GitHubCLIClient: Sendable {
    public init() {}

    // MARK: - Availability

    /// Returns true if `gh` is installed and authenticated.
    public func isAvailable() -> Bool {
        runGH(["auth", "status"]) != nil
    }

    // MARK: - PR

    public struct PRInfo: Sendable, Equatable {
        public let number: Int
        public let title: String
        public let state: PRState
        public let url: String
        public let headRefName: String
        public let baseRefName: String
        public let isDraft: Bool
        public let checksStatus: ChecksStatus
        /// `true` only when GitHub reports the PR as cleanly mergeable (`"MERGEABLE"`) — `false`
        /// for conflicts or while GitHub is still computing the merge state (`"UNKNOWN"`). P39
        /// G3's merge action gates on this: never offer to merge something GitHub itself hasn't
        /// confirmed is clean.
        public let mergeable: Bool
        /// GitHub's `reviewDecision`: `"APPROVED"`, `"CHANGES_REQUESTED"`, `"REVIEW_REQUIRED"`,
        /// or `nil` when no review is configured/recorded. M8: a maintainer-approved PR can
        /// waive the checks-must-pass merge gate (see `SidebarSessionListView.mergePR`) —
        /// `mergeable` (no conflicts) is never waived, only the checks-status requirement.
        public let reviewDecision: String?
    }

    public enum PRState: String, Sendable, Equatable {
        case open = "OPEN"
        case closed = "CLOSED"
        case merged = "MERGED"
    }

    public enum ChecksStatus: String, Sendable, Equatable {
        case pass = "pass"
        case fail = "fail"
        case pending = "pending"
        case none = "none"
    }

    /// Get PR info for the current branch in the given repo directory.
    public func prForCurrentBranch(repoPath: String) -> PRInfo? {
        let fields = "number,title,state,url,headRefName,baseRefName,isDraft,statusCheckRollup,mergeable,reviewDecision"
        guard let output = runGH(
            ["pr", "view", "--json", fields],
            in: repoPath
        ) else { return nil }
        return parsePRInfo(output)
    }

    // MARK: - CI Runs

    public struct CIRun: Sendable, Equatable {
        public let id: Int
        public let name: String
        public let status: String       // "completed", "in_progress", "queued"
        public let conclusion: String?  // "success", "failure", "cancelled", nil
        public let url: String
    }

    /// List recent CI runs for the current branch.
    public func ciRuns(repoPath: String, limit: Int = 5) -> [CIRun] {
        guard let output = runGH(
            ["run", "list", "--json", "databaseId,name,status,conclusion,url", "--limit", "\(limit)"],
            in: repoPath
        ) else { return [] }
        return parseCIRuns(output)
    }

    // MARK: - Actions

    /// Re-run failed jobs for a given run ID.
    @discardableResult
    public func rerunFailed(repoPath: String, runID: Int) -> Bool {
        runGH(["run", "rerun", "\(runID)", "--failed"], in: repoPath) != nil
    }

    // MARK: - Merge (P39 G3)

    public enum MergeMethod: Sendable {
        case squash, rebase, merge

        var flag: String {
            switch self {
            case .squash: return "--squash"
            case .rebase: return "--rebase"
            case .merge: return "--merge"
            }
        }
    }

    public struct MergeResult: Sendable, Equatable {
        public let success: Bool
        public let errorMessage: String?
    }

    /// Merges `prNumber` with an explicitly-chosen method. No default method — every caller must
    /// pass one; there is deliberately no "just merge however gh feels like today" entry point.
    /// `gh pr merge` itself refuses on branch protection / merge conflicts, which is the only
    /// safety backstop this needs — no app-side force option, ever.
    public func merge(repoPath: String, prNumber: Int, method: MergeMethod) -> MergeResult {
        guard let ghPath = Self.cachedGhPath else {
            return MergeResult(success: false, errorMessage: "gh CLI not found")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["pr", "merge", "\(prNumber)", method.flag, "--delete-branch=false"]
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return MergeResult(success: true, errorMessage: nil)
            }
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return MergeResult(success: false, errorMessage: (message?.isEmpty ?? true) ? "gh pr merge failed" : message)
        } catch {
            return MergeResult(success: false, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Issues

    public struct IssueInfo: Sendable, Equatable {
        public let title: String
        public let body: String
    }

    /// Fetch an issue's title/body from `repoSpec` (`org/repo`), for seeding a `wake`-launched
    /// agent's initial prompt. No `repoPath` needed — `-R` lets `gh` resolve the repo remotely.
    public func issue(repoSpec: String, number: Int) -> IssueInfo? {
        guard let output = runGH(["issue", "view", "\(number)", "-R", repoSpec, "--json", "title,body"])
        else { return nil }
        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = object["title"] as? String
        else { return nil }
        return IssueInfo(title: title, body: object["body"] as? String ?? "")
    }

    // MARK: - Clone

    /// Clones `repoSpec` (`org/repo`) to `destination` via `gh repo clone`. `destination`'s parent
    /// directory must already exist — `gh`/`git` won't create intermediate directories.
    @discardableResult
    public func cloneRepo(repoSpec: String, to destination: String) -> Bool {
        guard let ghPath = Self.cachedGhPath else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["repo", "clone", repoSpec, destination]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch { return false }
    }

    // MARK: - Private

    /// Resolve gh path: prefer the common Homebrew/system locations; fall back to `which gh`
    /// for non-standard installs (MacPorts, asdf/mise shims, etc.) — callers elsewhere (e.g.
    /// `SidebarListModel.cachedGhPath`) already probe availability with this same fallback, so
    /// this must match or the availability check and the actual fetch can silently disagree.
    private static let cachedGhPath: String? = {
        let paths = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        if let found = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return found
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gh"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty, FileManager.default.fileExists(atPath: path)
            else { return nil }
            return path
        } catch { return nil }
    }()

    private func runGH(_ args: [String], in directory: String? = nil) -> String? {
        let process = Process()
        let pipe = Pipe()
        guard let ghPath = Self.cachedGhPath else {
            return nil
        }
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = args
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
        }
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }

    /// Not private: exercised directly by `GitHubCLIClientTests` against a JSON fixture, since
    /// `prForCurrentBranch` itself depends on a real `gh` CLI + network and can't be unit tested.
    func parsePRInfo(_ json: String) -> PRInfo? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = obj["number"] as? Int,
              let title = obj["title"] as? String,
              let stateStr = obj["state"] as? String,
              let url = obj["url"] as? String,
              let headRef = obj["headRefName"] as? String
        else { return nil }

        let state = PRState(rawValue: stateStr) ?? .open
        let isDraft = obj["isDraft"] as? Bool ?? false
        let checksStatus = parseChecksStatus(obj["statusCheckRollup"])
        let baseRef = obj["baseRefName"] as? String ?? ""
        let mergeable = (obj["mergeable"] as? String) == "MERGEABLE"
        // gh CLI reports an empty string, not JSON null, when no review decision exists yet.
        let reviewDecision = (obj["reviewDecision"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return PRInfo(
            number: number, title: title, state: state, url: url,
            headRefName: headRef, baseRefName: baseRef, isDraft: isDraft,
            checksStatus: checksStatus, mergeable: mergeable, reviewDecision: reviewDecision
        )
    }

    private func parseChecksStatus(_ rollup: Any?) -> ChecksStatus {
        guard let checks = rollup as? [[String: Any]], !checks.isEmpty else {
            return .none
        }
        let hasFailure = checks.contains { ($0["conclusion"] as? String) == "FAILURE" }
        if hasFailure { return .fail }
        let allDone = checks.allSatisfy { ($0["status"] as? String) == "COMPLETED" }
        if allDone { return .pass }
        return .pending
    }

    private func parseCIRuns(_ json: String) -> [CIRun] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return arr.compactMap { obj in
            guard let id = obj["databaseId"] as? Int,
                  let name = obj["name"] as? String,
                  let status = obj["status"] as? String,
                  let url = obj["url"] as? String
            else { return nil }
            return CIRun(id: id, name: name, status: status, conclusion: obj["conclusion"] as? String, url: url)
        }
    }
}
