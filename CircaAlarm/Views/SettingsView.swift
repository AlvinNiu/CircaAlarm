//
//  SettingsView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI
import Combine
import UserNotifications
import UIKit

// MARK: - 设置页
struct SettingsView: View {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 临时设置值
    @State private var targetWakeTime: Date
    @State private var fallAsleepDelayIndex: Int
    @State private var wakeWindowIndex: Int
    @State private var fallbackStrategy: FallbackStrategy
    @State private var latestAlarmTime: Date?
    @State private var maxSnoozeCount: Int
    @State private var volumeFadeIn: Bool
    @State private var vibrationEnabled: Bool
    
    let delayOptions: [TimeInterval] = [300, 600, 900, 1200, 1500, 1800]
    let windowOptions: [TimeInterval] = [300, 600, 900, 1200, 1800]
    
    init() {
        let settings = DataStore.shared.settings
        
        // 转换目标起床时间为 Date
        var components = settings.targetWakeTime
        components.year = 2026
        components.month = 1
        components.day = 1
        _targetWakeTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        
        // 找到最接近的索引
        _fallAsleepDelayIndex = State(initialValue: delayOptions.firstIndex(of: settings.fallAsleepDelay) ?? 1)
        _wakeWindowIndex = State(initialValue: windowOptions.firstIndex(of: settings.wakeWindow) ?? 1)
        _fallbackStrategy = State(initialValue: settings.fallbackStrategy)
        
        // 最晚响铃时间
        if let latestComponents = settings.latestAlarmTime {
            var latestComps = latestComponents
            latestComps.year = 2026
            latestComps.month = 1
            latestComps.day = 1
            _latestAlarmTime = State(initialValue: Calendar.current.date(from: latestComps))
        } else {
            _latestAlarmTime = State(initialValue: nil)
        }
        
        _maxSnoozeCount = State(initialValue: settings.maxSnoozeCount)
        _volumeFadeIn = State(initialValue: settings.volumeFadeIn)
        _vibrationEnabled = State(initialValue: settings.vibrationEnabled)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                List {
                    // 时间设置
                    timeSettingsSection
                    
                    // 兜底策略
                    fallbackStrategySection
                    
                    // 闹钟偏好
                    alarmPreferencesSection
                    
                    // 数据管理
                    dataManagementSection
                    
                    // 使用提示
                    tipsSection
                    
                    // 应用信息
                    appInfoSection
                }
                #if !os(macOS)
                .listStyle(.insetGrouped)
                #endif
            }
            .navigationTitle("设置")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            #endif
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - 时间设置
    private var timeSettingsSection: some View {
        Section {
            // 目标起床时间
            DatePicker(
                "目标起床时间",
                selection: $targetWakeTime,
                displayedComponents: .hourAndMinute
            )
            
            // 入睡所需时间
            VStack(alignment: .leading, spacing: 8) {
                Text("入睡所需时间: \(Int(delayOptions[fallAsleepDelayIndex] / 60))分钟")
                    .font(.system(size: 16))
                
                Picker("入睡所需时间", selection: $fallAsleepDelayIndex) {
                    ForEach(0..<delayOptions.count, id: \.self) { index in
                        Text("\(Int(delayOptions[index] / 60))分钟").tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
            
            // 唤醒窗口
            VStack(alignment: .leading, spacing: 8) {
                Text("唤醒窗口: ±\(Int(windowOptions[wakeWindowIndex] / 60))分钟")
                    .font(.system(size: 16))
                
                Picker("唤醒窗口", selection: $wakeWindowIndex) {
                    ForEach(0..<windowOptions.count, id: \.self) { index in
                        Text("±\(Int(windowOptions[index] / 60))分").tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        } header: {
            Text("时间设置")
        }
    }
    
    // MARK: - 兜底策略
    private var fallbackStrategySection: some View {
        Section {
            Picker("兜底策略", selection: $fallbackStrategy) {
                ForEach(FallbackStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            #else
            .pickerStyle(.navigationLink)
            #endif
            
            if fallbackStrategy == .latestTime {
                if let _ = latestAlarmTime {
                    DatePicker(
                        "最晚响铃时间",
                        selection: Binding(
                            get: { latestAlarmTime ?? Date() },
                            set: { latestAlarmTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
            
            // 兜底策略说明
            Text(fallbackStrategy.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        } header: {
            Text("兜底策略")
        }
    }
    
    // MARK: - 闹钟偏好
    private var alarmPreferencesSection: some View {
        Section {
            // 最大延迟次数
            Stepper("最大延迟次数: \(maxSnoozeCount)次", value: $maxSnoozeCount, in: 1...5)
            
            // 振动开关
            Toggle("振动提醒", isOn: $vibrationEnabled)
        } header: {
            Text("闹钟偏好")
        } footer: {
            Text("闹钟将通过系统通知声音叫醒您。请确保系统音量和通知音量已开启。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 数据管理
    private var dataManagementSection: some View {
        Section {
            Button(action: {
                #if canImport(UIKit)
                HapticManager.shared.impact(style: .light)
                #endif
                checkPendingNotifications()
            }) {
                HStack {
                    Image(systemName: "bell.badge")
                    Text("查看待处理闹钟")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.white)
            
            Button(action: {
                #if canImport(UIKit)
                HapticManager.shared.impact(style: .light)
                #endif
                testNotification()
            }) {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("测试通知（5秒后）")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.white)
            
            Button(action: {
                #if canImport(UIKit)
                HapticManager.shared.impact(style: .light)
                #endif
                exportData()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出数据")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.white)
            
            Button(action: {
                #if canImport(UIKit)
                HapticManager.shared.impact(style: .light)
                #endif
                clearAllData()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("清除所有数据")
                    Spacer()
                }
            }
            .foregroundColor(.red)
        } header: {
            Text("数据管理")
        }
    }
    
    // MARK: - 使用提示
    private var tipsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("确保系统音量和通知音量已开启", systemImage: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                
                Label("在设置中允许「重要通知」以突破静音模式", systemImage: "bell.badge.fill")
                    .font(.system(size: 14))
                
                Label("闹钟响铃时可在通知上直接操作，无需打开应用", systemImage: "hand.tap.fill")
                    .font(.system(size: 14))
            }
            .foregroundColor(.white.opacity(0.8))
        } header: {
            Text("使用提示")
        }
    }
    
    // MARK: - 应用信息
    private var appInfoSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("构建")
                Spacer()
                Text("2026.02.18")
                    .foregroundColor(.secondary)
            }
            
            Text("CircaAlarm 是一款基于睡眠周期理论的智能闹钟应用。闹钟通过系统通知声音叫醒您，支持在通知上直接停止或延迟。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        } header: {
            Text("关于")
        }
    }
    
    // MARK: - 辅助方法
    
    private func saveSettings() {
        var settings = dataStore.settings
        
        // 转换目标起床时间
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: targetWakeTime)
        settings.targetWakeTime = components
        
        // 入睡延迟
        settings.fallAsleepDelay = delayOptions[fallAsleepDelayIndex]
        
        // 唤醒窗口
        settings.wakeWindow = windowOptions[wakeWindowIndex]
        
        // 兜底策略
        settings.fallbackStrategy = fallbackStrategy
        
        // 最晚响铃时间
        if fallbackStrategy == .latestTime, let latest = latestAlarmTime {
            let latestComponents = calendar.dateComponents([.hour, .minute], from: latest)
            settings.latestAlarmTime = latestComponents
        } else {
            settings.latestAlarmTime = nil
        }
        
        // 其他设置
        settings.maxSnoozeCount = maxSnoozeCount
        settings.volumeFadeIn = volumeFadeIn
        settings.vibrationEnabled = vibrationEnabled
        
        // 保存
        dataStore.settings = settings
        dataStore.saveSettings()
    }
    
    private func exportData() {
        let records = dataStore.sleepRecords
        
        // 创建 CSV 内容
        var csv = "日期,就寝时间,预计入睡,目标起床,实际响铃,实际起床,睡眠时长(小时),延迟次数,舒适度\n"
        
        for record in records {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            
            let date = dateFormatter.string(from: record.date)
            let bedTime = timeFormatter.string(from: record.bedTimeClicked)
            let estimatedSleep = timeFormatter.string(from: record.estimatedFallAsleepTime)
            let targetWake = timeFormatter.string(from: record.targetWakeTime)
            let actualAlarm = timeFormatter.string(from: record.actualAlarmTime)
            let actualWake = record.actualWakeTime.map { timeFormatter.string(from: $0) } ?? "未记录"
            let duration = String(format: "%.2f", record.sleepDurationHours ?? 0)
            let snooze = "\(record.snoozeCount)"
            let comfort = record.comfortLevel?.displayName ?? "未评价"
            
            csv += "\(date),\(bedTime),\(estimatedSleep),\(targetWake),\(actualAlarm),\(actualWake),\(duration),\(snooze),\(comfort)\n"
        }
        
        // 创建临时文件
        let filename = "CircaAlarm_睡眠记录_\(Date().timeIntervalSince1970).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try csv.write(to: path, atomically: true, encoding: .utf8)
            
            // 显示分享面板
            let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
            
            // 获取当前窗口的 root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                let screenBounds = windowScene.screen.bounds
                activityVC.popoverPresentationController?.sourceRect = CGRect(x: screenBounds.midX, y: screenBounds.midY, width: 0, height: 0)
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("导出失败: \(error)")
        }
    }
    
    private func clearAllData() {
        // 显示确认对话框后清除数据
        // 这里简化处理，实际应该使用 Alert
        for record in dataStore.sleepRecords {
            _ = dataStore.deleteSleepRecord(id: record.id)
        }
    }
    
    private func checkPendingNotifications() {
        notificationManager.getPendingNotifications { requests in
            print("=== 待处理的通知 ===")
            print("总数: \(requests.count)")
            
            let alarmRequests = requests.filter { $0.identifier.contains("alarm_") || $0.identifier.contains("snooze_") }
            print("闹钟通知数: \(alarmRequests.count)")
            
            for request in alarmRequests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    if let nextDate = trigger.nextTriggerDate() {
                        print("  - \(request.identifier): \(dateFormatter.string(from: nextDate))")
                    }
                }
            }
            print("================")
        }
    }
    
    private func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "⏰ 测试通知"
        content.body = "这是一条测试通知，5秒后显示"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("测试通知调度失败: \(error)")
            } else {
                print("测试通知已调度，5秒后显示")
            }
        }
    }
}

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
