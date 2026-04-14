import CoreTransferable
import NoteBlobKit
import UniformTypeIdentifiers

extension UTType {
    static let noteItemTransfer = UTType(exportedAs: "com.noteblob.note-item-transfer", conformingTo: .data)
}

struct NoteItemTransfer: Codable, Transferable {
    let folder: Folder
    let items: [NoteItem]

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .noteItemTransfer)
    }
}
