import Foundation
import HarnessCore

public struct FileNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public var children: [FileNode]?
    public var gitStatus: GitStatusType

    public init(
        id: String,
        name: String,
        path: String,
        isDirectory: Bool,
        children: [FileNode]? = nil,
        gitStatus: GitStatusType = .unmodified
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
        self.gitStatus = gitStatus
    }
}

public enum GitStatusType: Sendable {
    case unmodified
    case modified
    case added
    case deleted
    case renamed
    case untracked
}
