import SwiftUI

public struct TableEditorView: View {

    private struct CellID: Hashable {
        // row == -1 identifies the header row.
        let row: Int
        let column: Int
    }

    private static let menuButtonHeight: CGFloat = 24
    /// Wider than the height so the menu's icon + chevron (macOS) has a
    /// little breathing room and doesn't crowd against the cell border.
    private static let menuButtonWidth: CGFloat = 40

    @State private var presenter: TableEditorPresenter
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedCell: CellID?
    /// Mirrors `focusedCell` but persists across focus loss caused by tapping
    /// a menu button (which moves focus off the cell). Drives the menu
    /// visibility so the menu doesn't hide itself the instant the user taps
    /// it, killing the popover before it can open.
    @State private var lastFocusedColumn: Int = 0
    @State private var lastFocusedRow: Int = -1

    public init(presenter: TableEditorPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        let vm = presenter.viewModel()
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height
                            )
                        grid(vm: vm)
                            .padding()
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle(Text("note.table.title", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        presenter.on(.confirm)
                    } label: {
                        Text("note.table.confirm", bundle: .module).bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!vm.isConfirmEnabled)
                }
            }
            .onAppear {
                focus(CellID(row: -1, column: 0))
            }
            .onChange(of: focusedCell) { _, newValue in
                if let cell = newValue {
                    lastFocusedColumn = cell.column
                    lastFocusedRow = cell.row
                }
            }
        }
        #if os(macOS)
            .frame(width: 560, height: 460)
        #endif
    }

    @ViewBuilder
    private func grid(vm: TableEditorViewModel) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            // Top row: per-column more buttons.
            GridRow {
                cornerSpacer
                ForEach(0..<vm.columnCount, id: \.self) { column in
                    columnMenuSlot(vm: vm, column: column)
                }
            }
            // Header row.
            GridRow {
                rowMenuSlot(vm: vm, row: -1)
                ForEach(0..<vm.columnCount, id: \.self) { column in
                    headerCell(vm: vm, column: column)
                }
            }
            // Body rows.
            ForEach(0..<vm.rowCount, id: \.self) { row in
                GridRow {
                    rowMenuSlot(vm: vm, row: row)
                    ForEach(0..<vm.columnCount, id: \.self) { column in
                        bodyCell(vm: vm, row: row, column: column)
                    }
                }
            }
        }
    }

    private var cornerSpacer: some View {
        Color.clear.frame(width: Self.menuButtonWidth, height: Self.menuButtonHeight)
    }

    @ViewBuilder
    private func columnMenuSlot(vm: TableEditorViewModel, column: Int) -> some View {
        let visible = lastFocusedColumn == column
        Menu {
            columnMenuItems(vm: vm, column: column)
        } label: {
            // Frame *inside* the label so the menu's tap target = the full
            // column slot, not just the small icon glyph. Bolder weight makes
            // the dots readable against the cell highlight.
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 160, height: Self.menuButtonHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }

    @ViewBuilder
    private func columnMenuItems(vm: TableEditorViewModel, column: Int) -> some View {
        Button {
            presenter.on(.insertColumn(after: column - 1))
        } label: {
            Label {
                Text("note.table.insert_column_left", bundle: .module)
            } icon: {
                Image(systemName: "arrow.left")
            }
        }
        Button {
            presenter.on(.insertColumn(after: column))
        } label: {
            Label {
                Text("note.table.insert_column_right", bundle: .module)
            } icon: {
                Image(systemName: "arrow.right")
            }
        }
        Divider()
        Button(role: .destructive) {
            presenter.on(.removeColumn(column))
        } label: {
            Label {
                Text("note.table.remove_column", bundle: .module)
            } icon: {
                Image(systemName: "trash")
            }
        }
        .disabled(vm.columnCount <= 1)
    }

    @ViewBuilder
    private func rowMenuSlot(vm: TableEditorViewModel, row: Int) -> some View {
        // Header row (`row == -1`) keeps the menu — the user can still
        // "Insert Row Below" to add the first body row. Insert-above and
        // delete are disabled for the header in `rowMenuItems(vm:row:)`.
        let visible = lastFocusedRow == row
        Menu {
            rowMenuItems(vm: vm, row: row)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .rotationEffect(.degrees(90))
                .foregroundStyle(.primary)
                .frame(width: Self.menuButtonWidth, height: Self.menuButtonHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }

    @ViewBuilder
    private func rowMenuItems(vm: TableEditorViewModel, row: Int) -> some View {
        let isHeader = row < 0
        Button {
            presenter.on(.insertRow(after: row - 1))
        } label: {
            Label {
                Text("note.table.insert_row_above", bundle: .module)
            } icon: {
                Image(systemName: "arrow.up")
            }
        }
        .disabled(isHeader)
        Button {
            presenter.on(.insertRow(after: row))
        } label: {
            Label {
                Text("note.table.insert_row_below", bundle: .module)
            } icon: {
                Image(systemName: "arrow.down")
            }
        }
        Divider()
        Button(role: .destructive) {
            presenter.on(.removeRow(row))
        } label: {
            Label {
                Text("note.table.remove_row", bundle: .module)
            } icon: {
                Image(systemName: "trash")
            }
        }
        .disabled(isHeader)
    }

    @ViewBuilder
    private func headerCell(vm: TableEditorViewModel, column: Int) -> some View {
        let id = CellID(row: -1, column: column)
        TextField(
            text: Binding(
                get: { headerValue(vm: vm, column: column) },
                set: { presenter.on(.updateHeader(column: column, value: $0)) }
            )
        ) {
            Text(verbatim: "")
        }
        .textFieldStyle(.plain)
        .fontWeight(.semibold)
        .focused($focusedCell, equals: id)
        .padding(.horizontal, cellHorizontalPadding)
        .padding(.vertical, cellVerticalPadding)
        .frame(width: 160, alignment: .leading)
        .background(cellHighlight(row: -1, column: column))
        .contentShape(Rectangle())
        .onTapGesture {
            focus(id)
        }
        .overlay(cellBorder)
    }

    @ViewBuilder
    private func bodyCell(vm: TableEditorViewModel, row: Int, column: Int) -> some View {
        let id = CellID(row: row, column: column)
        TextField(
            text: Binding(
                get: { cellValue(vm: vm, row: row, column: column) },
                set: { presenter.on(.updateCell(row: row, column: column, value: $0)) }
            )
        ) {
            Text(verbatim: "")
        }
        .textFieldStyle(.plain)
        .focused($focusedCell, equals: id)
        .padding(.horizontal, cellHorizontalPadding)
        .padding(.vertical, cellVerticalPadding)
        .frame(width: 160, alignment: .leading)
        .background(cellHighlight(row: row, column: column))
        .contentShape(Rectangle())
        .onTapGesture {
            focus(id)
        }
        .overlay(cellBorder)
    }

    private var cellBorder: some View {
        Rectangle()
            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
    }

    /// Apple Notes-style cross-hair highlight: the focused cell gets a
    /// stronger tint, while every other cell sharing its row or column gets
    /// a softer tint to make the focus position obvious at a glance.
    private func cellHighlight(row: Int, column: Int) -> Color {
        let inRow = lastFocusedRow == row
        let inColumn = lastFocusedColumn == column
        if inRow && inColumn {
            return Color.accentColor.opacity(0.18)
        }
        if inRow || inColumn {
            return Color.accentColor.opacity(0.06)
        }
        return Color.clear
    }

    #if os(iOS)
    private let cellHorizontalPadding: CGFloat = 12
    private let cellVerticalPadding: CGFloat = 10
    #else
    private let cellHorizontalPadding: CGFloat = 8
    private let cellVerticalPadding: CGFloat = 6
    #endif

    private func focus(_ id: CellID) {
        focusedCell = id
        lastFocusedColumn = id.column
        lastFocusedRow = id.row
    }

    private func headerValue(vm: TableEditorViewModel, column: Int) -> String {
        guard vm.headers.indices.contains(column) else { return "" }
        return vm.headers[column]
    }

    private func cellValue(vm: TableEditorViewModel, row: Int, column: Int) -> String {
        guard vm.rows.indices.contains(row), vm.rows[row].indices.contains(column) else {
            return ""
        }
        return vm.rows[row][column]
    }
}
