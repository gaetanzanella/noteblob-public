import SwiftUI

struct StepExplanationView: View {

    let vm: CommitViewModel

    var body: some View {
        if let selectedStep = vm.selectedStep,
           let stepVM = vm.steps.first(where: { $0.step == selectedStep }) {
            Text(stepVM.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .animation(nil, value: selectedStep)
        }
    }
}
