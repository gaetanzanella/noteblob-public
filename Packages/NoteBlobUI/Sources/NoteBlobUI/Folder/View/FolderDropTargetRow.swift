import SwiftUI

enum DropOperation {
    case move
    case copy
}

struct FolderDropTargetRow: View {

    let title: String
    let systemImage: String
    let onDrop: ([NoteItemTransfer], DropOperation) -> Bool

    @State private var isTargeted = false
    #if os(macOS)
    @State private var optionKeyPressed = false
    #endif

    var body: some View {
        DisclosureRow(title: title, systemImage: systemImage)
            .dropDestination(for: NoteItemTransfer.self) { items, _ in
                #if os(macOS)
                let operation: DropOperation = optionKeyPressed ? .copy : .move
                #else
                let operation: DropOperation = .move
                #endif
                return onDrop(items, operation)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            #if os(macOS)
            .onModifierKeysChanged(mask: .option) { _, new in
                optionKeyPressed = !new.isEmpty
            }
            #endif
    }
}
