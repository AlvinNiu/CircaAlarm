//
//  SleepRecord.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import Foundation

// MARK: - 舒适度枚举
enum ComfortLevel: String, Codable, CaseIterable {
    case comfortable = "comfortable"     // 舒适
    case uncomfortable = "uncomfortable" // 不舒服
    case skipped = "skipped"             // 用户主动跳过
    
    var displayName: String {
        switch self {
        case .comfortable:
            return "舒适"
        case .uncomfortable:
            return "不舒服"
        case .skipped:
            return "跳过"
        }
    }
    
    var icon: String {
        switch self {
        case .comfortable:
            return "😊"
        case .uncomfortable:
            return "😣"
        case .skipped:
            return "⏭️"
        }
    }
    
    var colorName: String {
        switch self {
        case .comfortable:
            return "green"
        case .uncomfortable:
            return "red"
        case .skipped:
            return "gray"
        }
    }
}

// MARK: - 兜底策略枚举
enum FallbackStrategy: String, Codable, CaseIterable {
    case smart = "smart"           // 智能优先
    case latestTime = "latestTime" // 最晚时间兜底
    case strictTarget = "strict"   // 严格按时
    
    var displayName: String {
        switch self {
        case .smart:
            return "智能优化"
        case .latestTime:
            return "最晚时间兜底"
        case .strictTarget:
            return "严格按时"
        }
    }
    
    var description: String {
        switch self {
        case .smart:
            return "优先在浅睡眠阶段唤醒，可能早于预设时间"
        case .latestTime:
            return "智能优化失败时，确保不晚于指定时间"
        case .strictTarget:
            return "始终在预设时间响铃，放弃周期优化"
        }
    }
}

// MARK: - 睡眠记录模型
struct SleepRecord: Identifiable, Codable {
    let id: UUID                    // 主键
    let date: Date                  // 记录日期
    let bedTimeClicked: Date        // "我要睡了"点击时间
    let estimatedFallAsleepTime: Date  // 估算入睡时间
    let targetWakeTime: Date        // 预设起床时间
    let plannedOptimalWakeTime: Date?  // 计划最佳唤醒时间（可能为nil）
    let actualAlarmTime: Date       // 实际响铃时间
    var actualWakeTime: Date?       // 实际醒来时间（用户停止闹钟）
    var snoozeCount: Int            // 延迟次数
    let usedFallback: Bool          // 是否使用兜底策略
    var comfortLevel: ComfortLevel? // 舒适度枚举
    
    // MARK: - 衍生计算属性
    
    /// 实际睡眠时长
    var actualSleepDuration: TimeInterval? {
        guard let wakeTime = actualWakeTime else { return nil }
        return wakeTime.timeIntervalSince(estimatedFallAsleepTime)
    }
    
    /// 完成的完整周期数
    var completedCycles: Int? {
        guard let duration = actualSleepDuration else { return nil }
        return Int(duration / 5400) // 90分钟 = 5400秒
    }
    
    /// 睡眠效率（百分比）
    var sleepEfficiency: Double? {
        guard let sleepDuration = actualSleepDuration,
              let wakeTime = actualWakeTime else { return nil }
        let timeInBed = wakeTime.timeIntervalSince(bedTimeClicked)
        guard timeInBed > 0 else { return nil }
        return (sleepDuration / timeInBed) * 100
    }
    
    /// 睡眠时长（小时）
    var sleepDurationHours: Double? {
        guard let duration = actualSleepDuration else { return nil }
        return duration / 3600
    }
    
    /// 格式化睡眠时长显示
    var sleepDurationDisplay: String {
        guard let hours = sleepDurationHours else { return "--" }
        let wholeHours = Int(hours)
        let minutes = Int((hours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)小时\(minutes)分钟"
        } else {
            return "\(wholeHours)小时"
        }
    }
}

// MARK: - 睡眠记录扩展（用于预览和测试）
extension SleepRecord {
    /// 创建示例记录
    static func sample() -> SleepRecord {
        let calendar = Calendar.current
        let bedTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date())!
        let fallAsleepTime = calendar.date(bySettingHour: 23, minute: 40, second: 0, of: Date())!
        let targetWake = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date().addingTimeInterval(86400))!
        let alarmTime = calendar.date(bySettingHour: 5, minute: 40, second: 0, of: Date().addingTimeInterval(86400))!
        let wakeTime = calendar.date(bySettingHour: 5, minute: 45, second: 0, of: Date().addingTimeInterval(86400))!
        
        return SleepRecord(
            id: UUID(),
            date: Date(),
            bedTimeClicked: bedTime,
            estimatedFallAsleepTime: fallAsleepTime,
            targetWakeTime: targetWake,
            plannedOptimalWakeTime: alarmTime,
            actualAlarmTime: alarmTime,
            actualWakeTime: wakeTime,
            snoozeCount: 0,
            usedFallback: false,
            comfortLevel: .comfortable
        )
    }
}
