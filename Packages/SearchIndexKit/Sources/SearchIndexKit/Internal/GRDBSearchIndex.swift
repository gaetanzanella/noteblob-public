import Foundation
import GRDB

final class GRDBSearchIndex: WriteSearchIndex, Sendable {

    private static let syncStateKey = "__sync_state__"

    private let dbQueue: DatabaseQueue

    init(databaseURL: URL) throws {
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createFTS") { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                    path UNINDEXED,
                    content
                )
                """)
        }
        return migrator
    }

    func search(query: String) async throws -> [SearchResult] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT path, snippet(notes_fts, 1, '<b>', '</b>', '...', 32) as snippet, rank
                    FROM notes_fts
                    WHERE notes_fts MATCH ?
                    AND path != ?
                    ORDER BY rank
                    """,
                arguments: [query, Self.syncStateKey]
            )
            return rows.map { row in
                SearchResult(
                    path: row["path"],
                    snippet: row["snippet"],
                    rank: row["rank"]
                )
            }
        }
    }

    func destroy() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM notes_fts")
        }
    }

    func rebuild(entries: [SearchIndexEntry]) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM notes_fts")
            for entry in entries {
                try db.execute(
                    sql: "INSERT INTO notes_fts (path, content) VALUES (?, ?)",
                    arguments: [entry.path, entry.content]
                )
            }
        }
    }

    func apply(_ changes: [SearchIndexChange]) async throws {
        try await dbQueue.write { db in
            for change in changes {
                switch change {
                case .updated(let entry):
                    try db.execute(
                        sql: "DELETE FROM notes_fts WHERE path = ?",
                        arguments: [entry.path]
                    )
                    try db.execute(
                        sql: "INSERT INTO notes_fts (path, content) VALUES (?, ?)",
                        arguments: [entry.path, entry.content]
                    )
                case .deleted(let path):
                    try db.execute(
                        sql: "DELETE FROM notes_fts WHERE path = ?",
                        arguments: [path]
                    )
                }
            }
        }
    }

    func readEntry(path: FilePath) async throws -> String? {
        try await dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: "SELECT content FROM notes_fts WHERE path = ?",
                arguments: [path]
            )
            return row?["content"] as? String
        }
    }
}
