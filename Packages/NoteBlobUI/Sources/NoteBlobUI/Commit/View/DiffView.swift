import SwiftUI
import NoteBlobKit

struct DiffView: View {

    @State var presenter: DiffPresenter

    init(presenter: DiffPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    var body: some View {
        let vm = presenter.viewModel()
        content(vm: vm)
            .navigationTitle(vm.title)
            .task { presenter.on(.load) }
    }

    @ViewBuilder
    private func content(vm: DiffViewModel) -> some View {
        if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = vm.errorMessage {
            ContentUnavailableView(
                errorMessage,
                systemImage: "exclamationmark.triangle"
            )
        } else if vm.hunks.isEmpty {
            ContentUnavailableView(
                "diff.empty.title",
                systemImage: "doc.text",
                description: Text("diff.empty.description", bundle: .module)
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(vm.hunks) { hunk in
                        hunkHeader(hunk.header)
                        ForEach(hunk.lines) { line in
                            lineRow(line)
                        }
                    }
                }
            }
        }
    }

    private func hunkHeader(_ header: String) -> some View {
        Text(header)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary)
    }

    private func lineRow(_ line: DiffViewModel.Line) -> some View {
        HStack(spacing: 4) {
            Text(prefix(for: line.kind))
                .foregroundStyle(color(for: line.kind))
            Text(line.content)
        }
        .font(.callout.monospaced())
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background(for: line.kind))
    }

    private func prefix(for kind: FileDiff.Hunk.Line.Kind) -> String {
        switch kind {
        case .context: " "
        case .addition: "+"
        case .deletion: "-"
        }
    }

    private func color(for kind: FileDiff.Hunk.Line.Kind) -> Color {
        switch kind {
        case .context: .secondary
        case .addition: .green
        case .deletion: .red
        }
    }

    private func background(for kind: FileDiff.Hunk.Line.Kind) -> Color {
        switch kind {
        case .context: .clear
        case .addition: .green.opacity(0.1)
        case .deletion: .red.opacity(0.1)
        }
    }
}
