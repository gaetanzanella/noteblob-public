import Foundation

// MARK: - DocumentEditorAction

public enum DocumentEditorAction: Hashable, Sendable {
    case format(Mark)
    case indent
    case dedent
    case formatDocument
    case insert(Insertion)
    case editTable
    case undo
    case redo

    public enum Insertion: Hashable, Sendable {
        case link(target: String, title: String)
        case table(MarkdownTable)
    }
}

// MARK: - Mark

public enum Mark: Hashable, Sendable {
    case heading(Int)
    case bold
    case italic
    case strikethrough
    case inlineCode
    case codeBlock
    case list
    case todoList
}
