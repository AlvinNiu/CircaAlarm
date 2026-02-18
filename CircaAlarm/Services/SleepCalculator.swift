//
//  SleepCalculator.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import Foundation

// MARK: - 睡眠计算结果
struct SleepCalculationResult {
    let estimatedFallAsleepTime: Date    // 估算入睡时间
    let optimalWakeTime: Date?           // 最佳唤醒时间（可能为nil）
    let targetWakeTime: Date             // 预设起床时间
    let completedCycles: Int             // 完整周期数
    let totalSleepDuration: TimeInterval // 总可用睡眠时间
    let isValid: Bool                    // 是否满足条件
    let minutesEarlierThanTarget: Int    // 比预设时间提前多少分钟
    
    /// 最佳唤醒时间格式化显示
    var optimalWakeTimeDisplay: String {
        guard let time = optimalWakeTime else { return "无法计算" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    /// 预设起床时间格式化显示
    var targetWakeTimeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: targetWakeTime)
    }
    
    /// 估算入睡时间格式化显示
    var fallAsleepTimeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: estimatedFallAsleepTime)
    }
    
    /// 周期数显示
    var cyclesDisplay: String {
        return "\(completedCycles)个完整周期"
    }
    
    /// 睡眠时长显示
    var sleepDurationDisplay: String {
        if let optimal = optimalWakeTime {
            let duration = optimal.timeIntervalSince(estimatedFallAsleepTime)
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)小时\(minutes)分钟"
        }
        return "--"
    }
    
    /// 提前时间显示
    var earlierTimeDisplay: String {
        if minutesEarlierThanTarget > 0 {
            return "比预设时间早\(minutesEarlierThanTarget)分钟"
        } else if minutesEarlierThanTarget == 0 {
            return "与预设时间相同"
        } else {
            return "已错过最佳唤醒时间"
        }
    }
}

// MARK: - 睡眠周期计算器
class SleepCalculator {
    static let shared = SleepCalculator()
    
    private let cycleDuration: TimeInterval = 5400 // 90分钟 = 5400秒
    
    private init() {}
    
    /// 计算最佳唤醒时间
    /// - Parameters:
    ///   - bedTimeClicked: "我要睡了"点击时间
    ///   - fallAsleepDelay: 入睡所需时间（秒）
    ///   - targetWakeTime: 预设起床时间
    /// - Returns: 计算结果
    func calculateOptimalWakeTime(
        bedTimeClicked: Date,
        fallAsleepDelay: TimeInterval,
        targetWakeTime: Date
    ) -> SleepCalculationResult {
        // 估算入睡时间
        let estimatedFallAsleep = bedTimeClicked.addingTimeInterval(fallAsleepDelay)
        
        // 计算到目标时间的可用时长
        let timeUntilTarget = targetWakeTime.timeIntervalSince(estimatedFallAsleep)
        
        // 边界条件：不足一个完整周期
        guard timeUntilTarget >= cycleDuration else {
            return SleepCalculationResult(
                estimatedFallAsleepTime: estimatedFallAsleep,
                optimalWakeTime: nil,
                targetWakeTime: targetWakeTime,
                completedCycles: 0,
                totalSleepDuration: timeUntilTarget,
                isValid: false,
                minutesEarlierThanTarget: 0
            )
        }
        
        // 计算完整周期数（向下取整）
        let completedCycles = Int(floor(timeUntilTarget / cycleDuration))
        
        // 计算最佳唤醒时间
        var optimalWakeTime = estimatedFallAsleep.addingTimeInterval(
            TimeInterval(completedCycles) * cycleDuration
        )
        
        // 精度保护：确保不超过目标时间
        optimalWakeTime = min(optimalWakeTime, targetWakeTime)
        
        // 计算提前时间
        let minutesEarlier = Int(targetWakeTime.timeIntervalSince(optimalWakeTime) / 60)
        
        return SleepCalculationResult(
            estimatedFallAsleepTime: estimatedFallAsleep,
            optimalWakeTime: optimalWakeTime,
            targetWakeTime: targetWakeTime,
            completedCycles: completedCycles,
            totalSleepDuration: timeUntilTarget,
            isValid: true,
            minutesEarlierThanTarget: minutesEarlier
        )
    }
    
    /// 根据兜底策略确定最终响铃时间
    /// - Parameters:
    ///   - calculationResult: 计算结果
    ///   - fallbackStrategy: 兜底策略
    ///   - latestAlarmTime: 最晚响铃时间（可选）
    /// - Returns: 最终响铃时间和是否使用兜底
    func determineAlarmTime(
        calculationResult: SleepCalculationResult,
        fallbackStrategy: FallbackStrategy,
        latestAlarmTime: Date? = nil
    ) -> (alarmTime: Date, usedFallback: Bool, isOptimal: Bool) {
        // 智能唤醒可行
        if let optimal = calculationResult.optimalWakeTime {
            return (optimal, false, true)
        }
        
        // 触发兜底
        switch fallbackStrategy {
        case .latestTime:
            if let latest = latestAlarmTime {
                return (min(latest, calculationResult.targetWakeTime), true, false)
            }
            return (calculationResult.targetWakeTime, true, false)
        case .strictTarget, .smart: // smart失败时回退到strict
            return (calculationResult.targetWakeTime, true, false)
        }
    }
    
    /// 计算建议的就寝时间范围
    /// - Parameter targetWakeTime: 目标起床时间
    /// - Returns: (最早就寝时间, 最晚就寝时间)
    func calculateRecommendedBedtime(targetWakeTime: Date) -> (earliest: Date, latest: Date) {
        let calendar = Calendar.current
        
        // 推荐睡眠时长 7-9 小时
        let nineHoursBefore = calendar.date(byAdding: .hour, value: -9, to: targetWakeTime)!
        let sevenHoursBefore = calendar.date(byAdding: .hour, value: -7, to: targetWakeTime)!
        
        return (nineHoursBefore, sevenHoursBefore)
    }
    
    /// 格式化时间显示
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化日期时间显示
    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
}
