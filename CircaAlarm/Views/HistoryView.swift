//
//  HistoryView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI
import Combine

// MARK: - 历史记录页
struct HistoryView: View {
    @StateObject private var dataStore = DataStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case all = "全部"
    }
    
    var filteredRecords: [SleepRecord] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .week:
            return dataStore.sleepRecords.filter {
                calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
            }
        case .month:
            return dataStore.sleepRecords.filter {
                calendar.isDate($0.date, equalTo: now, toGranularity: .month)
            }
        case .all:
            return dataStore.sleepRecords
        }
    }
    
    var averageSleepDuration: Double {
        let completedRecords = filteredRecords.filter { $0.sleepDurationHours != nil }
        guard !completedRecords.isEmpty else { return 0 }
        let total = completedRecords.compactMap { $0.sleepDurationHours }.reduce(0, +)
        return total / Double(completedRecords.count)
    }
    
    var comfortableRate: Double {
        let ratedRecords = filteredRecords.filter { $0.comfortLevel != nil }
        guard !ratedRecords.isEmpty else { return 0 }
        let comfortableCount = ratedRecords.filter { $0.comfortLevel == .comfortable }.count
        return Double(comfortableCount) / Double(ratedRecords.count) * 100
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 统计概览
                        statisticsSection
                        
                        // 时间范围选择
                        timeRangeSelector
                        
                        // 记录列表
                        recordsList
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("睡眠历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - 统计概览
    private var statisticsSection: some View {
        HStack(spacing: 12) {
            // 平均睡眠时长
            StatCard(
                title: "平均睡眠",
                value: String(format: "%.1f", averageSleepDuration),
                unit: "小时",
                icon: "bed.double.fill",
                color: .blue
            )
            
            // 舒适率
            StatCard(
                title: "舒适率",
                value: String(format: "%.0f", comfortableRate),
                unit: "%",
                icon: "smiley.fill",
                color: .green
            )
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 时间范围选择器
    private var timeRangeSelector: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
    }
    
    // MARK: - 记录列表
    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史记录")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            if filteredRecords.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("暂无睡眠记录")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("点击「我要睡了」开始记录您的睡眠")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredRecords) { record in
                        RecordCard(record: record)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(unit)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - 记录卡片
struct RecordCard: View {
    let record: SleepRecord
    
    var body: some View {
        HStack(spacing: 16) {
            // 日期
            VStack(spacing: 4) {
                Text(dayString(from: record.date))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(weekdayString(from: record.date))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 50)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 详情
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(record.sleepDurationDisplay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 舒适度图标
                    if let comfort = record.comfortLevel {
                        Text(comfort.icon)
                            .font(.system(size: 20))
                    }
                }
                
                HStack(spacing: 12) {
                    Label(formatTime(record.bedTimeClicked), systemImage: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Label(formatTime(record.actualAlarmTime), systemImage: "alarm.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // 标签
                HStack(spacing: 8) {
                    if record.usedFallback {
                        Tag(text: "兜底", color: .orange)
                    } else {
                        Tag(text: "\(record.completedCycles ?? 0)周期", color: .green)
                    }
                    
                    if record.snoozeCount > 0 {
                        Tag(text: "延迟\(record.snoozeCount)次", color: .blue)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func weekdayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 标签组件
struct Tag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }
}

// MARK: - 预览
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
