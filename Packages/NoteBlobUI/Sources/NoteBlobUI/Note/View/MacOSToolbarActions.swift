#if os(macOS)
import SwiftUI

struct MacOSToolbarActions: View {

    let actions: [ToolbarAction]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(actions.filter { !$0.isHidden }) { action in
                switch action.kind {
                case .button(let systemImage):
                    Button { action.action() } label: {
                        Image(systemName: systemImage)
                    }
                    .foregroundStyle(action.isActive ? Color.accentColor : .primary)
                    .disabled(!action.isEnabled)
                case .menu(let systemImage, let options):
                    Menu {
                        ForEach(options) { option in
                            Button {
                                option.action()
                            } label: {
                                Label(
                                    option.title,
                                    systemImage: option.systemImage ?? (option.isActive ? "checkmark" : "")
                                )
                            }
                            .disabled(!option.isEnabled)
                        }
                    } label: {
                        Image(systemName: systemImage)
                    }
                    .foregroundStyle(action.isActive ? Color.accentColor : .primary)
                    .disabled(!action.isEnabled)
                }
            }
        }
    }
}
#endif
