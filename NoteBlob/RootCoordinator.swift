import NoteBlobKit
import NoteBlobUI
import SwiftUI

struct RootCoordinator: Scene {

    let presenterFactory: PresenterFactory
    @State private var rootPresenter: RootPresenter

    #if os(macOS)
    @State private var isShowingAccount = false
    #endif

    init(presenterFactory: PresenterFactory) {
        self.presenterFactory = presenterFactory
        self._rootPresenter = State(initialValue: presenterFactory.makeRootPresenter())
    }

    var body: some Scene {
        WindowGroup {
            MainCoordinator(
                presenterFactory: presenterFactory,
                onLogout: {}
            )
            .task {
                await rootPresenter.onAsync(.onAppear)
            }
            #if os(macOS)
            .sheet(isPresented: $isShowingAccount) {
                AccountView(
                    presenter: presenterFactory.makeAccountPresenter { _ in
                        isShowingAccount = false
                    }
                )
            }
            #endif
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Account...") {
                    isShowingAccount = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
        #if os(macOS)
        WindowGroup(for: NoteNavigationPayload.self) { $payload in
            if let payload {
                NoteCoordinator(
                    presenterFactory: presenterFactory,
                    payload: payload
                )
            }
        }
        #endif
    }
}
