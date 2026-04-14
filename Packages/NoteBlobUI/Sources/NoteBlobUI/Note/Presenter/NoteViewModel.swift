import Foundation

enum PreviewMode {
    case formatted
    case raw
}

struct ToolbarAction: Identifiable {

    struct HeadingOption: Identifiable {
        let id: Int
        let title: String
        let action: () -> Void
    }

    enum Kind {
        case button(systemImage: String)
        case headingMenu([HeadingOption])
    }

    struct KeyboardShortcut {
        let key: Character
        let shift: Bool

        init(_ key: Character, shift: Bool = false) {
            self.key = key
            self.shift = shift
        }
    }

    let id: String
    let kind: Kind
    let isActive: Bool
    let keyboardShortcut: KeyboardShortcut?
    let localizedTitle: String
    let action: () -> Void

    init(
        id: String,
        kind: Kind,
        isActive: Bool,
        keyboardShortcut: KeyboardShortcut? = nil,
        localizedTitle: String = "",
        action: @escaping () -> Void
    ) {
        self.id = id
        self.kind = kind
        self.isActive = isActive
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
    let errorMessage: String?
}
