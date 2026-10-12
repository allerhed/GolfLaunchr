import Foundation
import SQLite3

/// A value bound to a statement parameter.
enum SQLValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case null
}

/// One result row. Column access is by index and mirrors the SELECT order.
struct SQLRow {
    fileprivate let statement: OpaquePointer

    func int(_ column: Int32) -> Int64 {
        sqlite3_column_int64(statement, column)
    }

    func double(_ column: Int32) -> Double {
        sqlite3_column_double(statement, column)
    }

    func isNull(_ column: Int32) -> Bool {
        sqlite3_column_type(statement, column) == SQLITE_NULL
    }

    func text(_ column: Int32) -> String {
        guard let raw = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: raw)
    }
}

/// Thin wrapper over the system SQLite. Not thread-safe by itself: it is only ever used from inside `SQLiteStore` (an actor).
final class SQLiteDatabase {
    private var handle: OpaquePointer?
    let path: String

    /// Opens (creating if missing) and configures the database: write-ahead log, full synchronous commits, foreign keys.
    /// A file that is not a SQLite database fails here with `.corrupt` and is left untouched.
    init(path: String) throws {
        self.path = path
        var opened: OpaquePointer?
        let code = sqlite3_open_v2(path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        handle = opened
        guard code == SQLITE_OK else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed (\(code))"
            sqlite3_close(opened)
            handle = nil
            throw PersistenceError.storageFailure("cannot open database: \(message)")
        }
        sqlite3_busy_timeout(opened, 5000)
        do {
            try exec("PRAGMA foreign_keys = ON")
            // Reading the header is what reveals a non-database file.
            _ = try query("PRAGMA schema_version") { $0.int(0) }
            _ = try query("PRAGMA journal_mode = WAL") { $0.text(0) }
            try exec("PRAGMA synchronous = FULL")
        } catch let error as PersistenceError {
            close()
            if case let .storageFailure(message) = error, message.contains("not a database") || message.contains("malformed") {
                throw PersistenceError.corrupt(path)
            }
            throw error
        }
    }

    deinit { close() }

    func close() {
        if let handle {
            sqlite3_close(handle)
        }
        handle = nil
    }

    private var message: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "database closed"
    }

    func exec(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw PersistenceError.storageFailure(message) }
    }

    /// Runs a statement and returns the number of rows changed.
    @discardableResult
    func run(_ sql: String, _ binds: [SQLValue] = []) throws -> Int {
        let statement = try prepare(sql, binds)
        defer { sqlite3_finalize(statement) }
        let code = sqlite3_step(statement)
        guard code == SQLITE_DONE || code == SQLITE_ROW else { throw PersistenceError.storageFailure(message) }
        return Int(sqlite3_changes(handle))
    }

    func query<T>(_ sql: String, _ binds: [SQLValue] = [], map: (SQLRow) throws -> T) throws -> [T] {
        let statement = try prepare(sql, binds)
        defer { sqlite3_finalize(statement) }
        var rows: [T] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                try rows.append(map(SQLRow(statement: statement)))
            } else if code == SQLITE_DONE {
                return rows
            } else {
                throw PersistenceError.storageFailure(message)
            }
        }
    }

    /// All-or-nothing: commits when `body` returns, rolls back when it throws.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try exec("COMMIT")
            return result
        } catch {
            _ = try? exec("ROLLBACK")
            throw error
        }
    }

    private func prepare(_ sql: String, _ binds: [SQLValue]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw PersistenceError.storageFailure(message)
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self) // SQLITE_TRANSIENT: SQLite copies the text
        for (offset, value) in binds.enumerated() {
            let index = Int32(offset + 1)
            let code: Int32 = switch value {
            case let .int(v): sqlite3_bind_int64(statement, index, v)
            case let .double(v): sqlite3_bind_double(statement, index, v)
            case let .text(v): sqlite3_bind_text(statement, index, v, -1, transient)
            case .null: sqlite3_bind_null(statement, index)
            }
            guard code == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw PersistenceError.storageFailure(message)
            }
        }
        return statement
    }
}
