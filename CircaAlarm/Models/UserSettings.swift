//
//  UserSettings.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import Foundation

// MARK: - 用户设置模型
struct UserSettings: Codable {
    var targetWakeTime: DateComponents    // 目标起床时间（仅时分）
    var fallAsleepDelay: TimeInterval     // 入睡所需时间，默认600秒（10分钟）
    var wakeWindow: TimeInterval          // 唤醒窗口，默认600秒（±10分钟）
    var fallbackStrategy: FallbackStrategy // 兜底策略枚举
    var latestAlarmTime: DateComponents?  // 最晚响铃时间（可选）
    var selectedSound: String             // 铃声文件名
    var volumeFadeIn: Bool                // 音量渐变，默认true
    var vibrationEnabled: Bool            // 振动开关，默认true
    var maxSnoozeCount: Int               // 最大延迟次数，默认3次
    
    // MARK: - 默认值
    static let `default` = UserSettings(
        targetWakeTime: DateComponents(hour: 7, minute: 0),
        fallAsleepDelay: 600, // 10分钟
        wakeWindow: 600, // ±10分钟
        fallbackStrategy: .smart,
        latestAlarmTime: DateComponents(hour: 7, minute: 15),
        selectedSound: "鸟鸣",
        volumeFadeIn: true,
        vibrationEnabled: true,
        maxSnoozeCount: 3
    )
    
    // MARK: - 便捷方法
    
    /// 获取今天的目标起床时间
    func getTodayTargetWakeTime() -> Date {
        return getTargetWakeTime(for: Date())
    }
    
    /// 获取指定日期的目标起床时间
    func getTargetWakeTime(for date: Date) -> Date {
        var components = targetWakeTime
        components.year = nil
        components.month = nil
        components.day = nil
        
        let calendar = Calendar.current
        var targetDate = calendar.date(bySettingHour: components.hour ?? 7,
                                       minute: components.minute ?? 0,
                                       second: 0,
                                       of: date)!
        
        // 如果目标时间已过，设为第二天
        if targetDate <= date {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
        }
        
        return targetDate
    }
    
    /// 获取最晚响铃时间
    func getLatestAlarmTime(for date: Date) -> Date? {
        guard let latestComponents = latestAlarmTime else { return nil }
        
        let calendar = Calendar.current
        var latestDate = calendar.date(bySettingHour: latestComponents.hour ?? 7,
                                       minute: latestComponents.minute ?? 15,
                                       second: 0,
                                       of: date)!
        
        // 如果最晚时间已过，设为第二天
        if latestDate <= date {
            latestDate = calendar.date(byAdding: .day, value: 1, to: latestDate)!
        }
        
        return latestDate
    }
    
    /// 格式化入睡延迟显示
    var fallAsleepDelayDisplay: String {
        let minutes = Int(fallAsleepDelay / 60)
        return "\(minutes)分钟"
    }
    
    /// 格式化唤醒窗口显示
    var wakeWindowDisplay: String {
        let minutes = Int(wakeWindow / 60)
        return "±\(minutes)分钟"
    }
}
