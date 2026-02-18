//
//  DataStore.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import Foundation
import Combine
import SQLite3

// MARK: - 数据存储管理器
class DataStore: ObservableObject {
    static let shared = DataStore()
    
    @Published var settings: UserSettings = .default
    @Published var sleepRecords: [SleepRecord] = []
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    // UserDefaults 键名
    private let settingsKey = "com.bioalarm.usersettings"
    
    private init() {
        // 设置数据库路径
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        dbPath = urls[0].appendingPathComponent("sleep_records.db").path
        
        // 初始化
        loadSettings()
        openDatabase()
        createTableIfNeeded()
        loadSleepRecords()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    // MARK: - UserDefaults 设置管理
    
    /// 加载用户设置
    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }
    
    /// 保存用户设置
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    // MARK: - SQLite 数据库管理
    
    /// 打开数据库
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("无法打开数据库")
            db = nil
        }
    }
    
    /// 创建表（如果不存在）
    private func createTableIfNeeded() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS sleep_records (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                bed_time_clicked TEXT NOT NULL,
                estimated_fall_asleep_time TEXT NOT NULL,
                target_wake_time TEXT NOT NULL,
                planned_optimal_wake_time TEXT,
                actual_alarm_time TEXT NOT NULL,
                actual_wake_time TEXT,
                snooze_count INTEGER DEFAULT 0,
                used_fallback INTEGER DEFAULT 0,
                comfort_level TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_date ON sleep_records(date);
        """
        
        var errorMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &errorMsg) != SQLITE_OK {
            let message = String(cString: errorMsg!)
            print("创建表失败: \(message)")
            sqlite3_free(errorMsg)
        }
    }
    
    /// 加载所有睡眠记录
    func loadSleepRecords() {
        sleepRecords.removeAll()
        
        let querySQL = "SELECT * FROM sleep_records ORDER BY date DESC;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK,
              let stmt = statement else {
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let record = parseRecord(from: stmt, dateFormatter: dateFormatter) {
                sleepRecords.append(record)
            }
        }
        
        sqlite3_finalize(stmt)
    }
    
    /// 解析数据库记录
    private func parseRecord(from statement: OpaquePointer, dateFormatter: ISO8601DateFormatter) -> SleepRecord? {
        guard let idString = sqlite3_column_text(statement, 0).flatMap({ String(cString: $0) }),
              let id = UUID(uuidString: idString),
              let dateString = sqlite3_column_text(statement, 1).flatMap({ String(cString: $0) }),
              let date = dateFormatter.date(from: dateString),
              let bedTimeString = sqlite3_column_text(statement, 2).flatMap({ String(cString: $0) }),
              let bedTime = dateFormatter.date(from: bedTimeString),
              let fallAsleepString = sqlite3_column_text(statement, 3).flatMap({ String(cString: $0) }),
              let fallAsleepTime = dateFormatter.date(from: fallAsleepString),
              let targetWakeString = sqlite3_column_text(statement, 4).flatMap({ String(cString: $0) }),
              let targetWakeTime = dateFormatter.date(from: targetWakeString),
              let alarmTimeString = sqlite3_column_text(statement, 6).flatMap({ String(cString: $0) }),
              let alarmTime = dateFormatter.date(from: alarmTimeString) else {
            return nil
        }
        
        let plannedOptimalTime = sqlite3_column_text(statement, 5).flatMap { String(cString: $0) }.flatMap { dateFormatter.date(from: $0) }
        let actualWakeTime = sqlite3_column_text(statement, 7).flatMap { String(cString: $0) }.flatMap { dateFormatter.date(from: $0) }
        let snoozeCount = Int(sqlite3_column_int(statement, 8))
        let usedFallback = sqlite3_column_int(statement, 9) != 0
        let comfortLevelString = sqlite3_column_text(statement, 10).flatMap { String(cString: $0) }
        let comfortLevel = comfortLevelString.flatMap { ComfortLevel(rawValue: $0) }
        
        return SleepRecord(
            id: id,
            date: date,
            bedTimeClicked: bedTime,
            estimatedFallAsleepTime: fallAsleepTime,
            targetWakeTime: targetWakeTime,
            plannedOptimalWakeTime: plannedOptimalTime,
            actualAlarmTime: alarmTime,
            actualWakeTime: actualWakeTime,
            snoozeCount: snoozeCount,
            usedFallback: usedFallback,
            comfortLevel: comfortLevel
        )
    }
    
    /// 插入睡眠记录
    func insertSleepRecord(_ record: SleepRecord) -> Bool {
        let insertSQL = """
            INSERT INTO sleep_records (
                id, date, bed_time_clicked, estimated_fall_asleep_time,
                target_wake_time, planned_optimal_wake_time, actual_alarm_time,
                actual_wake_time, snooze_count, used_fallback, comfort_level
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        sqlite3_bind_text(statement, 1, (record.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (dateFormatter.string(from: record.date) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (dateFormatter.string(from: record.bedTimeClicked) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (dateFormatter.string(from: record.estimatedFallAsleepTime) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 5, (dateFormatter.string(from: record.targetWakeTime) as NSString).utf8String, -1, nil)
        
        if let optimalTime = record.plannedOptimalWakeTime {
            sqlite3_bind_text(statement, 6, (dateFormatter.string(from: optimalTime) as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 6)
        }
        
        sqlite3_bind_text(statement, 7, (dateFormatter.string(from: record.actualAlarmTime) as NSString).utf8String, -1, nil)
        
        if let wakeTime = record.actualWakeTime {
            sqlite3_bind_text(statement, 8, (dateFormatter.string(from: wakeTime) as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        
        sqlite3_bind_int(statement, 9, Int32(record.snoozeCount))
        sqlite3_bind_int(statement, 10, record.usedFallback ? 1 : 0)
        
        if let comfort = record.comfortLevel {
            sqlite3_bind_text(statement, 11, (comfort.rawValue as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 11)
        }
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            sleepRecords.insert(record, at: 0)
        }
        
        return result
    }
    
    /// 更新睡眠记录（用于更新醒来时间和舒适度）
    func updateSleepRecord(_ record: SleepRecord) -> Bool {
        let updateSQL = """
            UPDATE sleep_records SET
                actual_wake_time = ?,
                snooze_count = ?,
                comfort_level = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        if let wakeTime = record.actualWakeTime {
            sqlite3_bind_text(statement, 1, (dateFormatter.string(from: wakeTime) as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 1)
        }
        
        sqlite3_bind_int(statement, 2, Int32(record.snoozeCount))
        
        if let comfort = record.comfortLevel {
            sqlite3_bind_text(statement, 3, (comfort.rawValue as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        
        sqlite3_bind_text(statement, 4, (record.id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result, let index = sleepRecords.firstIndex(where: { $0.id == record.id }) {
            sleepRecords[index] = record
        }
        
        return result
    }
    
    /// 删除睡眠记录
    func deleteSleepRecord(id: UUID) -> Bool {
        let deleteSQL = "DELETE FROM sleep_records WHERE id = ?;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)
        
        let result = sqlite3_step(statement) == SQLITE_DONE
        sqlite3_finalize(statement)
        
        if result {
            sleepRecords.removeAll { $0.id == id }
        }
        
        return result
    }
    
    /// 获取今天的睡眠记录（未完成）
    func getTodayUnfinishedRecord() -> SleepRecord? {
        let calendar = Calendar.current
        return sleepRecords.first { record in
            calendar.isDateInToday(record.date) && record.actualWakeTime == nil
        }
    }
}
