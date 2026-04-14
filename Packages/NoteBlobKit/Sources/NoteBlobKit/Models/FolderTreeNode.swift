import Foundation

public struct FolderTreeNode: Sendable, Identifiable, Hashable {
    public let name: String
    public let path: RelativePath
    public let children: [FolderTreeNode]?

    public var id: String { path.value }

    public init(name: String, path: RelativePath, children: [FolderTreeNode]?) {
        self.name = name
        self.path = path
        self.children = children
    }
}
