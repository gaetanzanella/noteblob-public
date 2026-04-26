import SwiftUI

#if os(macOS)
import AppKit

struct MacOSCommitView: View {

    let vm: CommitViewModel
    let selection: () -> String?
    let onAction: (CommitViewAction) -> Void
    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Text(vm.navigationTitle)
                .font(.headline)
                .padding(.bottom, 12)

            CommitFlowHeader(vm: vm) { onAction(.selectStep($0)) }
                .padding(.bottom, 4)

            StepExplanationView(vm: vm)

            CommitErrorView(vm: vm, onAction: onAction)

            Group {
                if vm.isBrowsingOtherStep {
                    Spacer()
                } else {
                    switch vm.mode {
                    case .loading:
                        Spacer()
                        ProgressView()
                        Spacer()
                    case .localChanges:
                        macOSLocalChangesContent()
                    case .pushNeeded:
                        CommitLogContentView(vm: vm)
                    case .pullNeeded:
                        statusContent(
                            systemImage: "arrow.down.circle.fill",
                            color: .blue,
                            title: "sync.pull.title",
                            description: "sync.pull.description"
                        )
                    case .upToDate:
                        statusContent(
                            systemImage: "checkmark.circle.fill",
                            color: .green,
                            title: "sync.up_to_date.title",
                            description: "sync.up_to_date.description"
                        )
                    case .notBacked:
                        statusContent(
                            systemImage: "exclamationmark.triangle.fill",
                            color: .orange,
                            title: "sync.not_backed.title",
                            description: "sync.not_backed.description"
                        )
                    case .readyToMerge:
                        CommitLogContentView(vm: vm)
                    }
                }
            }

            Divider()

            buttons()
                .padding(.top, 20)
        }
        .scenePadding()
    }

    // MARK: - Private

    private func statusContent(
        systemImage: String,
        color: Color,
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        VStack {
            Spacer()
            CommitStatusView(
                systemImage: systemImage,
                color: color,
                title: title,
                description: description
            )
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func macOSLocalChangesContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Section {
                TextField(text: Binding(
                    get: { vm.commitMessage },
                    set: { onAction(.editMessage($0)) }
                ), axis: .vertical) {
                    if vm.isGeneratingMessage {
                        Text("commit.message.generating", bundle: .module)
                    } else {
                        Text("commit.message.placeholder", bundle: .module)
                    }
                }
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isLoading || vm.isGeneratingMessage)
            } header: {
                Text("commit.message.header", bundle: .module)
            }
            .padding(.bottom, 8)

            Section {
                List(
                    selection: Binding<String>(
                        get: { selection() ?? "" },
                        set: { newValue in
                            // Apple bug: inside a sheet, `List` fires its
                            // selection-binding setter on right-click while
                            // the button is still held. Detect that via
                            // NSEvent and suppress the navigation side-effect
                            // so `.contextMenu` can appear without pushing.
                            guard NSEvent.pressedMouseButtons & (1 << 1) == 0 else { return }
                            onAction(.selectFile(newValue))
                        }
                    )
                ) {
                    CommitChangesRowsView(vm: vm, onAction: onAction)
                }
            } header: {
                Text("commit.changes_count \(vm.rows.count)", bundle: .module)
            }
        }
    }

    private func buttons() -> some View {
        HStack {
            if case .localChanges = vm.mode, !vm.isBrowsingOtherStep {
                Button(role: .destructive) {
                    isShowingDiscardConfirmation = true
                } label: {
                    Text("commit.discard.action", bundle: .module)
                }
                .disabled(vm.isLoading)
                .confirmationDialog(
                    Text("commit.discard.confirm.title", bundle: .module),
                    isPresented: $isShowingDiscardConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) {
                        onAction(.discard)
                    } label: {
                        Text("commit.discard.confirm.action", bundle: .module)
                    }
                } message: {
                    Text("commit.discard.confirm.message", bundle: .module)
                }
            }

            Spacer()

            Button { onAction(.done) } label: {
                Text("common.done", bundle: .module)
            }
            .keyboardShortcut(.cancelAction)

            if !vm.isBrowsingOtherStep {
                confirmationButton()
            }
        }
    }

    @ViewBuilder
    private func confirmationButton() -> some View {
        switch vm.mode {
        case .loading, .upToDate, .notBacked:
            EmptyView()
        case .localChanges:
            Menu {
                CommitActionMenuItems(onAction: onAction)
            } label: {
                Text("commit.action", bundle: .module)
            }
            .menuStyle(.borderedButton)
            .disabled(!vm.canCommit)
        case .pushNeeded:
            Menu {
                PushActionMenuItems(onAction: onAction)
            } label: {
                Text("sync.push.action", bundle: .module)
            }
            .menuStyle(.borderedButton)
            .disabled(vm.isLoading)
        case .pullNeeded:
            Button { onAction(.pull) } label: {
                Text("sync.pull.action", bundle: .module)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.isLoading)
        case .readyToMerge:
            Button { onAction(.merge) } label: {
                Text("sync.merge.action", bundle: .module)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.isLoading)
        }
    }
}
#endif
