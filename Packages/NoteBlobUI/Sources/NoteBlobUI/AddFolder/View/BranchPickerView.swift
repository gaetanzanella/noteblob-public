import SwiftUI

struct BranchPickerView: View {

    @State var presenter: BranchPickerPresenter

    var body: some View {
        let vm = presenter.viewModel()
        Group {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = vm.errorMessage {
                ContentUnavailableView {
                    Label {
                        Text("branch_picker.error.title", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(errorMessage)
                }
            } else if vm.branches.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("branch_picker.empty.title", bundle: .module)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text("branch_picker.empty.description", bundle: .module)
                }
            } else {
                branchList(vm: vm)
            }
        }
        .navigationTitle(Text("branch_picker.title", bundle: .module))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { presenter.on(.confirm) } label: {
                    Text("add_folder.add.action", bundle: .module).bold()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(!vm.canConfirm)
            }
        }
        .task {
            await presenter.load()
        }
        .alert(vm.alert) {
            presenter.on(.dismissAlert)
        }
    }

    private func branchList(vm: BranchPickerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("branch_picker.explanation", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 12)

            List(selection: Binding<String?>(
                get: { vm.selectedBranch },
                set: { presenter.on(.select($0)) }
            )) {
                ForEach(vm.branches, id: \.self) { branch in
                    HStack {
                        Label(branch, systemImage: "arrow.triangle.branch")
                        Spacer()
                        if vm.selectedBranch == branch {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                    .tag(branch)
                }
            }
            .disabled(!vm.canSelect)
        }
    }
}
