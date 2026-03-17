import Foundation
import SQLite3

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "reminders-mac.db", qos: .userInitiated)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private init() {
        openDatabase()
        createTableIfNeeded()
        migrateTableIfNeeded()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RemindersMac", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let dbPath = dir.appendingPathComponent("reminders.db").path
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            NSLog("[DB] 打开数据库失败: %@", String(cString: sqlite3_errmsg(db)))
        }
    }

    private func createTableIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            scheduled_at TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
        );
        """
        execute(sql)
    }

    private func migrateTableIfNeeded() {
        queue.sync {
            guard hasColumn(named: "created_at") == false else {
                return
            }

            execute("ALTER TABLE reminders ADD COLUMN created_at TEXT")
            execute("UPDATE reminders SET created_at = datetime('now','localtime') WHERE created_at IS NULL")
        }
    }

    func fetchAll() -> [ReminderItem] {
        var items: [ReminderItem] = []
        queue.sync {
            let sql = "SELECT id, title, scheduled_at, is_completed, created_at FROM reminders ORDER BY scheduled_at ASC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(stmt, 0),
                      let titleCStr = sqlite3_column_text(stmt, 1),
                      let scheduledCStr = sqlite3_column_text(stmt, 2)
                else {
                    continue
                }

                let idString = String(cString: idCStr)
                let title = String(cString: titleCStr)
                let scheduledString = String(cString: scheduledCStr)
                let isCompleted = sqlite3_column_int(stmt, 3) != 0
                let createdString = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? scheduledString

                guard let uuid = UUID(uuidString: idString),
                      let scheduledAt = dateFormatter.date(from: scheduledString),
                      let createdAt = dateFormatter.date(from: createdString)
                else {
                    continue
                }

                items.append(
                    ReminderItem(
                        id: uuid,
                        title: title,
                        scheduledAt: scheduledAt,
                        createdAt: createdAt,
                        tone: isCompleted ? .completed : Self.tone(for: scheduledAt),
                        isCompleted: isCompleted,
                        showsMoreButton: !isCompleted
                    )
                )
            }
        }
        return items
    }

    func insert(_ item: ReminderItem) {
        queue.async { [self] in
            let sql = "INSERT INTO reminders (id, title, scheduled_at, is_completed, created_at) VALUES (?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }

            let idString = item.id.uuidString
            let scheduledString = dateFormatter.string(from: item.scheduledAt)
            let createdString = dateFormatter.string(from: item.createdAt)

            sqlite3_bind_text(stmt, 1, (idString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (item.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (scheduledString as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 4, item.isCompleted ? 1 : 0)
            sqlite3_bind_text(stmt, 5, (createdString as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                NSLog("[DB] insert 失败: %@", String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func update(_ item: ReminderItem) {
        queue.async { [self] in
            let sql = "UPDATE reminders SET title = ?, scheduled_at = ?, is_completed = ?, updated_at = datetime('now','localtime') WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }

            let scheduledString = dateFormatter.string(from: item.scheduledAt)
            let idString = item.id.uuidString

            sqlite3_bind_text(stmt, 1, (item.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (scheduledString as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 3, item.isCompleted ? 1 : 0)
            sqlite3_bind_text(stmt, 4, (idString as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                NSLog("[DB] update 失败: %@", String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func delete(id: UUID) {
        queue.async { [self] in
            let sql = "DELETE FROM reminders WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }

            let idString = id.uuidString
            sqlite3_bind_text(stmt, 1, (idString as NSString).utf8String, -1, nil)

            if sqlite3_step(stmt) != SQLITE_DONE {
                NSLog("[DB] delete 失败: %@", String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func deleteCompleted() {
        queue.async { [self] in
            execute("DELETE FROM reminders WHERE is_completed = 1")
        }
    }

    private func execute(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            NSLog("[DB] exec 失败: %@", String(cString: sqlite3_errmsg(db)))
        }
    }

    private func hasColumn(named columnName: String) -> Bool {
        let sql = "PRAGMA table_info(reminders)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let namePointer = sqlite3_column_text(stmt, 1) else {
                continue
            }
            if String(cString: namePointer) == columnName {
                return true
            }
        }

        return false
    }

    private static func tone(for date: Date) -> ReminderItem.ScheduleTone {
        date.timeIntervalSince(Date()) <= 60 * 60 ? .warning : .neutral
    }
}
