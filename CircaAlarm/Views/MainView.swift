//
//  MainView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI
import Combine

// MARK: - 主界面（睡眠启动页）
struct MainView: View {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var currentTime = Date()
    @State private var showSleepConfirm = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showAlarmRinging = false
    @State private var showWakeUpFeedback = false
    @State private var showTimePicker = false
    @State private var tempWakeTime = Date()
    @State private var triggeredRecordId: UUID?
    
    // 当前进行中的睡眠记录
    var currentSleepRecord: SleepRecord? {
        dataStore.getTodayUnfinishedRecord()
    }
    
    // 是否正在睡眠中
    var isSleeping: Bool {
        currentSleepRecord != nil
    }
    
    // 定时器，每秒更新当前时间
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                backgroundGradient
                
                VStack(spacing: 0) {
                    // 顶部：当前时间
                    currentTimeSection
                    
                    Spacer()
                    
                    // 中部：明日预设起床时间卡片或睡眠中卡片
                    if isSleeping {
                        sleepingStatusCard
                    } else {
                        targetWakeTimeCard
                    }
                    
                    Spacer()
                    
                    // 核心按钮：根据状态显示不同按钮
                    if isSleeping {
                        wakeUpButton
                    } else {
                        sleepButton
                    }
                    
                    Spacer()
                    
                    // 底部：设置和历史入口
                    bottomButtons
                }
                .padding(.vertical, 40)
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
        }
        .onAppear {
            checkNotificationAuthorization()
            checkForActiveAlarm()
            setupAlarmObserver()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        #if os(macOS)
        .sheet(isPresented: $showSleepConfirm) {
            SleepConfirmView()
        }
        #else
        .fullScreenCover(isPresented: $showSleepConfirm) {
            SleepConfirmView()
        }
        #endif
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        #if os(macOS)
        .sheet(isPresented: $showAlarmRinging) {
            if let recordId = triggeredRecordId {
                AlarmRingingView(recordId: recordId)
            }
        }
        .sheet(isPresented: $showWakeUpFeedback) {
            if let record = currentSleepRecord {
                QuickFeedbackView(record: record)
            }
        }
        #else
        .fullScreenCover(isPresented: $showAlarmRinging) {
            if let recordId = triggeredRecordId {
                AlarmRingingView(recordId: recordId)
            }
        }
        .fullScreenCover(isPresented: $showWakeUpFeedback) {
            if let record = currentSleepRecord {
                QuickFeedbackView(record: record)
            }
        }
        #endif
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.08, blue: 0.2)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - 当前时间区域
    private var currentTimeSection: some View {
        VStack(spacing: 8) {
            Text("现在")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text(timeString(from: currentTime))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
    
    // MARK: - 预设起床时间卡片
    private var targetWakeTimeCard: some View {
        Button(action: {
            // 初始化临时时间为当前设置的时间
            tempWakeTime = dataStore.settings.getTodayTargetWakeTime()
            showTimePicker = true
        }) {
            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("明日预设起床时间")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Text(targetWakeTimeString)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(timeUntilTarget)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTimePicker) {
            TimePickerSheet(
                selectedTime: $tempWakeTime,
                onSave: {
                    saveWakeTime(tempWakeTime)
                    showTimePicker = false
                },
                onCancel: {
                    showTimePicker = false
                }
            )
        }
    }
    
    /// 保存起床时间
    private func saveWakeTime(_ date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        var settings = dataStore.settings
        settings.targetWakeTime = components
        dataStore.settings = settings
        dataStore.saveSettings()
        
        print("起床时间已更新为: \(components.hour ?? 7):\(components.minute ?? 0)")
    }
    
    // MARK: - 睡眠中状态卡片
    private var sleepingStatusCard: some View {
        VStack(spacing: 12) {
            if let record = currentSleepRecord {
                Text("正在睡眠中...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("预计 \(formatTime(record.plannedOptimalWakeTime ?? record.targetWakeTime)) 醒来")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                    Text("已睡 \(sleepDurationString(from: record.bedTimeClicked))")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - "我要睡了"按钮
    private var sleepButton: some View {
        Button(action: {
            #if canImport(UIKit)
            HapticManager.shared.impact(style: .heavy)
            #endif
            showSleepConfirm = true
        }) {
            ZStack {
                // 按钮背景渐变
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.35, green: 0.78, blue: 0.98),  // #5AC8FA
                                Color(red: 0.35, green: 0.34, blue: 0.84)   // #5856D6
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: Color(red: 0.35, green: 0.34, blue: 0.84).opacity(0.5),
                            radius: 20, x: 0, y: 10)
                
                // 脉动动画层
                PulseAnimationView()
                    .frame(width: 200, height: 200)
                
                // 按钮文字
                VStack(spacing: 4) {
                    Text("我要睡了")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("点击开始睡眠")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - "我醒了"按钮
    private var wakeUpButton: some View {
        Button(action: {
            #if canImport(UIKit)
            HapticManager.shared.impact(style: .heavy)
            #endif
            showWakeUpFeedback = true
        }) {
            ZStack {
                // 按钮背景渐变 - 使用日出/黎明的橙黄色调
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.6, blue: 0.3),   // 橙黄色
                                Color(red: 1.0, green: 0.4, blue: 0.2)    // 深橙色
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: Color(red: 1.0, green: 0.4, blue: 0.2).opacity(0.5),
                            radius: 20, x: 0, y: 10)
                
                // 脉动动画层
                PulseAnimationView()
                    .frame(width: 200, height: 200)
                
                // 按钮文字
                VStack(spacing: 4) {
                    Text("我醒了")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("点击结束睡眠")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        HStack(spacing: 60) {
            // 设置按钮
            Button(action: {
                showSettings = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 24))
                    Text("设置")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 60, height: 60)
            }
            
            // 历史记录按钮
            Button(action: {
                showHistory = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 24))
                    Text("历史")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 60, height: 60)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func sleepDurationString(from bedTime: Date) -> String {
        let duration = Date().timeIntervalSince(bedTime)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private var targetWakeTimeString: String {
        let targetTime = dataStore.settings.getTodayTargetWakeTime()
        return timeString(from: targetTime)
    }
    
    private var timeUntilTarget: String {
        let targetTime = dataStore.settings.getTodayTargetWakeTime()
        let interval = targetTime.timeIntervalSince(currentTime)
        
        if interval <= 0 {
            return "已过预设时间"
        }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "还有\(hours)小时\(minutes)分钟"
        } else {
            return "还有\(minutes)分钟"
        }
    }
    
    private func checkNotificationAuthorization() {
        notificationManager.requestAuthorization()
    }
    
    private func checkForActiveAlarm() {
        // 检查是否有未完成的睡眠记录
        if let record = dataStore.getTodayUnfinishedRecord() {
            // 检查是否已经到了闹钟时间
            if record.actualAlarmTime <= Date() {
                triggeredRecordId = record.id
                showAlarmRinging = true
            }
        }
    }
    
    private func setupAlarmObserver() {
        // 闹钟触发通知
        NotificationCenter.default.addObserver(
            forName: .alarmTriggered,
            object: nil,
            queue: .main
        ) { notification in
            if let recordId = notification.userInfo?["recordId"] as? UUID {
                triggeredRecordId = recordId
                showAlarmRinging = true
            }
        }
        
        // 从通知停止闹钟
        NotificationCenter.default.addObserver(
            forName: .stopAlarmFromNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let recordId = notification.userInfo?["recordId"] as? UUID {
                self.stopAlarmFromNotification(recordId: recordId)
            }
        }
        
        // 从通知延迟闹钟
        NotificationCenter.default.addObserver(
            forName: .snoozeAlarmFromNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let recordId = notification.userInfo?["recordId"] as? UUID {
                self.snoozeAlarmFromNotification(recordId: recordId)
            }
        }
    }
    
    /// 从通知停止闹钟
    private func stopAlarmFromNotification(recordId: UUID) {
        if var record = dataStore.sleepRecords.first(where: { $0.id == recordId }) {
            let wakeTime = Date()
            let sleepDuration = wakeTime.timeIntervalSince(record.bedTimeClicked)
            
            // 先取消所有闹钟通知
            NotificationManager.shared.cancelAlarms(for: recordId)
            
            // 如果睡眠时长小于1小时，删除记录不保存
            if sleepDuration < 3600 {
                _ = dataStore.deleteSleepRecord(id: recordId)
                return
            }
            
            record.actualWakeTime = wakeTime
            _ = dataStore.updateSleepRecord(record)
            
            // 显示反馈
            showWakeUpFeedback = true
        }
    }
    
    /// 从通知延迟闹钟
    private func snoozeAlarmFromNotification(recordId: UUID) {
        if var record = dataStore.sleepRecords.first(where: { $0.id == recordId }) {
            record.snoozeCount += 1
            if dataStore.updateSleepRecord(record) {
                notificationManager.scheduleSnoozeAlarm(for: record.id, snoozeCount: record.snoozeCount)
            }
        }
    }
}

// MARK: - 快速反馈视图（简化版舒适度反馈）
struct QuickFeedbackView: View {
    @State var record: SleepRecord
    @StateObject private var dataStore = DataStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // 标题
                    VStack(spacing: 12) {
                        Text("早上好！")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("您睡了 \(sleepDurationText)")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // 舒适度选择
                    VStack(spacing: 20) {
                        Text("这次醒来感觉怎么样？")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                        
                        // 舒适按钮
                        FeedbackButton(
                            icon: "😊",
                            title: "很舒适",
                            subtitle: "醒来神清气爽",
                            color: Color(red: 0.2, green: 0.78, blue: 0.35),
                            action: {
                                completeWakeUp(comfortLevel: .comfortable)
                            }
                        )
                        
                        // 一般按钮
                        FeedbackButton(
                            icon: "😐",
                            title: "一般般",
                            subtitle: "正常醒来",
                            color: Color.orange,
                            action: {
                                completeWakeUp(comfortLevel: .skipped)
                            }
                        )
                        
                        // 不舒服按钮
                        FeedbackButton(
                            icon: "😣",
                            title: "不舒服",
                            subtitle: "醒来困难，很困",
                            color: Color.red,
                            action: {
                                completeWakeUp(comfortLevel: .uncomfortable)
                            }
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 30)
            }
            .navigationTitle("醒来反馈")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("跳过") {
                        completeWakeUp(comfortLevel: .skipped)
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var sleepDurationText: String {
        let duration = Date().timeIntervalSince(record.bedTimeClicked)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func completeWakeUp(comfortLevel: ComfortLevel) {
        let wakeTime = Date()
        let sleepDuration = wakeTime.timeIntervalSince(record.bedTimeClicked)
        
        // 先取消所有闹钟通知（无论是否保存记录都要取消）
        NotificationManager.shared.cancelAlarms(for: record.id)
        
        // 如果睡眠时长小于1小时，删除记录不保存
        if sleepDuration < 3600 {
            _ = dataStore.deleteSleepRecord(id: record.id)
            dismiss()
            return
        }
        
        // 更新睡眠记录
        var updatedRecord = record
        updatedRecord.actualWakeTime = wakeTime
        updatedRecord.comfortLevel = comfortLevel
        
        _ = dataStore.updateSleepRecord(updatedRecord)
        
        // 关闭反馈界面
        dismiss()
    }
}

// MARK: - 反馈按钮
struct FeedbackButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.5), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 脉动动画视图
struct PulseAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.3), lineWidth: 2)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 4)
                        .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 按钮缩放效果
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 触觉反馈管理器
#if canImport(UIKit)
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#else
class HapticManager {
    static let shared = HapticManager()
    func impact(style: Int) {}
}
#endif

// MARK: - 时间选择器弹窗
struct TimePickerSheet: View {
    @Binding var selectedTime: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("设置起床时间")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // 时间选择器
                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorMultiply(Color(red: 0.2, green: 0.78, blue: 0.35))
                    .frame(maxHeight: 200)
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 16) {
                        Button(action: onCancel) {
                            Text("取消")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                        
                        Button(action: onSave) {
                            Text("保存")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 预览
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
