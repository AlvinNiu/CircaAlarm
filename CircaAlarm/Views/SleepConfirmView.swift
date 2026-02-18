//
//  SleepConfirmView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI

// MARK: - 睡前确认页
struct SleepConfirmView: View {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var currentTime = Date()
    @State private var fallAsleepDelay: TimeInterval
    @State private var calculationResult: SleepCalculationResult?
    @State private var showInsufficientTimeWarning = false
    @State private var isScheduling = false
    
    // 入睡延迟选项（分钟）
    let delayOptions: [TimeInterval] = [300, 600, 900, 1200, 1500, 1800] // 5, 10, 15, 20, 25, 30分钟
    
    init() {
        let defaultDelay = DataStore.shared.settings.fallAsleepDelay
        _fallAsleepDelay = State(initialValue: defaultDelay)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(red: 0.05, green: 0.05, blue: 0.15)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 时间轴可视化
                        timelineSection
                        
                        // 计算结果展示
                        if let result = calculationResult {
                            calculationResultSection(result: result)
                        }
                        
                        // 入睡延迟选择
                        delaySelectionSection
                        
                        // 警告信息
                        if showInsufficientTimeWarning {
                            warningSection
                        }
                        
                        Spacer(minLength: 40)
                        
                        // 确认按钮
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("准备入睡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .onAppear {
                currentTime = Date()
                recalculate()
            }
            .onChange(of: fallAsleepDelay) { _ in
                recalculate()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 时间轴可视化
    private var timelineSection: some View {
        VStack(spacing: 16) {
            // 当前时间
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("现在")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatTime(currentTime))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            
            // 时间线
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.35, green: 0.78, blue: 0.98))
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 2)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 2)
                
                if let result = calculationResult, result.isValid {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                }
            }
            
            // 预计入睡时间
            HStack {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("预计入睡")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Text(formatTime(currentTime.addingTimeInterval(fallAsleepDelay)))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - 计算结果展示
    private func calculationResultSection(result: SleepCalculationResult) -> some View {
        VStack(spacing: 16) {
            if result.isValid {
                // 最佳唤醒时间
                VStack(spacing: 8) {
                    Text("预计最佳唤醒时间")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(result.optimalWakeTimeDisplay)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.78, blue: 0.35))
                    
                    Text(result.earlierTimeDisplay)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // 周期数和睡眠时长
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text(result.cyclesDisplay)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("完整睡眠周期")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Text(result.sleepDurationDisplay)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("预计睡眠时长")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            } else {
                // 不足一个周期
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("剩余时间不足完整周期")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("系统将使用兜底策略在预设时间响铃")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - 入睡延迟选择
    private var delaySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入睡所需时间")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("您通常躺下后多久能睡着？")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            // 分段选择器
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(delayOptions, id: \.self) { delay in
                    Button(action: {
                        withAnimation(.spring()) {
                            fallAsleepDelay = delay
                            HapticManager.shared.impact(style: .light)
                        }
                    }) {
                        Text("\(Int(delay / 60))分钟")
                            .font(.system(size: 16, weight: fallAsleepDelay == delay ? .semibold : .regular))
                            .foregroundColor(fallAsleepDelay == delay ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(fallAsleepDelay == delay ? Color(red: 0.35, green: 0.34, blue: 0.84) : Color.white.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - 警告信息
    private var warningSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)
            
            Text("入睡过晚，无法完成完整睡眠周期。建议调整起床时间或接受兜底策略。")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                startSleep()
            }) {
                HStack {
                    if isScheduling {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bed.double.fill")
                        Text("开始睡眠")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                )
            }
            .disabled(isScheduling)
            
            Button(action: {
                dismiss()
            }) {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func recalculate() {
        let targetWakeTime = dataStore.settings.getTodayTargetWakeTime()
        
        calculationResult = SleepCalculator.shared.calculateOptimalWakeTime(
            bedTimeClicked: currentTime,
            fallAsleepDelay: fallAsleepDelay,
            targetWakeTime: targetWakeTime
        )
        
        // 检查是否需要显示警告
        if let result = calculationResult {
            showInsufficientTimeWarning = !result.isValid
        }
    }
    
    private func startSleep() {
        guard let result = calculationResult else { return }
        
        isScheduling = true
        HapticManager.shared.impact(style: .heavy)
        
        // 确定最终响铃时间
        let (alarmTime, usedFallback, _) = SleepCalculator.shared.determineAlarmTime(
            calculationResult: result,
            fallbackStrategy: dataStore.settings.fallbackStrategy,
            latestAlarmTime: dataStore.settings.getLatestAlarmTime(for: Date())
        )
        
        // 创建睡眠记录
        let record = SleepRecord(
            id: UUID(),
            date: Date(),
            bedTimeClicked: currentTime,
            estimatedFallAsleepTime: result.estimatedFallAsleepTime,
            targetWakeTime: result.targetWakeTime,
            plannedOptimalWakeTime: result.optimalWakeTime,
            actualAlarmTime: alarmTime,
            actualWakeTime: nil,
            snoozeCount: 0,
            usedFallback: usedFallback,
            comfortLevel: nil
        )
        
        // 保存到数据库
        if dataStore.insertSleepRecord(record) {
            // 调度闹钟通知
            let alarmType: AlarmType = usedFallback ? .fallback : .optimal
            notificationManager.scheduleAlarm(at: alarmTime, type: alarmType, recordId: record.id)
            
            // 更新设置中的入睡延迟（记住用户选择）
            dataStore.settings.fallAsleepDelay = fallAsleepDelay
            dataStore.saveSettings()
            
            // 关闭页面
            dismiss()
        } else {
            isScheduling = false
            // 显示错误提示
        }
    }
}

// MARK: - 预览
struct SleepConfirmView_Previews: PreviewProvider {
    static var previews: some View {
        SleepConfirmView()
    }
}
