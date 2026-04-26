import SwiftUI

struct CommitChangeIcon: View {

    let kind: CommitViewModel.ChangeKind

    var body: some View {
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
