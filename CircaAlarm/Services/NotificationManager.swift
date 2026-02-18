//
//  NotificationManager.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import UserNotifications
import SwiftUI
import Combine

// MARK: - 通知类型
enum AlarmType {
    case optimal    // 智能唤醒
    case fallback   // 兜底闹钟
    case snooze     // 延迟闹钟
}

// MARK: - 通知管理器
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - 权限管理
    
    /// 请求通知权限
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("通知权限请求失败: \(error)")
                }
            }
        }
    }
    
    /// 检查授权状态
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - 闹钟调度
    
    /// 调度睡眠闹钟
    /// - Parameters:
    ///   - alarmTime: 响铃时间
    ///   - alarmType: 闹钟类型
    ///   - recordId: 关联的睡眠记录ID
    func scheduleAlarm(at alarmTime: Date, type alarmType: AlarmType, recordId: UUID) {
        let content = UNMutableNotificationContent()
        
        switch alarmType {
        case .optimal:
            content.title = "最佳唤醒时间到了"
            content.body = "您现在处于浅睡眠阶段，醒来会感觉最舒适"
            content.sound = UNNotificationSound.default
            content.userInfo = ["alarmType": "optimal", "recordId": recordId.uuidString]
        case .fallback:
            content.title = "兜底闹钟"
            content.body = "确保您不会迟到，该起床了"
            content.sound = UNNotificationSound.default
            content.userInfo = ["alarmType": "fallback", "recordId": recordId.uuidString]
        case .snooze:
            content.title = "延迟闹钟"
            content.body = "再睡一会儿，准备起床了"
            content.sound = UNNotificationSound.default
            content.userInfo = ["alarmType": "snooze", "recordId": recordId.uuidString]
        }
        
        // 设置触发时间
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alarmTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "alarm_\(recordId.uuidString)_\(alarmType)",
            content: content,
            trigger: trigger
        )
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("调度闹钟失败: \(error)")
            } else {
                print("闹钟已调度: \(alarmTime), 类型: \(alarmType)")
            }
        }
    }
    
    /// 调度延迟闹钟（10分钟后）
    func scheduleSnoozeAlarm(for recordId: UUID, snoozeCount: Int) {
        let snoozeTime = Date().addingTimeInterval(600) // 10分钟后
        
        let content = UNMutableNotificationContent()
        content.title = "延迟闹钟"
        content.body = "该起床了！（延迟第\(snoozeCount)次）"
        content.sound = UNNotificationSound.default
        content.userInfo = ["alarmType": "snooze", "recordId": recordId.uuidString, "snoozeCount": snoozeCount]
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: snoozeTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze_\(recordId.uuidString)_\(snoozeCount)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("调度延迟闹钟失败: \(error)")
            } else {
                print("延迟闹钟已调度: \(snoozeTime)")
            }
        }
    }
    
    /// 取消所有闹钟
    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("所有闹钟已取消")
    }
    
    /// 取消特定记录的闹钟
    func cancelAlarms(for recordId: UUID) {
        let identifiers = [
            "alarm_\(recordId.uuidString)_optimal",
            "alarm_\(recordId.uuidString)_fallback",
            "alarm_\(recordId.uuidString)_snooze"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// 获取待处理的通知
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 应用在前台时也显示通知
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理通知点击
        if let recordIdString = userInfo["recordId"] as? String,
           let recordId = UUID(uuidString: recordIdString) {
            print("用户点击了闹钟通知，记录ID: \(recordId)")
            
            // 发布通知，让应用处理响铃界面
            NotificationCenter.default.post(
                name: .alarmTriggered,
                object: nil,
                userInfo: ["recordId": recordId, "alarmType": userInfo["alarmType"] ?? "unknown"]
            )
        }
        
        completionHandler()
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let alarmTriggered = Notification.Name("alarmTriggered")
}
