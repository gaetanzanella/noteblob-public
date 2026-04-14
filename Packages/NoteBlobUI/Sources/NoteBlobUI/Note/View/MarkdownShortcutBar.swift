import SwiftUI

struct MarkdownShortcutBar: View {

    let actions: [ToolbarAction]
    let onDismissKeyboard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        switch action.kind {
                        case .headingMenu(let options):
                            headingMenu(options: options)
                        case .button(let systemImage):
                            iconButton(systemImage: systemImage, isActive: action.isActive, action: action.action)
                        }
                    }
                }
                .padding(.leading, 8)
            }
            .scrollContentBackground(.hidden)
            Button {
                onDismissKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
            }
        }
    }

    private func headingMenu(options: [ToolbarAction.HeadingOption]) -> some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) { option.action() }
            }
        } label: {
            Image(systemName: "textformat.size")
                .frame(minWidth: 28, minHeight: 28)
        }
    }

    private func iconButton(systemImage: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .frame(minWidth: 28, minHeight: 28)
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .background(isActive ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
