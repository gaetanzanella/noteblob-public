import Foundation

struct SyncExecutor: Sendable {

    let source: SnapshotSource
    let store: WriteSearchIndex
    let batchSize: Int

    func readIndexState() async throws -> IndexState {
        let raw = try await store.readEntry(path: SyncToken.key)
        guard let raw else { return .empty }
        return .checkpoint(SyncToken.parse(raw))
    }

    func fullBuild(at snapshot: SnapshotID? = nil, startIndex: Int = 0) async throws
        -> SyncCheckpoint
    {
        let resolvedSnapshot: SnapshotID
        if let snapshot {
            let current = try await source.currentSnapshot()
            if current != snapshot {
                try await store.destroy()
                return try await fullBuild()
            }
            resolvedSnapshot = snapshot
        } else {
            resolvedSnapshot = try await source.currentSnapshot()
        }

        let allFiles = try await source.allFiles(at: resolvedSnapshot).sorted()
        try await indexBatched(snapshot: resolvedSnapshot, files: allFiles, startIndex: startIndex)
        return .synced(resolvedSnapshot)
    }

    func incrementalSync(from snapshot: SnapshotID) async throws -> SyncCheckpoint {
        let current = try await source.currentSnapshot()
        guard current != snapshot else { return .synced(snapshot) }

        let fileChanges = try await source.diff(from: snapshot, to: current)
        var indexChanges: [SearchIndexChange] = []
        for fileChange in fileChanges {
            switch fileChange {
            case .added(let path), .modified(let path):
                let content = try await source.fileContent(at: current, path: path)
                indexChanges.append(.updated(SearchIndexEntry(path: path, content: content)))
            case .deleted(let path):
                indexChanges.append(.deleted(path: path))
            }
        }
        indexChanges.append(.updated(SyncToken(checkpoint: .synced(current)).toEntry()))
        try await store.apply(indexChanges)
        return .synced(current)
    }

    // MARK: - Private

    private func indexBatched(
        snapshot: SnapshotID,
        files: [FilePath],
        startIndex: Int
    ) async throws {
        let total = files.count
        var currentIndex = startIndex

        while currentIndex < total {
            let endIndex = min(currentIndex + batchSize, total)
            let batch = Array(files[currentIndex..<endIndex])

            var changes: [SearchIndexChange] = []
            for path in batch {
                let content = try await source.fileContent(at: snapshot, path: path)
                changes.append(.updated(SearchIndexEntry(path: path, content: content)))
            }

            currentIndex = endIndex

            let isLastBatch = currentIndex >= total
            let token = isLastBatch
                ? SyncToken(checkpoint: .synced(snapshot))
                : SyncToken(checkpoint: .initializing(snapshot: snapshot, indexedCount: currentIndex))
            changes.append(.updated(token.toEntry()))
            try await store.apply(changes)
        }

        if total == 0 {
            try await store.apply([
                .updated(SyncToken(checkpoint: .synced(snapshot)).toEntry())
            ])
        }
    }
}

struct SyncToken: Sendable {

    static let key: FilePath = "__sync_state__"

    let checkpoint: SyncCheckpoint
}

// MARK: - Private

extension SyncToken {

    fileprivate func toEntry() -> SearchIndexEntry {
        let value: String
        switch checkpoint {
        case .synced(let snapshot):
            value = snapshot.value
        case .initializing(let snapshot, let count):
            value = "init:\(snapshot.value):\(count)"
        }
        return SearchIndexEntry(path: Self.key, content: value)
    }

    fileprivate static func parse(_ raw: String) -> SyncCheckpoint {
        if raw.hasPrefix("init:") {
            let parts = raw.split(separator: ":")
            if parts.count == 3,
                let count = Int(parts[2])
            {
                return .initializing(snapshot: SnapshotID(String(parts[1])), indexedCount: count)
            }
        }
        return .synced(SnapshotID(raw))
    }
}
