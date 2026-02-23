//
//  ContentView.swift
//  CircaAlarm
//
//  Created by 牛慧升 on 2026/2/18.
//

import SwiftUI

struct ContentView: View {
    @State private var isActive = false
    
    var body: some View {
        ZStack {
            if isActive {
                MainView()
            } else {
                SplashScreenView()
            }
        }
        .onAppear {
            // 1秒后切换到主界面
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
    }
}

// MARK: - 启动屏
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 应用图标
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.35, green: 0.78, blue: 0.98),
                                    Color(red: 0.35, green: 0.34, blue: 0.84)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.5)
                
                // 应用名称
                VStack(spacing: 8) {
                    Text("CircaAlarm")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("生物钟闹钟")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // 副标题
                Text("基于睡眠周期的智能唤醒")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
