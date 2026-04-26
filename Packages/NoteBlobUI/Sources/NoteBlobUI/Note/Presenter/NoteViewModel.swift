import Foundation

enum PreviewMode {
    case formatted
    case raw
}

struct ToolbarAction: Identifiable {

    struct MenuOption: Identifiable {
        let id: String
        let title: String
        let systemImage: String?
        let isActive: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    enum Kind {
        case button(systemImage: String)
        case menu(systemImage: String, options: [MenuOption])
    }

    struct KeyboardShortcut {
        let key: Character
        let shift: Bool
        let command: Bool

        init(_ key: Character, shift: Bool = false, command: Bool = true) {
            self.key = key
            self.shift = shift
            self.command = command
        }
    }

    let id: String
    let kind: Kind
    let isActive: Bool
    let isEnabled: Bool
    let isHidden: Bool
    let keyboardShortcut: KeyboardShortcut?
    let localizedTitle: String
    let action: () -> Void

    init(
        id: String,
        kind: Kind,
        isActive: Bool,
        isEnabled: Bool,
        isHidden: Bool = false,
        keyboardShortcut: KeyboardShortcut? = nil,
        localizedTitle: String = "",
        action: @escaping () -> Void
    ) {
        self.id = id
        self.kind = kind
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.isHidden = isHidden
        self.keyboardShortcut = keyboardShortcut
        self.localizedTitle = localizedTitle
        self.action = action
    }
}

struct NoteViewModel {

    let latestChangeDate: Date?

    var formattedDate: String {
        guard let date = latestChangeDate else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    enum Mode {
        case editing
        case preview(PreviewMode)

        var isEditing: Bool {
            switch self {
            case .editing: true
            case .preview: false
            }
        }

        var previewMode: PreviewMode {
            switch self {
            case .editing: .formatted
            case .preview(let mode): mode
            }
        }

    }

    let title: String
    let mode: Mode
    let toolbarActions: [ToolbarAction]
    let menuActions: [ToolbarAction]
    let undoRedoActions: [ToolbarAction]
    let errorMessage: String?
}
