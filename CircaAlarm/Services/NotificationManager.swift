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
    
    // 连续通知的配置
    private let notificationDuration: TimeInterval = 30 // 每个通知30秒声音
    private let notificationInterval: TimeInterval = 25 // 每25秒发一个新通知（重叠5秒确保连续）
    private let totalNotifications = 10 // 总共发10个通知，持续约4分钟
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
        registerNotificationCategories()
    }
    
    // MARK: - 权限管理
    
    /// 请求通知权限
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        // 请求基本通知权限
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("通知权限请求失败: \(error)")
                } else {
                    print("通知权限状态: \(granted ? "已授权" : "未授权")")
                }
            }
        }
    }
    
    /// 检查授权状态
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - 注册通知类别（操作按钮）
    private func registerNotificationCategories() {
        // 停止闹钟操作
        let stopAction = UNNotificationAction(
            identifier: "STOP_ALARM",
            title: "停止闹钟",
            options: [.foreground, .destructive]
        )
        
        // 延迟闹钟操作
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ALARM",
            title: "再睡10分钟",
            options: []
        )
        
        // 闹钟类别
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [stopAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
    }
    
    // MARK: - 调度闹钟（连续通知实现持续响铃）
    
    /// 调度睡眠闹钟 - 使用连续通知实现持续响铃
    /// - Parameters:
    ///   - alarmTime: 响铃时间
    ///   - alarmType: 闹钟类型
    ///   - recordId: 关联的睡眠记录ID
    func scheduleAlarm(at alarmTime: Date, type alarmType: AlarmType, recordId: UUID) {
        // 取消之前的闹钟
        cancelAlarms(for: recordId)
        
        // 调度多个连续通知
        for i in 0..<totalNotifications {
            let notificationTime = alarmTime.addingTimeInterval(Double(i) * notificationInterval)
            
            // 如果时间在当前时间之前，跳过
            if notificationTime < Date() {
                continue
            }
            
            let content = createNotificationContent(type: alarmType, index: i, recordId: recordId)
            
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: notificationTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "alarm_\(recordId.uuidString)_\(i)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("调度闹钟失败 [\(i)]: \(error)")
                }
            }
        }
        
        print("已调度 \(totalNotifications) 个连续通知，从 \(alarmTime) 开始")
    }
    
    /// 创建通知内容
    private func createNotificationContent(type: AlarmType, index: Int, recordId: UUID) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        switch type {
        case .optimal:
            content.title = index == 0 ? "⏰ 最佳唤醒时间到了" : "⏰ 闹钟响铃中..."
            content.body = index == 0 
                ? "您现在处于浅睡眠阶段，醒来会感觉最舒适。点击停止闹钟。"
                : "闹钟持续响铃中，请点击停止。"
        case .fallback:
            content.title = index == 0 ? "⏰ 兜底闹钟" : "⏰ 闹钟响铃中..."
            content.body = index == 0
                ? "确保您不会迟到，该起床了！点击停止闹钟。"
                : "闹钟持续响铃中，请点击停止。"
        case .snooze:
            content.title = "⏰ 延迟闹钟"
            content.body = "再睡一会儿，准备起床了！"
        }
        
        // 使用系统默认声音，确保兼容性
        content.sound = UNNotificationSound.default
        
        // 设置用户信息和类别
        content.userInfo = ["alarmType": type == .optimal ? "optimal" : "fallback", "recordId": recordId.uuidString, "index": index]
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        // 设置为时间敏感通知（iOS 15+），在专注模式下也能显示
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        
        // 设置通知优先级
        content.threadIdentifier = "alarm_\(recordId.uuidString)"
        
        return content
    }
    
    /// 调度延迟闹钟（10分钟后）
    func scheduleSnoozeAlarm(for recordId: UUID, snoozeCount: Int) {
        let snoozeTime = Date().addingTimeInterval(600) // 10分钟后
        
        // 取消当前的所有闹钟通知
        cancelAlarms(for: recordId)
        
        // 调度新的连续通知
        for i in 0..<totalNotifications {
            let notificationTime = snoozeTime.addingTimeInterval(Double(i) * notificationInterval)
            
            let content = UNMutableNotificationContent()
            content.title = "⏰ 延迟闹钟"
            content.body = "该起床了！（延迟第\(snoozeCount)次）"
            content.sound = UNNotificationSound.defaultCritical
            content.userInfo = ["alarmType": "snooze", "recordId": recordId.uuidString, "snoozeCount": snoozeCount, "index": i]
            content.categoryIdentifier = "ALARM_CATEGORY"
            
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .critical
                content.relevanceScore = 1.0
            }
            
            content.threadIdentifier = "alarm_\(recordId.uuidString)"
            
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "snooze_\(recordId.uuidString)_\(i)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("调度延迟闹钟失败 [\(i)]: \(error)")
                }
            }
        }
        
        print("已调度延迟闹钟的 \(totalNotifications) 个连续通知")
    }
    
    /// 取消所有闹钟
    func cancelAllAlarms() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("所有闹钟已取消")
    }
    
    /// 取消特定记录的闹钟
    func cancelAlarms(for recordId: UUID) {
        // 确保在主线程执行
        DispatchQueue.main.async {
            // 移除待发送的通知
            var identifiers: [String] = []
            for i in 0..<self.totalNotifications {
                identifiers.append("alarm_\(recordId.uuidString)_\(i)")
                identifiers.append("snooze_\(recordId.uuidString)_\(i)")
            }
            
            print("正在取消闹钟，记录ID: \(recordId.uuidString)")
            print("要取消的通知标识符: \(identifiers)")
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            
            // 移除已显示的通知
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            
            print("闹钟已取消")
        }
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
        // 应用在前台时也显示通知（包括声音）
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理通知操作
        switch response.actionIdentifier {
        case "STOP_ALARM":
            // 用户点击了停止闹钟 - 不需要打开应用
            if let recordIdString = userInfo["recordId"] as? String,
               let recordId = UUID(uuidString: recordIdString) {
                NotificationCenter.default.post(
                    name: .stopAlarmFromNotification,
                    object: nil,
                    userInfo: ["recordId": recordId]
                )
            }
            
        case "SNOOZE_ALARM":
            // 用户点击了延迟闹钟 - 不需要打开应用
            if let recordIdString = userInfo["recordId"] as? String,
               let recordId = UUID(uuidString: recordIdString) {
                NotificationCenter.default.post(
                    name: .snoozeAlarmFromNotification,
                    object: nil,
                    userInfo: ["recordId": recordId]
                )
            }
            
        case UNNotificationDefaultActionIdentifier:
            // 用户点击了通知本身 - 打开应用
            if let recordIdString = userInfo["recordId"] as? String,
               let recordId = UUID(uuidString: recordIdString) {
                NotificationCenter.default.post(
                    name: .alarmTriggered,
                    object: nil,
                    userInfo: ["recordId": recordId, "alarmType": userInfo["alarmType"] ?? "unknown"]
                )
            }
            
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let alarmTriggered = Notification.Name("alarmTriggered")
    static let stopAlarmFromNotification = Notification.Name("stopAlarmFromNotification")
    static let snoozeAlarmFromNotification = Notification.Name("snoozeAlarmFromNotification")
}
