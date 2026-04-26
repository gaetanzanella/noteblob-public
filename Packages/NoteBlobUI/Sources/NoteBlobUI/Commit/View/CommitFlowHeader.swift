import SwiftUI

struct CommitFlowHeader: View {

    let vm: CommitViewModel
    let onSelectStep: (SyncFlowStep) -> Void

    var body: some View {
        if !vm.steps.isEmpty, let selectedStep = vm.selectedStep {
            SyncFlowStepView(
                steps: vm.steps,
                selectedStep: selectedStep,
                onSelectStep: onSelectStep
            )
        }
    }
}
