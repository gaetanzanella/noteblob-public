import SwiftUI

public enum SyncFlowStep: CaseIterable {
    case commit, push, merge

    var label: LocalizedStringKey {
        switch self {
        case .commit: "sync.flow.step.commit.label"
        case .push: "sync.flow.step.push.label"
        case .merge: "sync.flow.step.merge.label"
        }
    }
}

struct SyncFlowStepView: View {

    let steps: [CommitViewModel.StepViewModel]
    let selectedStep: SyncFlowStep
    let onSelectStep: (SyncFlowStep) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, stepVM in
                if index > 0 {
                    line(reached: stepVM.dotState == .reached)
                }
                stepButton(stepVM)
            }
        }
        .frame(maxWidth: 350)
    }

    private func stepButton(_ stepVM: CommitViewModel.StepViewModel) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onSelectStep(stepVM.step)
            }
        } label: {
            VStack(spacing: 4) {
                stepIndicator(stepVM)
                Text(stepVM.step.label, bundle: .module)
                    .font(stepVM.dotState != .notReached ? .caption.bold() : .caption)
                    .foregroundStyle(stepVM.dotState != .notReached ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func stepIndicator(_ stepVM: CommitViewModel.StepViewModel) -> some View {
        ZStack {
            // Outer circle for current step
            if stepVM.isCurrent {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 22, height: 22)
            }
            // Inner dot based on dot state
            switch stepVM.dotState {
            case .selected:
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 12, height: 12)
            case .reached:
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
            case .notReached:
                Circle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 24, height: 24)
    }

    private func line(reached: Bool) -> some View {
        Rectangle()
            .fill(reached ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }
}
