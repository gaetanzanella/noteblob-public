import Foundation
@testable import SearchIndexKit

final class MockWriteSearchIndex: WriteSearchIndex, @unchecked Sendable {

    var entries: [SearchIndexEntry] = []
    var changes: [[SearchIndexChange]] = []

    var rebuildCallCount = 0
    var applyCallCount = 0
    var destroyCallCount = 0

    var shouldThrow: Error?
    var throwOnApplyAfter: Int?

    func destroy() async throws {
        destroyCallCount += 1
        if let error = shouldThrow { throw error }
        entries = []
    }

    func rebuild(entries: [SearchIndexEntry]) async throws {
        rebuildCallCount += 1
        if let error = shouldThrow { throw error }
        self.entries = entries
    }

    func apply(_ changes: [SearchIndexChange]) async throws {
        applyCallCount += 1
        if let error = shouldThrow { throw error }
        if let limit = throwOnApplyAfter, applyCallCount > limit {
            throw MockIndexError.simulatedCrash
        }
        self.changes.append(changes)
        for change in changes {
            switch change {
            case .updated(let entry):
                entries.removeAll { $0.path == entry.path }
                entries.append(entry)
            case .deleted(let path):
                entries.removeAll { $0.path == path }
            }
        }
    }

    func search(query: String) async throws -> [SearchResult] {
        []
    }

    func readEntry(path: FilePath) async throws -> String? {
        entries.first { $0.path == path }?.content
    }
}

enum MockIndexError: Error {
    case simulatedCrash
}
