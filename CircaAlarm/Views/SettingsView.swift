//
//  SettingsView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI

// MARK: - 设置页
struct SettingsView: View {
    @StateObject private var dataStore = DataStore.shared
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
                    
                    // 应用信息
                    appInfoSection
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("设置")
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
            .pickerStyle(.navigationLink)
            
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
            
            // 音量渐变
            Toggle("音量渐变", isOn: $volumeFadeIn)
            
            // 振动开关
            Toggle("振动提醒", isOn: $vibrationEnabled)
        } header: {
            Text("闹钟偏好")
        }
    }
    
    // MARK: - 数据管理
    private var dataManagementSection: some View {
        Section {
            Button(action: {
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
            
            Text("CircaAlarm 是一款基于睡眠周期理论的智能闹钟应用，完全本地运行，保护您的隐私。")
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
        // 实现数据导出功能
        let records = dataStore.sleepRecords
        // 转换为 CSV 或 JSON
        // 使用 UIActivityViewController 分享
    }
    
    private func clearAllData() {
        // 显示确认对话框后清除数据
        // 这里简化处理，实际应该使用 Alert
        for record in dataStore.sleepRecords {
            _ = dataStore.deleteSleepRecord(id: record.id)
        }
    }
}

// MARK: - 预览
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
