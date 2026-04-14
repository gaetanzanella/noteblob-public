import SwiftUI

struct NewNoteSheet: View {

    let folderName: String
    let onCreate: (String) -> Void
    @State private var filename = ""
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
            Text("new_note.title", bundle: .module)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(folderName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField(text: $filename) {
                Text("new_note.filename.placeholder", bundle: .module)
            }
            .textFieldStyle(.roundedBorder)

            Text("new_note.extension_hint", bundle: .module)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text("common.cancel", bundle: .module)
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    onCreate(filename)
                    dismiss()
                } label: {
                    Text("common.create", bundle: .module)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .scenePadding()
        .frame(minWidth: 350, minHeight: 200)
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private func iOSBody() -> some View {
        NavigationStack {
            Form {
                TextField(text: $filename) {
                    Text("new_note.filename.placeholder", bundle: .module)
                }
                Text("new_note.extension_hint", bundle: .module)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(Text("new_note.title", bundle: .module))
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
                        onCreate(filename)
                        dismiss()
                    } label: {
                        Text("common.create", bundle: .module)
                            .bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(filename.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    #endif
}
