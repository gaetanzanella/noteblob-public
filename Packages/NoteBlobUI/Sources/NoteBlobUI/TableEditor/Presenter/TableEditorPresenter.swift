import Foundation

// MARK: - Navigation

public struct TableEditorNavigationPayload {

    public let initialDraft: TableDraft
    public let onConfirmed: (TableDraft) -> Void

    public init(initialDraft: TableDraft, onConfirmed: @escaping (TableDraft) -> Void) {
        self.initialDraft = initialDraft
        self.onConfirmed = onConfirmed
    }
}

enum TableEditorViewAction {
    case insertColumn(after: Int)
    case removeColumn(Int)
    case insertRow(after: Int)
    case removeRow(Int)
    case updateHeader(column: Int, value: String)
    case updateCell(row: Int, column: Int, value: String)
    case confirm
}

// MARK: - ViewModel

struct TableEditorViewModel {
    let headers: [String]
    let rows: [[String]]
    let rowCount: Int
    let columnCount: Int
    let isConfirmEnabled: Bool
}

// MARK: - State

private struct TableEditorState {
    var draft: TableDraft
}

// MARK: - Presenter

@Observable
@MainActor
public final class TableEditorPresenter {

    private var state: TableEditorState
    private let onConfirmed: (TableDraft) -> Void

    public init(payload: TableEditorNavigationPayload) {
        let draft: TableDraft
        if payload.initialDraft.columnCount > 0 {
            draft = payload.initialDraft
        } else {
            draft = .empty(columns: 3, rows: 2)
        }
        self.state = TableEditorState(draft: draft)
        self.onConfirmed = payload.onConfirmed
    }

    func viewModel() -> TableEditorViewModel {
        TableEditorViewModel(
            headers: state.draft.headers,
            rows: state.draft.rows,
            rowCount: state.draft.rowCount,
            columnCount: state.draft.columnCount,
            isConfirmEnabled: hasContent()
        )
    }

    func on(_ action: TableEditorViewAction) {
        switch action {
        case .insertColumn(let column):
            state.draft.insertColumn(after: column)
        case .removeColumn(let column):
            state.draft.removeColumn(at: column)
        case .insertRow(let row):
            state.draft.insertRow(after: row)
        case .removeRow(let row):
            state.draft.removeRow(at: row)
        case .updateHeader(let column, let value):
            state.draft.setHeader(column: column, value: value)
        case .updateCell(let row, let column, let value):
            state.draft.setCell(row: row, column: column, value: value)
        case .confirm:
            guard hasContent() else { return }
            onConfirmed(state.draft)
        }
    }

    private func hasContent() -> Bool {
        guard state.draft.columnCount >= 1, state.draft.rowCount >= 1 else { return false }
        if state.draft.headers.contains(where: { !$0.isEmpty }) { return true }
        return state.draft.rows.contains { row in row.contains(where: { !$0.isEmpty }) }
    }
}
