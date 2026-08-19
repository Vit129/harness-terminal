import AppKit
import KouenCore
import Observation

// MARK: - Shared types

struct RepoGitMetadata: Sendable, Equatable {
    let prNumber: Int?
    let prURL: String?
    let prTitle: String?
    let prBaseBranch: String?
    let prChecksStatus: GitHubCLIClient.ChecksStatus?
    /// `nil` when there's no PR at all; `false` covers both real conflicts and GitHub still
    /// computing merge state — P39 G3's merge action treats both the same (don't offer to merge).
    let prMergeable: Bool?
    /// M8: `"APPROVED"` lets `mergePR` offer a checks-waiver — `prMergeable` (no conflicts)
    /// is still always required, never waived.
    let prReviewDecision: String?
    let aheadCount: Int?
    let behindCount: Int?
}

enum SidebarSessionRow: Identifiable {
    case groupHeader(name: String, rootPath: String, count: Int, isCollapsed: Bool, status: BoardColumnKind)
    case session(SessionGroup)
    case worktreeHeader(rootPath: String, count: Int, isCollapsed: Bool)
    case worktree(SidebarWorktreeEntry, rootPath: String)
    case divider

    var id: String {
        switch self {
        case let .groupHeader(_, rootPath, _, _, _): "group-\(rootPath)"
        case let .session(s): "sess-\(s.id.uuidString)"
        case let .worktreeHeader(rootPath, _, _): "wth-\(rootPath)"
        case let .worktree(entry, _): "wt-\(entry.path)"
        case .divider: "divider"
        }
    }
}

struct SidebarWorktreeEntry: Sendable, Equatable, Hashable {
    let path: String
    let head: String
    let branch: String
    let isMain: Bool
    let isLocked: Bool
}

// MARK: - Observable model

@Observable @MainActor
final class SidebarListModel {
    var rows: [SidebarSessionRow] = []
    var activeSessionID: SessionID?
    var activeWorkspaceID: WorkspaceID?
    private(set) var sessions: [SessionGroup] = []
    private var isRebuilding = false

    var collapsedGroups = Set<String>()
    var collapsedWorktreeGroups = Set<String>() // tracks EXPANDED groups (inverted: default = collapsed)
    private(set) var projectWorktrees: [String: [SidebarWorktreeEntry]] = [:]
    var pinnedRepos: Set<String> = {
        let array = UserDefaults.standard.stringArray(forKey: "kouen.sidebar.pinnedRepos") ?? []
        return Set(array)
    }()

    private var repoRootCache: [String: (repoRoot: String?, fetchedAt: Date)] = [:]
    private var repoRootUpdatesInProgress: Set<String> = []
    // Stored as var so @Observable tracks mutations for badge re-renders
    @ObservationIgnored private var gitMetadataCache: [String: (metadata: RepoGitMetadata, fetchedAt: Date)] = [:]
    @ObservationIgnored private var gitMetadataUpdatesInProgress: Set<String> = []
    private var lastWorktreeFetchTime: [String: Date] = [:]
    @ObservationIgnored private var pendingRebuild: Task<Void, Never>?

    // MARK: - Main update

    func update(from snapshot: SessionSnapshot) {
        sessions = snapshot.activeWorkspace?.sessions ?? []
        activeSessionID = snapshot.activeWorkspace?.activeSessionID
        activeWorkspaceID = snapshot.activeWorkspaceID
        rebuildRows()
    }

    // MARK: - Collapse toggles

    func toggleCollapse(rootPath: String) {
        if collapsedGroups.contains(rootPath) {
            collapsedGroups.remove(rootPath)
        } else {
            collapsedGroups.insert(rootPath)
        }
        rebuildRows()
    }

    func togglePinRepo(rootPath: String) {
        if pinnedRepos.contains(rootPath) {
            pinnedRepos.remove(rootPath)
        } else {
            pinnedRepos.insert(rootPath)
        }
        UserDefaults.standard.set(Array(pinnedRepos), forKey: "kouen.sidebar.pinnedRepos")
        rebuildRows()
    }

    func toggleWorktreeCollapse(rootPath: String) {
        if collapsedWorktreeGroups.contains(rootPath) {
            collapsedWorktreeGroups.remove(rootPath)
        } else {
            collapsedWorktreeGroups.insert(rootPath)
        }
        rebuildRows()
    }

    // MARK: - Git metadata (badge data for session rows)

    func gitMetadata(forPath path: String, branch: String) -> RepoGitMetadata? {
        guard !branch.isEmpty else { return nil }
        let key = "\(path)|\(branch)"
        let now = Date()
        if let cached = gitMetadataCache[key], now.timeIntervalSince(cached.fetchedAt) < 60.0 {
            return cached.metadata
        }
        if gitMetadataUpdatesInProgress.insert(key).inserted {
            Task {
                let metadata = await self.fetchGitMetadata(for: path, branch: branch)
                self.gitMetadataCache[key] = (metadata: metadata, fetchedAt: Date())
                self.gitMetadataUpdatesInProgress.remove(key)
                self.scheduleRebuild()
            }
        }
        return gitMetadataCache[key]?.metadata
    }

    // MARK: - Worktrees

    func updateWorktrees(force: Bool = false) {
        let rootPaths = Set(sessions.map { repoRootForSession($0) })
        let now = Date()
        for rootPath in rootPaths {
            if !force, let lastFetch = lastWorktreeFetchTime[rootPath],
               now.timeIntervalSince(lastFetch) < 3.0 { continue }
            lastWorktreeFetchTime[rootPath] = now
            Task {
                let worktrees = await self.fetchWorktrees(for: rootPath)
                if self.projectWorktrees[rootPath] != worktrees {
                    self.projectWorktrees[rootPath] = worktrees
                    self.scheduleRebuild()
                }
            }
        }
    }

    // MARK: - Row rebuild

    // Batch concurrent async completions (git metadata, repo root, worktrees) into a
    // single rebuild 80 ms after the last one fires instead of one rebuild per result.
    private func scheduleRebuild() {
        pendingRebuild?.cancel()
        pendingRebuild = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, let self else { return }
            self.rebuildRows()
        }
    }

    private func rebuildRows() {
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }
        var groupMap: [String: Int] = [:]
        var groups: [(name: String, rootPath: String, firstIndex: Int, sessions: [SessionGroup])] = []
        for (index, session) in sessions.enumerated() {
            let rootPath = repoRootForSession(session)
            let name = groupName(forRootPath: rootPath)
            if let groupIndex = groupMap[rootPath] {
                groups[groupIndex].sessions.append(session)
            } else {
                groupMap[rootPath] = groups.count
                groups.append((name: name, rootPath: rootPath, firstIndex: index, sessions: [session]))
            }
        }

        let sortedGroups = groups.sorted { g1, g2 in
            let pin1 = pinnedRepos.contains(g1.rootPath)
            let pin2 = pinnedRepos.contains(g2.rootPath)
            if pin1 != pin2 { return pin1 }
            return g1.firstIndex < g2.firstIndex
        }

        var newRows: [SidebarSessionRow] = []
        let pinnedGroups = sortedGroups.filter { pinnedRepos.contains($0.rootPath) }
        let unpinnedGroups = sortedGroups.filter { !pinnedRepos.contains($0.rootPath) }

        func appendGroup(_ group: (name: String, rootPath: String, firstIndex: Int, sessions: [SessionGroup])) {
            let isCollapsed = collapsedGroups.contains(group.rootPath)
            let status = highestBoardStatus(for: group.sessions)
            newRows.append(.groupHeader(name: group.name, rootPath: group.rootPath,
                                        count: group.sessions.count, isCollapsed: isCollapsed, status: status))
            guard !isCollapsed else { return }
            for session in group.sessions {
                newRows.append(.session(session))
            }
        }

        for group in pinnedGroups { appendGroup(group) }
        if !pinnedGroups.isEmpty && !unpinnedGroups.isEmpty { newRows.append(.divider) }
        for group in unpinnedGroups { appendGroup(group) }

        rows = newRows
    }

    // MARK: - Helpers

    func repoRootForSession(_ session: SessionGroup) -> String {
        guard let tab = session.activeTab ?? session.tabs.first else { return "Other" }
        if let parentRepoPath = tab.parentRepoPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !parentRepoPath.isEmpty {
            // Normalize through the same --git-common-dir key as non-worktree tabs of this repo,
            // so a task worktree's session groups with the main repo instead of splitting off.
            return gitRepoRoot(for: parentRepoPath) ?? parentRepoPath
        }
        if let gitRoot = gitRepoRoot(for: tab.cwd) { return gitRoot }
        return tab.cwd.isEmpty ? "Other" : tab.cwd
    }

    private func groupName(forRootPath rootPath: String) -> String {
        KouenDesign.projectGroupDisplayName(forRootPath: rootPath)
    }

    private func gitRepoRoot(for path: String) -> String? {
        let now = Date()
        if let cached = repoRootCache[path], now.timeIntervalSince(cached.fetchedAt) < 60.0 {
            return cached.repoRoot
        }
        if repoRootUpdatesInProgress.insert(path).inserted {
            Task {
                let root = await self.resolveGitRepoRoot(for: path)
                self.repoRootCache[path] = (repoRoot: root, fetchedAt: Date())
                self.repoRootUpdatesInProgress.remove(path)
                self.scheduleRebuild()
            }
        }
        return repoRootCache[path]?.repoRoot
    }

    private func resolveGitRepoRoot(for path: String) async -> String? {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", path, "rev-parse", "--path-format=absolute", "--git-common-dir"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0,
                   let root = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !root.isEmpty { return root }
            } catch {}
            return nil
        }.value
    }

    private func highestBoardStatus(for sessions: [SessionGroup]) -> BoardColumnKind {
        func priority(_ s: BoardColumnKind) -> Int {
            switch s {
            case .needsAttention: 4
            case .running: 3
            case .done: 2
            case .error: 1
            case .idle: 0
            }
        }
        var highest = BoardColumnKind.idle
        for session in sessions {
            for tab in session.tabs {
                let status = BoardModel.columnKind(for: tab)
                if priority(status) > priority(highest) { highest = status }
            }
        }
        return highest
    }

    // MARK: - Async git fetches

    private static var cachedGhPath: String? = {
        let paths = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        for path in paths where FileManager.default.fileExists(atPath: path) { return path }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["gh"]
        let pipe = Pipe()
        p.standardOutput = pipe
        do {
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if p.terminationStatus == 0,
               let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty, FileManager.default.fileExists(atPath: path) { return path }
        } catch {}
        return nil
    }()

    private func fetchHasRemote(for path: String) async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["remote"]
            process.currentDirectoryURL = URL(fileURLWithPath: path)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    return !(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
                }
            } catch {}
            return false
        }.value
    }

    private func fetchGitMetadata(for path: String, branch: String) async -> RepoGitMetadata {
        let empty = RepoGitMetadata(prNumber: nil, prURL: nil, prTitle: nil, prBaseBranch: nil, prChecksStatus: nil, prMergeable: nil, prReviewDecision: nil, aheadCount: nil, behindCount: nil)
        guard Self.cachedGhPath != nil, await fetchHasRemote(for: path) else { return empty }

        return await Task.detached(priority: .utility) {
            let pr = GitHubCLIClient().prForCurrentBranch(repoPath: path)
            let prNumber = pr?.number
            let prURL = pr?.url
            let prTitle = pr?.title
            let prBaseBranch = pr?.baseRefName
            let prChecksStatus = pr?.checksStatus
            let prMergeable = pr.map { $0.mergeable }
            let prReviewDecision = pr?.reviewDecision

            var aheadCount: Int? = nil
            var behindCount: Int? = nil
            let revProcess = Process()
            revProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            revProcess.arguments = ["rev-list", "--left-right", "--count", "HEAD...origin/\(branch)"]
            revProcess.currentDirectoryURL = URL(fileURLWithPath: path)
            let revPipe = Pipe()
            revProcess.standardOutput = revPipe
            revProcess.standardError = FileHandle.nullDevice
            do {
                try revProcess.run()
                let data = revPipe.fileHandleForReading.readDataToEndOfFile()
                revProcess.waitUntilExit()
                if revProcess.terminationStatus == 0,
                   let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let parts = output.components(separatedBy: "\t")
                    if parts.count == 2 { aheadCount = Int(parts[0]); behindCount = Int(parts[1]) }
                }
            } catch {}

            return RepoGitMetadata(prNumber: prNumber, prURL: prURL, prTitle: prTitle, prBaseBranch: prBaseBranch, prChecksStatus: prChecksStatus, prMergeable: prMergeable, prReviewDecision: prReviewDecision, aheadCount: aheadCount, behindCount: behindCount)
        }.value
    }

    private func fetchWorktrees(for rootPath: String) async -> [SidebarWorktreeEntry] {
        guard !rootPath.isEmpty, FileManager.default.fileExists(atPath: rootPath) else { return [] }
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["worktree", "list", "--porcelain"]
            process.currentDirectoryURL = URL(fileURLWithPath: rootPath)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return [] }
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return output.components(separatedBy: "\n\n").enumerated().compactMap { index, block in
                    let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
                    guard let wtLine = lines.first(where: { $0.hasPrefix("worktree ") }),
                          let headLine = lines.first(where: { $0.hasPrefix("HEAD ") }) else { return nil }
                    let worktreePath = String(wtLine.dropFirst("worktree ".count))
                    let head = String(headLine.dropFirst("HEAD ".count))
                    let branchLine = lines.first(where: { $0.hasPrefix("branch ") })
                    let branch = branchLine.map { line -> String in
                        let ref = String(line.dropFirst("branch ".count))
                        return ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
                    } ?? "detached"
                    let isLocked = lines.contains { $0 == "locked" || $0.hasPrefix("locked ") }
                    return SidebarWorktreeEntry(path: worktreePath, head: head, branch: branch,
                                                isMain: index == 0, isLocked: isLocked)
                }
            } catch { return [] }
        }.value
    }
}
