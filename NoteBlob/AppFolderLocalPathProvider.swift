import Foundation
import NoteBlobKit

struct AppFolderLocalPathProvider: FolderLocalPathProvider {

    func baseFoldersURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NoteBlob", isDirectory: true)
            .appendingPathComponent("repos", isDirectory: true)
    }

    func localPath(for folder: Folder) -> URL {
        baseFoldersURL().appendingPathComponent(folder.id, isDirectory: true)
    }
}
