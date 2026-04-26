import SwiftUI

#if os(iOS)
struct IOSCommitView: View {

    let vm: CommitViewModel
    let selection: () -> String?
    let onAction: (CommitViewAction) -> Void
    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        List(
            selection: vm.isSelectionEnabled ? Binding<String?>(
                get: selection,
                set: { onAction(.selectFile($0)) }
            ) : nil
        ) {
            if let errorMessage = vm.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                    if vm.needsAuth {
                        Button { onAction(.signIn) } label: {
                            Text("auth.sign_in", bundle: .module)
                        }
                    }
                }
            }

            if !vm.isBrowsingOtherStep {
                switch vm.mode {
                case .loading:
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                case .localChanges:
                    CommitChangesView(
                        vm: vm,
                        onAction: onAction,
                        isShowingDiscardConfirmation: $isShowingDiscardConfirmation
                    )
                case .pushNeeded:
                    CommitLogSectionView(vm: vm)
                case .pullNeeded:
                    Section { CommitStatusView(
                        systemImage: "arrow.down.circle.fill",
                        color: .blue,
                        title: "sync.pull.title",
                        description: "sync.pull.description"
                    ) }
                case .upToDate:
                    Section { CommitStatusView(
                        systemImage: "checkmark.circle.fill",
                        color: .green,
                        title: "sync.up_to_date.title",
                        description: "sync.up_to_date.description"
                    ) }
                case .notBacked:
                    Section { CommitStatusView(
                        systemImage: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "sync.not_backed.title",
                        description: "sync.not_backed.description"
                    ) }
                case .readyToMerge:
                    CommitLogSectionView(vm: vm)
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            if !vm.steps.isEmpty {
                VStack(spacing: 8) {
                    CommitFlowHeader(vm: vm) { onAction(.selectStep($0)) }
                    StepExplanationView(vm: vm)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .navigationTitle(vm.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { onAction(.done) } label: {
                    Text("common.done", bundle: .module)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if !vm.isBrowsingOtherStep {
                    confirmationButton()
                }
            }
        }
    }

    // MARK: - Private

    @ViewBuilder
    private func confirmationButton() -> some View {
        switch vm.mode {
        case .loading, .upToDate, .notBacked:
            EmptyView()
        case .localChanges:
            Menu {
                CommitActionMenuItems(onAction: onAction)
            } label: {
                Text("commit.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!vm.canCommit)
        case .pushNeeded:
            Menu {
                PushActionMenuItems(onAction: onAction)
            } label: {
                Text("sync.push.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        case .pullNeeded:
            Button { onAction(.pull) } label: {
                Text("sync.pull.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        case .readyToMerge:
            Button { onAction(.merge) } label: {
                Text("sync.merge.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        }
    }
}
#endif
