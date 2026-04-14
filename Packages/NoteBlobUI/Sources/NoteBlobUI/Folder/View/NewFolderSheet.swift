import SwiftUI

struct NewFolderSheet: View {

    let folderName: String
    let onCreate: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        macOSBody()
        #else
        iOSBody()
        #endif
    }

    // MARK: - macOS

    #if os(macOS)
    private func macOSBody() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("new_folder.title", bundle: .module)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(folderName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField(text: $name) {
                Text("new_folder.name.placeholder", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)

            Spacer()

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("common.cancel", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    onCreate(name)
                    dismiss()
                } label: {
                    Text("common.create", bundle: .module)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .scenePadding()
        .frame(minWidth: 350, minHeight: 180)
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private func iOSBody() -> some View {
        NavigationStack {
            Form {
                TextField(text: $name) {
                    Text("new_folder.name.placeholder", bundle: .module)
                }
            }
            .navigationTitle(Text("new_folder.title", bundle: .module))
            .navigationSubtitle(folderName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("common.cancel", bundle: .module)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onCreate(name)
                        dismiss()
                    } label: {
                        Text("common.create", bundle: .module)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    #endif
}
