//
//  FeedbackView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI

// MARK: - 舒适度反馈页
struct FeedbackView: View {
    @State var record: SleepRecord
    
    @StateObject private var dataStore = DataStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedComfort: ComfortLevel?
    @State private var showUncomfortableReasons = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 标题
                    titleSection
                    
                    // 睡眠摘要卡片
                    sleepSummaryCard
                    
                    Spacer()
                    
                    // 舒适度选择
                    comfortSelectionSection
                    
                    Spacer()
                    
                    // 跳过按钮
                    skipButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("醒来反馈")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
    
    // MARK: - 标题区域
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("这次醒来感觉怎么样？")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("您的反馈将帮助我们优化唤醒时机")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.top, 20)
    }
    
    // MARK: - 睡眠摘要卡片
    private var sleepSummaryCard: some View {
        VStack(spacing: 16) {
            // 睡眠时长
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                if let hours = record.sleepDurationHours {
                    Text("\(Int(hours))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("小时")
                        .font(.system(size: 20))
                } else {
                    Text("--")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 详细信息
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14))
                        Text("\(record.completedCycles ?? 0)个周期")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    
                    Text("完整睡眠周期")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 30)
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                        Text(formatTime(record.actualAlarmTime))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    
                    Text(record.usedFallback ? "兜底闹钟" : "智能唤醒")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - 舒适度选择区域
    private var comfortSelectionSection: some View {
        VStack(spacing: 20) {
            ForEach(ComfortLevel.allCases, id: \.self) { level in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedComfort = level
                        HapticManager.shared.impact(style: .light)
                        saveFeedback(level: level)
                    }
                }) {
                    HStack(spacing: 16) {
                        Text(level.icon)
                            .font(.system(size: 40))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(comfortDescription(for: level))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        if selectedComfort == level {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: level.color))
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedComfort == level ?
                                  Color(hex: level.color).opacity(0.2) :
                                    Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedComfort == level ?
                                            Color(hex: level.color) : Color.clear,
                                            lineWidth: 2)
                            )
                    )
                }
            }
        }
    }
    
    // MARK: - 跳过按钮
    private var skipButton: some View {
        Button(action: {
            saveFeedback(level: .skipped)
        }) {
            Text("跳过反馈")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 12)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func comfortDescription(for level: ComfortLevel) -> String {
        switch level {
        case .comfortable:
            return "醒来感觉清爽，没有困倦感"
        case .uncomfortable:
            return "醒来困难，感觉还没睡够"
        case .skipped:
            return "暂时不想评价"
        }
    }
    
    private func saveFeedback(level: ComfortLevel) {
        var updatedRecord = record
        updatedRecord.comfortLevel = level
        
        if dataStore.updateSleepRecord(updatedRecord) {
            dismiss()
        }
    }
}

// MARK: - 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 预览
struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackView(record: SleepRecord.sample())
    }
}
