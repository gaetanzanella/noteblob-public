import SwiftUI

public struct CommitView: View {

    @State var presenter: CommitPresenter
    let selection: () -> String?
    @State private var isShowingDiscardConfirmation = false

    public init(presenter: CommitPresenter, selection: @escaping () -> String?) {
        self._presenter = State(initialValue: presenter)
        self.selection = selection
    }

    public var body: some View {
        let vm = presenter.viewModel()
        #if os(macOS)
        macOSBody(vm: vm)
        #else
        iOSBody(vm: vm)
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private func macOSBody(vm: CommitViewModel) -> some View {
        VStack(spacing: 0) {
            navigationTitle(for: vm.mode)
                .font(.headline)
                .padding(.bottom, 12)

            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.bottom, 8)
            }

            Group {
                switch vm.mode {
                case .loading:
                    Spacer()
                    ProgressView()
                    Spacer()
                case .localChanges:
                    macOSLocalChangesContent(vm: vm)
                case .pushNeeded:
                    commitLogContent(vm: vm)
                case .pullNeeded:
                    macOSStatusContent(
                        systemImage: "arrow.down.circle.fill",
                        color: .blue,
                        title: "sync.pull.title",
                        description: "sync.pull.description"
                    )
                case .upToDate:
                    macOSStatusContent(
                        systemImage: "checkmark.circle.fill",
                        color: .green,
                        title: "sync.up_to_date.title",
                        description: "sync.up_to_date.description"
                    )
                case .notBacked:
                    macOSStatusContent(
                        systemImage: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "sync.not_backed.title",
                        description: "sync.not_backed.description"
                    )
                case .readyToMerge:
                    commitLogContent(vm: vm)
                }
            }

            Divider()

            macOSButtons(vm: vm)
                .padding(.top, 20)
        }
        .scenePadding()
        .task { presenter.on(.load) }
    }

    private func macOSStatusContent(
        systemImage: String,
        color: Color,
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(color)
            Text(title, bundle: .module)
                .font(.headline)
            Text(description, bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func macOSLocalChangesContent(vm: CommitViewModel) -> some View {
        VStack(spacing: 0) {
            Section {
                TextField(text: Binding(
                    get: { vm.commitMessage },
                    set: { presenter.on(.editMessage($0)) }
                ), axis: .vertical) {
                    if vm.isGeneratingMessage {
                        Text("commit.message.generating", bundle: .module)
                    } else {
                        Text("commit.message.placeholder", bundle: .module)
                    }
                }
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isGeneratingMessage)
            } header: {
                Text("commit.message.header", bundle: .module)
            }
            .padding(.bottom, 8)

            List(
                selection: Binding<String>(
                    get: { selection() ?? "" },
                    set: { presenter.on(.selectFile($0)) }
                )
            ) {
                Section {
                    changesRows(vm: vm)
                } header: {
                    Text("commit.changes_count \(vm.rows.count)", bundle: .module)
                }
            }
        }
    }

    private func macOSButtons(vm: CommitViewModel) -> some View {
        HStack {
            if case .localChanges = vm.mode {
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
                        presenter.on(.discard)
                    } label: {
                        Text("commit.discard.confirm.action", bundle: .module)
                    }
                } message: {
                    Text("commit.discard.confirm.message", bundle: .module)
                }
            }

            Spacer()

            Button { presenter.on(.done) } label: {
                Text("common.done", bundle: .module)
            }
            .keyboardShortcut(.cancelAction)

            macOSConfirmationButton(vm: vm)
        }
    }

    @ViewBuilder
    private func macOSConfirmationButton(vm: CommitViewModel) -> some View {
        switch vm.mode {
        case .loading, .upToDate, .notBacked:
            EmptyView()
        case .localChanges:
            Menu {
                Button { presenter.on(.commit) } label: {
                    Label(String.localized("commit.action"), systemImage: "checkmark.circle")
                }
                Button { presenter.on(.commitAndPush) } label: {
                    Label(String.localized("commit.action.commit_and_push"), systemImage: "arrow.up.circle")
                }
                Button { presenter.on(.commitPushAndMerge) } label: {
                    Label(String.localized("commit.action.commit_push_merge"), systemImage: "arrow.triangle.merge")
                }
            } label: {
                Text("commit.action", bundle: .module)
            }
            .menuStyle(.borderedButton)
            .disabled(!vm.canCommit)
        case .pushNeeded:
            Menu {
                Button { presenter.on(.push) } label: {
                    Label(String.localized("sync.push.action"), systemImage: "arrow.up.circle")
                }
                Button { presenter.on(.pushAndMerge) } label: {
                    Label(String.localized("sync.push.action.push_and_merge"), systemImage: "arrow.triangle.merge")
                }
            } label: {
                Text("sync.push.action", bundle: .module)
            }
            .menuStyle(.borderedButton)
            .disabled(vm.isLoading)
        case .pullNeeded:
            Button { presenter.on(.pull) } label: {
                Text("sync.pull.action", bundle: .module)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.isLoading)
        case .readyToMerge:
            Button { presenter.on(.merge) } label: {
                Text("sync.merge.action", bundle: .module)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.isLoading)
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private func iOSBody(vm: CommitViewModel) -> some View {
        List(
            selection: Binding<String?>(
                get: selection,
                set: { presenter.on(.selectFile($0)) }
            )
        ) {
            if let errorMessage = vm.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            switch vm.mode {
            case .loading:
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            case .localChanges:
                localChangesContent(vm: vm)
            case .pushNeeded:
                commitLogSection(vm: vm)
            case .pullNeeded:
                statusSection(
                    systemImage: "arrow.down.circle.fill",
                    color: .blue,
                    title: "sync.pull.title",
                    description: "sync.pull.description"
                )
            case .upToDate:
                statusSection(
                    systemImage: "checkmark.circle.fill",
                    color: .green,
                    title: "sync.up_to_date.title",
                    description: "sync.up_to_date.description"
                )
            case .notBacked:
                statusSection(
                    systemImage: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "sync.not_backed.title",
                    description: "sync.not_backed.description"
                )
            case .readyToMerge:
                commitLogSection(vm: vm)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(navigationTitle(for: vm.mode))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { presenter.on(.done) } label: {
                    Text("common.done", bundle: .module)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                iOSConfirmationButton(vm: vm)
            }
        }
        .task { presenter.on(.load) }
    }

    @ViewBuilder
    private func iOSConfirmationButton(vm: CommitViewModel) -> some View {
        switch vm.mode {
        case .loading, .upToDate, .notBacked:
            EmptyView()
        case .localChanges:
            Menu {
                Button { presenter.on(.commit) } label: {
                    Label(String.localized("commit.action"), systemImage: "checkmark.circle")
                }
                Button { presenter.on(.commitAndPush) } label: {
                    Label(String.localized("commit.action.commit_and_push"), systemImage: "arrow.up.circle")
                }
                Button { presenter.on(.commitPushAndMerge) } label: {
                    Label(String.localized("commit.action.commit_push_merge"), systemImage: "arrow.triangle.merge")
                }
            } label: {
                Text("commit.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!vm.canCommit)
        case .pushNeeded:
            Menu {
                Button { presenter.on(.push) } label: {
                    Label(String.localized("sync.push.action"), systemImage: "arrow.up.circle")
                }
                Button { presenter.on(.pushAndMerge) } label: {
                    Label(String.localized("sync.push.action.push_and_merge"), systemImage: "arrow.triangle.merge")
                }
            } label: {
                Text("sync.push.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        case .pullNeeded:
            Button { presenter.on(.pull) } label: {
                Text("sync.pull.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        case .readyToMerge:
            Button { presenter.on(.merge) } label: {
                Text("sync.merge.action", bundle: .module).bold()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(vm.isLoading)
        }
    }
    #endif

    // MARK: - Shared

    @ViewBuilder
    private func localChangesContent(vm: CommitViewModel) -> some View {
        Section {
            TextField(text: Binding(
                get: { vm.commitMessage },
                set: { presenter.on(.editMessage($0)) }
            ), axis: .vertical) {
                if vm.isGeneratingMessage {
                    Text("commit.message.generating", bundle: .module)
                } else {
                    Text("commit.message.placeholder", bundle: .module)
                }
            }
            .lineLimit(3...6)
            .disabled(vm.isGeneratingMessage)
            #if os(macOS)
            .textFieldStyle(.roundedBorder)
            #endif
        } header: {
            Text("commit.message.header", bundle: .module)
        }

        Section {
            changesRows(vm: vm)
        } header: {
            Text("commit.changes_count \(vm.rows.count)", bundle: .module)
        }

        Section {
            Button(role: .destructive) {
                isShowingDiscardConfirmation = true
            } label: {
                Text("commit.discard.action", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .disabled(vm.isLoading)
            .confirmationDialog(
                Text("commit.discard.confirm.title", bundle: .module),
                isPresented: $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    presenter.on(.discard)
                } label: {
                    Text("commit.discard.confirm.action", bundle: .module)
                }
            } message: {
                Text("commit.discard.confirm.message", bundle: .module)
            }
        }
    }

    private func statusSection(
        systemImage: String,
        color: Color,
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(color)
                Text(title, bundle: .module)
                    .font(.headline)
                Text(description, bundle: .module)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private func navigationTitle(for mode: CommitViewModel.Mode) -> Text {
        switch mode {
        case .loading:
            Text("sync.up_to_date.nav_title", bundle: .module)
        case .localChanges:
            Text("commit.title", bundle: .module)
        case .pushNeeded:
            Text("sync.push.nav_title", bundle: .module)
        case .pullNeeded:
            Text("sync.pull.nav_title", bundle: .module)
        case .upToDate:
            Text("sync.up_to_date.nav_title", bundle: .module)
        case .notBacked:
            Text("sync.not_backed.nav_title", bundle: .module)
        case .readyToMerge:
            Text("sync.merge.nav_title", bundle: .module)
        }
    }

    @ViewBuilder
    private func changesRows(vm: CommitViewModel) -> some View {
        ForEach(vm.rows) { row in
            HStack {
                changeIcon(for: row.kind)
                Text(row.path)
                    .font(.body.monospaced())
                Spacer()
            }
            .tag(row.id)
            #if os(iOS)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    presenter.on(.discardFile(row.path))
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
                    presenter.on(.discardFile(row.path))
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
                presenter.on(.discardFile(rows[index].path))
            }
        }
        #endif
    }

    // MARK: - Commit log

    @ViewBuilder
    private func commitLogContent(vm: CommitViewModel) -> some View {
        if !vm.branchName.isEmpty {
            Text(vm.branchName)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
        }
        List {
            Section {
                commitLogRows(vm: vm)
            }
        }
    }

    @ViewBuilder
    private func commitLogSection(vm: CommitViewModel) -> some View {
        if !vm.branchName.isEmpty {
            Section {
                Label(vm.branchName, systemImage: "arrow.triangle.branch")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        Section {
            commitLogRows(vm: vm)
        }
    }

    @ViewBuilder
    private func commitLogRows(vm: CommitViewModel) -> some View {
        ForEach(vm.commitRows) { row in
            HStack(spacing: 8) {
                Image(systemName: row.isPushed ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(row.isPushed ? Color.green : Color.blue)
                    .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.message)
                        .font(.body)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(row.id)
                            .font(.caption.monospaced())
                        Text("·")
                        Text(row.date, style: .relative)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func changeIcon(for kind: CommitViewModel.ChangeKind) -> some View {
        switch kind {
        case .added:
            Image(systemName: "plus.circle.fill").foregroundStyle(.green)
        case .modified:
            Image(systemName: "pencil.circle.fill").foregroundStyle(.orange)
        case .deleted:
            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
        }
    }
}
