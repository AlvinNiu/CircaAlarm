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
    @State private var triggeredRecordId: UUID?
    
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
                    
                    // 中部：明日预设起床时间卡片
                    targetWakeTimeCard
                    
                    Spacer()
                    
                    // 核心按钮："我要睡了"
                    sleepButton
                    
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
        .sheet(isPresented: $showSleepConfirm) {
            SleepConfirmView()
        }
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
        #else
        .fullScreenCover(isPresented: $showAlarmRinging) {
            if let recordId = triggeredRecordId {
                AlarmRingingView(recordId: recordId)
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
        VStack(spacing: 12) {
            Text("明日预设起床时间")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
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

// MARK: - 预览
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
