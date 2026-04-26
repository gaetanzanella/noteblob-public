import Foundation

enum Alerts {

    static func folderAlreadyInstalled() -> AlertViewModel {
        AlertViewModel(
            title: .localized("branch_picker.already_installed.title"),
            message: .localized("branch_picker.already_installed.message"),
            actions: [.text(.localized("common.ok"), handler: {})]
        )
    }

    static func confirmDeleteFolder(
        name: String,
        onConfirm: @MainActor @Sendable @escaping () -> Void
    ) -> AlertViewModel {
        AlertViewModel(
            title: .localized("folder_list.delete.title"),
            message: .localized("folder_list.delete.message \(name)"),
            actions: [
                .text(.localized("common.delete"), role: .destructive, handler: onConfirm),
                .text(.localized("common.cancel"), role: .cancel, handler: {}),
            ]
        )
    }

    static func confirmDeleteItems(
        count: Int,
        onConfirm: @MainActor @Sendable @escaping () -> Void
    ) -> AlertViewModel {
        AlertViewModel(
            title: .localized("folder.delete.title"),
            message: .localized("folder.delete.message \(count)"),
            actions: [
                .text(.localized("common.delete"), role: .destructive, handler: onConfirm),
                .text(.localized("common.cancel"), role: .cancel, handler: {}),
            ]
        )
    }
}
