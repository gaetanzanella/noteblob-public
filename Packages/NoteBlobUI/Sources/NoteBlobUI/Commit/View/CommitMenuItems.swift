import SwiftUI

struct CommitActionMenuItems: View {

    let onAction: (CommitViewAction) -> Void

    var body: some View {
        Button { onAction(.commit) } label: {
            Label(String.localized("commit.action"), systemImage: "checkmark.circle")
        }
        Button { onAction(.commitAndPush) } label: {
            Label(String.localized("commit.action.commit_and_push"), systemImage: "arrow.up.circle")
        }
        Button { onAction(.commitPushAndMerge) } label: {
            Label(String.localized("commit.action.commit_push_merge"), systemImage: "arrow.triangle.merge")
        }
    }
}

struct PushActionMenuItems: View {

    let onAction: (CommitViewAction) -> Void

    var body: some View {
        Button { onAction(.push) } label: {
            Label(String.localized("sync.push.action"), systemImage: "arrow.up.circle")
        }
        Button { onAction(.pushAndMerge) } label: {
            Label(String.localized("sync.push.action.push_and_merge"), systemImage: "arrow.triangle.merge")
        }
    }
}
