import SwiftUI

public struct URLLinkSheet: View {

    @State private var presenter: URLLinkPresenter
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case url
    }

    public init(presenter: URLLinkPresenter) {
        self._presenter = State(initialValue: presenter)
    }

    public var body: some View {
        let vm = presenter.viewModel()
        NavigationStack {
            Form {
                Section {
                    TextField(
                        text: Binding(
                            get: { vm.title },
                            set: { presenter.on(.updateTitle($0)) }
                        )
                    ) {
                        Text("note.link.url.title_field", bundle: .module)
                    }
                    .focused($focusedField, equals: .title)

                    TextField(
                        text: Binding(
                            get: { vm.urlString },
                            set: { presenter.on(.updateURL($0)) }
                        )
                    ) {
                        Text("note.link.url.url_field", bundle: .module)
                    }
                    .focused($focusedField, equals: .url)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    #endif
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("note.link.url.title", bundle: .module))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { focusedField = .title }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        presenter.on(.confirm)
                    } label: {
                        Text("note.link.url.confirm", bundle: .module).bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!vm.isConfirmEnabled)
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 420, minHeight: 260)
        #endif
    }
}
