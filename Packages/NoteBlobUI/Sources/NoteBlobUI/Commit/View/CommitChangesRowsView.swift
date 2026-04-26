import SwiftUI

struct CommitChangesRowsView: View {

    let vm: CommitViewModel
    let onAction: (CommitViewAction) -> Void

    var body: some View {
        ForEach(vm.rows) { row in
            HStack {
                CommitChangeIcon(kind: row.kind)
                Text(row.path)
                    .font(.body.monospaced())
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .tag(row.id)
            #if os(iOS)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onAction(.discardFile(row.path))
                } label: {
                    Label(
                        String.localized("commit.discard.file"),
                        systemImage: "trash"
                    )
                }
            }
            #endif
            .contextMenu {
                Button(role: .destructive) {
                    onAction(.discardFile(row.path))
                } label: {
                    Label(
                        String.localized("commit.discard.file"),
                        systemImage: "trash"
                    )
                }
            }
        }
        #if os(iOS)
        .onDelete { indexSet in
            let rows = vm.rows
            for index in indexSet {
                onAction(.discardFile(rows[index].path))
            }
        }
        #endif
    }
}
