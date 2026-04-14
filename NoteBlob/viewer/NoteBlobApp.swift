import SwiftUI
import NoteBlobKit
import NoteBlobUI

@main
struct NoteBlobApp: App {

    private let presenterFactory: PresenterFactory

    init() {
        self.presenterFactory = PresenterFactory(
            dependencyProvider: DependencyProvider(localPathProvider: AppFolderLocalPathProvider())
        )
    }

    var body: some Scene {
        RootCoordinator(presenterFactory: presenterFactory)
    }
}
