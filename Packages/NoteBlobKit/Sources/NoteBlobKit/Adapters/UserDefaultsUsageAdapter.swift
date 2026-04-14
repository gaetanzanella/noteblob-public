import Foundation

final class UserDefaultsUsageAdapter: UsageRepository, @unchecked Sendable {

    private enum Keys {
        static let recentNotes = "usage.recentNotes"
        static let totalNoteAccessCount = "usage.totalNoteAccessCount"
    }

    private let defaults: UserDefaults
    private let maxEntries = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func recordNoteAccess(folderID: String, path: RelativePath, name: String) {
        var entries = loadEntries()
        entries.removeAll { $0.folderID == folderID && $0.path == path.value }
        let entry = NoteUsageEntry(
            folderID: folderID,
            path: path.value,
            name: name,
            date: Date()
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveEntries(entries)
    }

    func recentNotes(folderID: String, limit: Int) -> [NoteUsageEntry] {
        let entries = loadEntries()
        return Array(
            entries
                .filter { $0.folderID == folderID }
                .prefix(limit)
        )
    }

    func totalNoteAccessCount() -> Int {
        defaults.integer(forKey: Keys.totalNoteAccessCount)
    }

    func incrementNoteAccessCount() {
        let count = defaults.integer(forKey: Keys.totalNoteAccessCount)
        defaults.set(count + 1, forKey: Keys.totalNoteAccessCount)
    }

    // MARK: - Private

    private func loadEntries() -> [NoteUsageEntry] {
        guard let data = defaults.data(forKey: Keys.recentNotes) else { return [] }
        return (try? JSONDecoder().decode([NoteUsageEntry].self, from: data)) ?? []
    }

    private func saveEntries(_ entries: [NoteUsageEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.recentNotes)
    }
}
