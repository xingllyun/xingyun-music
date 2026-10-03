import Foundation
import Combine
import SQLite3

/// 任务历史记录（§10）。
struct HistoryRecord: Identifiable, Codable, Equatable {
    var id: String
    var createdAt: Date
    var providerId: String
    var modelId: String            // 内部模型 ID（复用参数用）
    var modelName: String          // 自定义名快照
    var mode: CreationMode
    var lyrics: String?
    var prompt: String?
    var genre: String?
    var mood: String?
    var timbre: String?
    var gender: Gender?
    var outputPath: String?
    var durationMs: Int?
    var format: String?
    var watermarkPayload: UInt32?
    var costAmount: Double?
    var costUnit: String?
    var status: String             // success / failed
    var errorMessage: String?

    var statusText: String {
        switch status {
        case "success": return "成功"
        case "failed": return "失败"
        default: return status
        }
    }
}

/// 历史本地存储：SQLite（§3.1 / §10）。
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []
    private var db: OpaquePointer?

    init() {
        open()
        createTable()
        records = loadAll()
    }

    deinit {
        if let db = db { sqlite3_close(db) }
    }

    private func databaseURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("xingyun_history.sqlite")
    }

    private func open() {
        let url = databaseURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func createTable() {
        exec("""
        CREATE TABLE IF NOT EXISTS history (
            id TEXT PRIMARY KEY,
            created_at REAL,
            provider_id TEXT,
            model_id TEXT,
            model_name TEXT,
            mode TEXT,
            lyrics TEXT,
            prompt TEXT,
            genre TEXT,
            mood TEXT,
            timbre TEXT,
            gender TEXT,
            output_path TEXT,
            duration_ms INTEGER,
            format TEXT,
            watermark_payload INTEGER,
            cost_amount REAL,
            cost_unit TEXT,
            status TEXT,
            error_message TEXT
        );
        """)
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let e = err { sqlite3_free(e) }
        }
    }

    // MARK: - 增删查

    func insert(_ r: HistoryRecord) {
        let sql = """
        INSERT OR REPLACE INTO history
        (id, created_at, provider_id, model_id, model_name, mode, lyrics, prompt, genre, mood, timbre, gender,
         output_path, duration_ms, format, watermark_payload, cost_amount, cost_unit, status, error_message)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        bind(stmt, 1, r.id)
        bind(stmt, 2, r.createdAt.timeIntervalSince1970)
        bind(stmt, 3, r.providerId)
        bind(stmt, 4, r.modelId)
        bind(stmt, 5, r.modelName)
        bind(stmt, 6, r.mode.rawValue)
        bind(stmt, 7, r.lyrics)
        bind(stmt, 8, r.prompt)
        bind(stmt, 9, r.genre)
        bind(stmt, 10, r.mood)
        bind(stmt, 11, r.timbre)
        bind(stmt, 12, r.gender?.rawValue)
        bind(stmt, 13, r.outputPath)
        bind(stmt, 14, r.durationMs)
        bind(stmt, 15, r.format)
        if let p = r.watermarkPayload { sqlite3_bind_int64(stmt, 16, Int64(p)) } else { sqlite3_bind_null(stmt, 16) }
        bind(stmt, 17, r.costAmount)
        bind(stmt, 18, r.costUnit)
        bind(stmt, 19, r.status)
        bind(stmt, 20, r.errorMessage)

        sqlite3_step(stmt)
        if let idx = records.firstIndex(where: { $0.id == r.id }) {
            records[idx] = r
        } else {
            records.insert(r, at: 0)
        }
    }

    func delete(id: String, removeFile: Bool) {
        if removeFile, let r = records.first(where: { $0.id == id }), let path = r.outputPath {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        let sql = "DELETE FROM history WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, 1, id)
        sqlite3_step(stmt)
        records.removeAll { $0.id == id }
    }

    func clearOrphans() {
        // 清理无对应数据库记录的孤儿文件（§10.3）
        let dir = outputDirectory()
        let known = Set(records.compactMap(\.outputPath).map { URL(fileURLWithPath: $0).lastPathComponent })
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where !known.contains(f.lastPathComponent) {
            try? FileManager.default.removeItem(at: f)
        }
    }

    func outputDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func loadAll() -> [HistoryRecord] {
        let sql = "SELECT * FROM history ORDER BY created_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var result: [HistoryRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let r = rowToRecord(stmt) { result.append(r) }
        }
        return result
    }

    // MARK: - 绑定与读取

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ s: String?) {
        if let s = s {
            sqlite3_bind_text(stmt, idx, (s as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ d: Double?) {
        if let d = d { sqlite3_bind_double(stmt, idx, d) } else { sqlite3_bind_null(stmt, idx) }
    }

    private func bind(_ stmt: OpaquePointer?, _ idx: Int32, _ i: Int?) {
        if let i = i { sqlite3_bind_int64(stmt, idx, Int64(i)) } else { sqlite3_bind_null(stmt, idx) }
    }

    private func colText(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: c)
    }

    private func rowToRecord(_ stmt: OpaquePointer?) -> HistoryRecord? {
        guard let id = colText(stmt, 0) else { return nil }
        let mode = CreationMode(rawValue: colText(stmt, 5) ?? "") ?? .customLyrics
        let gender = (colText(stmt, 11)).flatMap(Gender.init(rawValue:))
        let payload = sqlite3_column_type(stmt, 15) == SQLITE_NULL ? nil : UInt32(sqlite3_column_int64(stmt, 15))

        return HistoryRecord(
            id: id,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            providerId: colText(stmt, 2) ?? "",
            modelId: colText(stmt, 3) ?? "",
            modelName: colText(stmt, 4) ?? "",
            mode: mode,
            lyrics: colText(stmt, 6),
            prompt: colText(stmt, 7),
            genre: colText(stmt, 8),
            mood: colText(stmt, 9),
            timbre: colText(stmt, 10),
            gender: gender,
            outputPath: colText(stmt, 12),
            durationMs: sqlite3_column_type(stmt, 13) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 13)),
            format: colText(stmt, 14),
            watermarkPayload: payload,
            costAmount: sqlite3_column_type(stmt, 16) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 16),
            costUnit: colText(stmt, 17),
            status: colText(stmt, 18) ?? "success",
            errorMessage: colText(stmt, 19)
        )
    }
}
