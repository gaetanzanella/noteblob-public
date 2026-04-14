import SwiftUI
import NoteBlobKit

struct MoveDestinationView: View {

    @State var presenter: MoveDestinationPresenter

    private var selection: Binding<RelativePath?> {
        Binding(
            get: { presenter.viewModel().selectedPath },
            set: { path in
                if let path {
                    presenter.on(.select(path))
                }
            }
        )
    }

    var body: some View {
        let vm = presenter.viewModel()
        List(selection: selection) {
            rootRow(vm: vm)
            OutlineGroup(vm.rows, children: \.children) { row in
                folderRow(row: row, vm: vm)
            }
        }
        .listStyle(.plain)
        .navigationTitle(vm.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .bottomBar) {
                confirmButton(vm: vm)
            }
            #else
            ToolbarItem(placement: .confirmationAction) {
                confirmButton(vm: vm)
            }
            #endif
        }
        .alert(vm.alert) {}
        .onAppear { presenter.on(.load) }
    }

    private func confirmButton(vm: MoveDestinationViewModel) -> some View {
        Button {
            presenter.on(.confirm)
        } label: {
            Text("folder.move.action", bundle: .module)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!vm.canConfirm)
    }

    private func rootRow(vm: MoveDestinationViewModel) -> some View {
        Label(vm.title, systemImage: "folder")
            .tag(RelativePath.root)
            .disabled(vm.isRootDisabled)
    }

    private func folderRow(row: MoveDestinationViewModel.Row, vm: MoveDestinationViewModel) -> some View {
        Label(row.name, systemImage: "folder")
            .tag(row.path)
            .disabled(row.isDisabled)
    }
}

public struct MoveDestinationSheet: View {

    @State var presenter: MoveDestinationPresenter
    @Environment(\.dismiss) private var dismiss

    public init(presenter: MoveDestinationPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        NavigationStack {
            MoveDestinationView(presenter: presenter)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minHeight: 400)
        #endif
    }
}
