#if os(macOS)
import SwiftUI

struct MacOSToolbarActions: View {

    let actions: [ToolbarAction]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(actions) { action in
                switch action.kind {
                case .headingMenu(let options):
                    Menu {
                        ForEach(options) { option in
                            Button(option.title) { option.action() }
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                case .button(let systemImage):
                    Button { action.action() } label: {
                        Image(systemName: systemImage)
                    }
                    .foregroundStyle(action.isActive ? Color.accentColor : .primary)
                }
            }
        }
    }
}
#endif
