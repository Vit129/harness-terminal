import Foundation
import KouenCore

/// Observes branch changes and auto-creates a worktree for isolation.
/// Every tab that switches to a non-default branch gets its own worktree
/// so that git probe always returns the correct branch per tab.
@MainActor
final class WorktreeAutoIsolateService {
    static let shared = WorktreeAutoIsolateService()
    private let manager = WorktreeManager()
    private var observation: NSObjectProtocol?
    private static let defaultBranches: Set<String> = ["main", "master", "develop"]

    private init() {}

    func start() {
        observation = NotificationCenter.default.addObserver(
            forName: Notification.Name("KouenActiveTabGitBranchDidChange"),
            object: nil, queue: .main
        ) { [weak self] note in
            let tabIDs = note.userInfo?["tabIDs"] as? [TabID] ?? []
            Task { @MainActor in self?.handleBranchChange(tabIDs: tabIDs) }
        }
    }

    /// Isolates every tab whose branch changed this poll, not just the focused one — a
    /// background tab (an agent session not currently in view) that switches branch must still
    /// get its own worktree, or its cwd/worktreePath stay pinned to the repo root forever.
    private func handleBranchChange(tabIDs: [TabID]) {
        let coord = SessionCoordinator.shared
        for workspace in coord.snapshot.workspaces {
            for session in workspace.sessions {
                for tab in session.tabs where tabIDs.contains(tab.id) {
                    isolate(tab: tab, workspace: workspace)
                }
            }
        }
    }

    private func isolate(tab: Tab, workspace: Workspace) {
        let coord = SessionCoordinator.shared
        guard let branch = tab.gitBranch, !branch.isEmpty else { return }
        guard !Self.defaultBranches.contains(branch) else { return }

        // Already in a worktree? Skip.
        if tab.worktreePath != nil { return }

        let cwd = tab.cwd
        // Check if cwd is the PARENT repo root (not already inside a worktree).
        // git rev-parse --show-toplevel returns the worktree root if inside one,
        // so we also check --git-common-dir to detect worktree vs main repo.
        guard manager.repoRoot(for: cwd) == cwd else { return }
        guard !isInsideWorktree(cwd) else { return }

        // Collect worktree paths already claimed by OTHER tabs in this workspace.
        let otherTabWorktrees: Set<String> = Set(
            workspace.sessions.flatMap(\.tabs)
                .filter { $0.id != tab.id }
                .compactMap { $0.worktreePath ?? $0.cwd }
        )

        // Find an existing worktree for this branch that no other tab is using.
        let existingWorktrees = manager.list(repoPath: cwd).filter { $0.branch == branch }
        let availableWorktree = existingWorktrees.first { !otherTabWorktrees.contains($0.path) }

        let wtPath: String
        if let available = availableWorktree, available.path != cwd {
            wtPath = available.path
        } else {
            // All existing worktrees for this branch are occupied (or only the repo root itself).
            // Create a new one with a unique suffix.
            let baseName = branch.replacingOccurrences(of: "/", with: "-")
            let suffix = existingWorktrees.isEmpty ? "" : "-\(existingWorktrees.count)"
            let sessionID = baseName + suffix
            let config = ProjectConfig.load(from: cwd)
            let baseRef = config?.baseRef ?? branch
            guard let created = manager.create(repoPath: cwd, sessionID: sessionID, branch: nil, baseRef: baseRef) else { return }
            wtPath = created
        }

        // Move shell to the worktree path
        if let surfaceID = tab.rootPane.allSurfaceIDs().first {
            coord.requestDaemon(.sendData(
                surfaceID: surfaceID.uuidString,
                data: Data(("cd \(wtPath)\r").utf8)
            ))
        }

        // Tag the tab so sidebar grouping/`isStableEqual` and the "already isolated" guard above
        // (`tab.worktreePath != nil`) see this tab as isolated, same as an explicit task tab.
        coord.requestDaemon(.setTabWorktree(tabID: tab.id, worktreePath: wtPath, parentRepoPath: cwd, taskName: nil))
    }

    /// Returns true if the path is inside a git linked worktree (not the main working tree).
    /// Uses `git rev-parse --git-common-dir` vs `--git-dir` — if they differ, it's a worktree.
    private func isInsideWorktree(_ path: String) -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--git-dir", "--git-common-dir"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n")
            guard lines.count == 2 else { return false }
            // In a linked worktree, git-dir != git-common-dir
            // e.g. git-dir = /repo/.git/worktrees/xyz, git-common-dir = /repo/.git
            return lines[0] != lines[1]
        } catch { return false }
    }
}
