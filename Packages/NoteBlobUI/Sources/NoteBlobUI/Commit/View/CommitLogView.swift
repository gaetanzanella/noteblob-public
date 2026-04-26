import SwiftUI

struct CommitLogView: View {

    let vm: CommitViewModel

    var body: some View {
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
}

/// Commit log wrapped in list sections, for use inside an iOS-style List.
struct CommitLogSectionView: View {

    let vm: CommitViewModel

    var body: some View {
        Section {
            CommitLogView(vm: vm)
        } header: {
            if !vm.branchName.isEmpty {
                Text(vm.branchName)
            }
        }
    }
}

/// Commit log with a branch header, for macOS VStack layout.
struct CommitLogContentView: View {

    let vm: CommitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Section {
                List {
                    CommitLogView(vm: vm)
                }
            } header: {
                if !vm.branchName.isEmpty {
                    Text(vm.branchName)
                }
            }
        }
    }
}
