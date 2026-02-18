//
//  AlarmRingingView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI
import Combine
#if canImport(AVFoundation) && !os(macOS)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 响铃界面
struct AlarmRingingView: View {
    let recordId: UUID
    
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTime = Date()
    @State private var record: SleepRecord?
    @State private var remainingSnoozeCount: Int = 0
    @State private var showFeedback = false
    #if canImport(AVFoundation) && !os(macOS)
    @State private var audioPlayer: AVAudioPlayer?
    #endif
    
    // 定时器更新当前时间
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(recordId: UUID) {
        self.recordId = recordId
    }
    
    var body: some View {
        ZStack {
            // 动态背景渐变
            backgroundGradient
            
            VStack(spacing: 0) {
                Spacer()
                
                // 当前时间大字体显示
                timeDisplaySection
                
                Spacer()
                
                // 状态标签
                statusBadgeSection
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
                
                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            loadRecord()
            setupAudioSession()
            playAlarmSound()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onDisappear {
            stopAlarmSound()
        }
        .sheet(isPresented: $showFeedback) {
            if let record = record {
                FeedbackView(record: record)
            }
        }
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        let isOptimal = record?.usedFallback == false
        
        return LinearGradient(
            gradient: Gradient(colors: isOptimal ? [
                Color(red: 0.1, green: 0.15, blue: 0.2),
                Color(red: 0.15, green: 0.25, blue: 0.3)
            ] : [
                Color(red: 0.15, green: 0.1, blue: 0.05),
                Color(red: 0.3, green: 0.2, blue: 0.1)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - 时间显示区域
    private var timeDisplaySection: some View {
        VStack(spacing: 16) {
            Text(timeString(from: currentTime))
                .font(.system(size: 96, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            if let record = record {
                Text(alarmDateDescription(for: record))
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - 状态标签区域
    private var statusBadgeSection: some View {
        VStack(spacing: 12) {
            // 主标签
            if let record = record {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon(for: record))
                    Text(statusText(for: record))
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(statusColor(for: record))
                )
                
                // 副标题说明
                Text(statusDescription(for: record))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // 停止按钮
            Button(action: {
                stopAlarm()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("停止闹钟")
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                        .shadow(color: Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.4),
                                radius: 15, x: 0, y: 8)
                )
            }
            
            // 延迟按钮
            if remainingSnoozeCount > 0 {
                Button(action: {
                    snoozeAlarm()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "zzz")
                        VStack(spacing: 2) {
                            Text("再睡10分钟")
                                .font(.system(size: 18, weight: .semibold))
                            Text("（还可延迟\(remainingSnoozeCount)次）")
                                .font(.system(size: 12))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.orange.opacity(0.3))
                            )
                    )
                }
            } else if let record = record, record.snoozeCount >= dataStore.settings.maxSnoozeCount {
                Text("已达到最大延迟次数")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func loadRecord() {
        record = dataStore.sleepRecords.first { $0.id == recordId }
        if let record = record {
            remainingSnoozeCount = max(0, dataStore.settings.maxSnoozeCount - record.snoozeCount)
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func alarmDateDescription(for record: SleepRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: record.actualAlarmTime)
    }
    
    private func statusIcon(for record: SleepRecord) -> String {
        if record.usedFallback {
            return "exclamationmark.triangle.fill"
        } else if record.snoozeCount > 0 {
            return "moon.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private func statusText(for record: SleepRecord) -> String {
        if record.usedFallback {
            return "兜底闹钟"
        } else if record.snoozeCount > 0 {
            return "延迟闹钟"
        } else {
            return "浅睡眠优化唤醒"
        }
    }
    
    private func statusDescription(for record: SleepRecord) -> String {
        if record.usedFallback {
            return "确保您不会迟到"
        } else if record.snoozeCount > 0 {
            return "您已经延迟了\(record.snoozeCount)次"
        } else {
            return "您在浅睡眠阶段，现在醒来感觉最舒适"
        }
    }
    
    private func statusColor(for record: SleepRecord) -> Color {
        if record.usedFallback {
            return Color.orange
        } else if record.snoozeCount > 0 {
            return Color.blue
        } else {
            return Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }
    
    // MARK: - 音频处理
    
    private func setupAudioSession() {
        #if canImport(AVFoundation) && !os(macOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
        #endif
    }
    
    private func playAlarmSound() {
        #if canImport(AVFoundation) && !os(macOS)
        // 播放系统默认闹钟声音
        // 实际项目中可以加载自定义铃声
        // 这里简化处理，使用系统声音
        #endif
    }
    
    private func stopAlarmSound() {
        #if canImport(AVFoundation) && !os(macOS)
        audioPlayer?.stop()
        audioPlayer = nil
        #endif
    }
    
    // MARK: - 闹钟操作
    
    private func stopAlarm() {
        #if canImport(UIKit)
        HapticManager.shared.impact(style: .heavy)
        #endif
        stopAlarmSound()
        
        // 更新记录
        if var record = record {
            record.actualWakeTime = Date()
            _ = dataStore.updateSleepRecord(record)
            self.record = record
        }
        
        // 显示反馈界面
        showFeedback = true
    }
    
    private func snoozeAlarm() {
        #if canImport(UIKit)
        HapticManager.shared.impact(style: .medium)
        #endif
        stopAlarmSound()
        
        guard var record = record else { return }
        
        // 更新延迟次数
        record.snoozeCount += 1
        remainingSnoozeCount = max(0, dataStore.settings.maxSnoozeCount - record.snoozeCount)
        
        if dataStore.updateSleepRecord(record) {
            self.record = record
            
            // 调度延迟闹钟
            notificationManager.scheduleSnoozeAlarm(for: record.id, snoozeCount: record.snoozeCount)
            
            // 关闭响铃界面
            dismiss()
        }
    }
}

// MARK: - 预览
struct AlarmRingingView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmRingingView(recordId: UUID())
    }
}
