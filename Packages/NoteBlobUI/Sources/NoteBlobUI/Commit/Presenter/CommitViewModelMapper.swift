import Foundation
import NoteBlobKit

struct CommitViewModelMapper {

    func map(_ state: CommitState) -> CommitViewModel {
        let mode = mapMode(state.syncStatus)
        let currentStep = mapSyncFlowStep(mode)
        let selectedStep = state.selectedStep ?? currentStep
        return CommitViewModel(
            mode: mode,
            navigationTitle: mapNavigationTitle(mode),
            isSelectionEnabled: mode == .localChanges,
            commitMessage: state.commitMessage,
            rows: state.changes.map { mapRow($0) },
            branchName: state.syncStatus?.branch.name ?? "",
            commitRows: mapCommitRows(state.commitLog, unpushedCount: state.unpushedCount),
            isLoading: state.isLoading,
            isGeneratingMessage: state.isGeneratingMessage,
            errorMessage: state.errorMessage,
            needsAuth: state.needsAuth,
            steps: mapSteps(state, currentStep: currentStep, selectedStep: selectedStep),
            selectedStep: selectedStep
        )
    }

    // MARK: - Mode

    private func mapMode(_ status: SyncStatus?) -> CommitViewModel.Mode {
        guard let status else { return .loading }
        return switch status.state {
        case .upToDate: .upToDate
        case .localChanges: .localChanges
        case .pushNeeded: .pushNeeded
        case .pullNeeded: .pullNeeded
        case .readyToMerge: .readyToMerge
        case .notBacked: .notBacked
        }
    }

    // MARK: - Navigation Title

    private func mapNavigationTitle(_ mode: CommitViewModel.Mode) -> String {
        switch mode {
        case .loading, .upToDate:
            String(localized: "sync.up_to_date.nav_title", bundle: .module)
        case .localChanges:
            String(localized: "commit.title", bundle: .module)
        case .pushNeeded:
            String(localized: "sync.push.nav_title", bundle: .module)
        case .pullNeeded:
            String(localized: "sync.pull.nav_title", bundle: .module)
        case .notBacked:
            String(localized: "sync.not_backed.nav_title", bundle: .module)
        case .readyToMerge:
            String(localized: "sync.merge.nav_title", bundle: .module)
        }
    }

    // MARK: - Rows

    private func mapRow(_ change: Change) -> CommitViewModel.Row {
        CommitViewModel.Row(
            id: change.path,
            path: change.path,
            kind: mapChangeKind(change)
        )
    }

    private func mapChangeKind(_ change: Change) -> CommitViewModel.ChangeKind {
        switch change {
        case .added: .added
        case .modified: .modified
        case .deleted: .deleted
        }
    }

    private func mapCommitRows(_ log: [CommitInfo], unpushedCount: Int) -> [CommitViewModel.CommitRow] {
        log.enumerated().map { index, commit in
            CommitViewModel.CommitRow(
                id: commit.id,
                message: commit.message,
                date: commit.date,
                isPushed: index >= unpushedCount
            )
        }
    }

    // MARK: - Steps

    private func mapSyncFlowStep(_ mode: CommitViewModel.Mode) -> SyncFlowStep? {
        switch mode {
        case .localChanges: .commit
        case .pushNeeded: .push
        case .readyToMerge: .merge
        case .loading, .pullNeeded, .upToDate, .notBacked: nil
        }
    }

    private func mapSteps(_ state: CommitState, currentStep: SyncFlowStep?, selectedStep: SyncFlowStep?) -> [CommitViewModel.StepViewModel] {
        guard let currentStep else { return [] }
        let allSteps = SyncFlowStep.allCases
        let currentIndex = allSteps.firstIndex(of: currentStep) ?? 0
        return allSteps.enumerated().map { index, step in
            let dotState: CommitViewModel.DotState
            if step == selectedStep {
                dotState = .selected
            } else if index <= currentIndex {
                dotState = .reached
            } else {
                dotState = .notReached
            }
            return CommitViewModel.StepViewModel(
                step: step,
                dotState: dotState,
                isCurrent: step == currentStep,
                explanation: mapStepExplanation(for: step, currentStep: currentStep, state: state)
            )
        }
    }

    private func mapStepExplanation(for step: SyncFlowStep, currentStep: SyncFlowStep, state: CommitState) -> String {
        let branchName = state.syncStatus?.branch.name ?? ""
        let isMain = state.syncStatus.map { state.payload.folder.isDefault($0.branch) } ?? true

        switch step {
        case .commit:
            if step == currentStep {
                if isMain {
                    return String(localized: "sync.flow.commit.current.on_main", bundle: .module)
                }
                return String(localized: "sync.flow.commit.current.on_branch \(branchName)", bundle: .module)
            }
            return String(localized: "sync.flow.commit.done \(branchName)", bundle: .module)

        case .push:
            if step == currentStep {
                return String(localized: "sync.flow.push.current \(branchName)", bundle: .module)
            }
            if currentStep == .commit {
                return String(localized: "sync.flow.push.upcoming", bundle: .module)
            }
            return String(localized: "sync.flow.push.done \(branchName)", bundle: .module)

        case .merge:
            if step == currentStep {
                return String(localized: "sync.flow.merge.current \(branchName)", bundle: .module)
            }
            return String(localized: "sync.flow.merge.upcoming", bundle: .module)
        }
    }
}
