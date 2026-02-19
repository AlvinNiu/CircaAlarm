//
//  AlarmSoundManager.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - 闹钟音频管理器
class AlarmSoundManager: ObservableObject {
    static let shared = AlarmSoundManager()
    
    @Published var isPlaying = false
    @Published var currentVolume: Float = 0.0
    
    private var audioPlayer: AVAudioPlayer?
    private var vibrator: Vibrator?
    private var volumeTimer: Timer?
    private var fadeInDuration: TimeInterval = 30.0 // 默认30秒渐强
    private var targetVolume: Float = 1.0
    
    private init() {
        setupAudioSession()
        vibrator = Vibrator()
    }
    
    // MARK: - 音频会话设置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 设置音频会话为播放模式，允许与其他音频混音
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 播放闹钟声音
    func playAlarmSound(fadeIn: Bool = true, vibrate: Bool = true) {
        // 停止当前播放
        stopAlarmSound()
        
        // 重新设置音频会话（可能在后台被其他应用改变）
        setupAudioSession()
        
        // 播放系统默认闹钟声音
        // 使用系统音效 ID 1105 是闹钟声音
        if let url = createAlarmSoundURL() {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1 // 无限循环
                audioPlayer?.prepareToPlay()
                
                if fadeIn {
                    // 渐变音量
                    currentVolume = 0.1
                    targetVolume = 1.0
                    audioPlayer?.volume = currentVolume
                    audioPlayer?.play()
                    startVolumeFadeIn()
                } else {
                    currentVolume = 1.0
                    audioPlayer?.volume = currentVolume
                    audioPlayer?.play()
                }
                
                isPlaying = true
                
                // 开始振动
                if vibrate {
                    vibrator?.startVibrating()
                }
                
            } catch {
                print("音频播放器创建失败: \(error)")
                // 如果音频文件播放失败，使用系统音效
                playSystemSound()
            }
        } else {
            // 如果没有自定义音频，使用系统音效
            playSystemSound()
        }
    }
    
    // MARK: - 停止闹钟声音
    func stopAlarmSound() {
        volumeTimer?.invalidate()
        volumeTimer = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        vibrator?.stopVibrating()
        
        isPlaying = false
        currentVolume = 0.0
    }
    
    // MARK: - 音量渐强
    private func startVolumeFadeIn() {
        let steps = 30 // 30步
        let stepInterval = fadeInDuration / Double(steps)
        let volumeStep = (targetVolume - currentVolume) / Float(steps)
        
        var currentStep = 0
        
        volumeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            
            if currentStep >= steps {
                self.currentVolume = self.targetVolume
                self.audioPlayer?.volume = self.currentVolume
                timer.invalidate()
            } else {
                self.currentVolume += volumeStep
                self.audioPlayer?.volume = self.currentVolume
            }
        }
    }
    
    // MARK: - 创建闹钟音频URL
    private func createAlarmSoundURL() -> URL? {
        // 尝试从 Bundle 中获取自定义铃声
        // 这里可以使用预设的铃声文件
        
        // 首先尝试获取系统闹钟声音
        if let systemSoundURL = getSystemAlarmSoundURL() {
            return systemSoundURL
        }
        
        return nil
    }
    
    // MARK: - 获取系统闹钟声音
    private func getSystemAlarmSoundURL() -> URL? {
        // 系统闹钟声音路径
        // 注意：iOS 系统声音文件通常无法直接访问，需要使用 AudioServicesPlaySystemSound
        // 这里返回 nil，将使用系统音效播放
        return nil
    }
    
    // MARK: - 播放系统音效（备用方案）
    private func playSystemSound() {
        // 使用系统音效 ID
        // 1005 = 闹钟声音
        // 1016 = 提醒声音
        // 1020 = 门铃声
        // 1105 = 警报声
        // 1304 = 上升音
        // 1305 = 上升音2
        
        // 使用 AudioServices 播放系统声音
        AudioServicesPlaySystemSound(1005)
        
        // 同时开始振动
        vibrator?.startVibrating()
        
        isPlaying = true
    }
    
    // MARK: - 播放测试声音
    func playTestSound() {
        playAlarmSound(fadeIn: false, vibrate: false)
        
        // 3秒后自动停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.stopAlarmSound()
        }
    }
}

// MARK: - 振动管理器
class Vibrator {
    private var vibrationTimer: Timer?
    private let vibrationPattern: [Double] = [0.5, 0.5] // 振动0.5秒，暂停0.5秒
    
    func startVibrating() {
        stopVibrating()
        
        // 立即振动一次
        vibrate()
        
        // 设置定时器持续振动
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.vibrate()
        }
    }
    
    func stopVibrating() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }
    
    private func vibrate() {
        // 使用 AudioServices 播放振动
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

// MARK: - AudioServices 导入
import AudioToolbox

// 系统音效 ID 常量
extension AlarmSoundManager {
    // 常见的系统音效 ID
    enum SystemSoundID: UInt32 {
        case newMail = 1000
        case mailSent = 1001
        case voicemail = 1002
        case receivedMessage = 1003
        case sentMessage = 1004
        case alarm = 1005
        case lowPower = 1006
        case smsReceived1 = 1007
        case smsReceived2 = 1008
        case smsReceived3 = 1009
        case smsReceived4 = 1010
        case smsReceivedVibrate = 1011
        case smsReceived1Alert = 1012
        case alarmClock = 1013
        case lock = 1014
        case unlock = 1015
        case pressClick = 1016
        case beepBeep = 1057
        case riot = 1075
        case chords = 1158
        case dictateError = 1159
        case decodeError = 1160
        case fanfare = 1161
        caseNo = 1162
        case swipe = 1152
        case tweakDescent = 1153
        case tweakShake = 1154
        case unlockDevice = 1100
        case lockDevice = 1101
        case failedUnlock = 1102
        case keyPressed1 = 1103
        case keyPressed2 = 1104
        case keyPressed3 = 1105
        case connectedToPower = 1106
        case ringerSwitchIndication = 1107
        case cameraShutter = 1108
        case shakeToShuffle = 1109
        case beginRecording = 1110
        case endRecording = 1111
        case beginVideoRecording = 1112
        case endVideoRecording = 1113
        case wrongAnswer = 1114
        case ping = 1115
        case ringtoneReceived = 1116
        case vibrate = 4095
    }
}
