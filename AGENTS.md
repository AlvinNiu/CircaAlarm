# CircaAlarm - AI Agent 项目指南

## 项目概述

**CircaAlarm**（生物钟闹钟）是一款基于睡眠周期理论的 iOS 智能闹钟应用。应用采用**纯时间模型驱动**的设计范式，区别于市场上依赖传感器监测的智能闹钟，完全不使用麦克风、加速度计等传感器，仅基于用户主动输入的时间数据和经过科学验证的 90 分钟睡眠周期参数进行预测性计算。

### 核心价值主张

1. **浅睡眠阶段唤醒**：通过在睡眠周期结束时（浅睡眠阶段）唤醒，显著减少起床不适感
2. **完全本地运行**：所有数据存储和处理均在设备本地完成，零隐私风险
3. **数据驱动优化**：记录睡眠历史，分析作息规律，提供个性化建议

### 目标平台

- **iOS 15.0+**（主要目标平台）
- **macOS 26.2+**（通过 Mac Catalyst 支持）
- **visionOS 26.2+**（Apple Vision Pro）

## 技术栈

| 技术 | 版本/框架 | 用途 |
|:---|:---|:---|
| 编程语言 | Swift 5.0 | 主要开发语言 |
| UI 框架 | SwiftUI | 用户界面构建 |
| 数据持久化 | SQLite + UserDefaults | 睡眠记录和设置存储 |
| 构建工具 | Xcode 26.2 | 开发和构建 |
| 闹钟触发 | UNUserNotificationCenter | 本地通知调度 |
| 音频播放 | AVAudioPlayer | 铃声播放（规划中） |

## 项目结构

```
CircaAlarm/
├── CircaAlarm.xcodeproj/          # Xcode 项目配置
│   ├── project.pbxproj            # 项目文件（目标、构建设置等）
│   ├── project.xcworkspace/       # 工作区配置
│   └── xcuserdata/               # 用户特定数据
├── CircaAlarm/                    # 源代码目录
│   ├── CircaAlarmApp.swift        # 应用入口（@main）
│   ├── ContentView.swift          # 主界面视图
│   ├── Assets.xcassets/           # 资源文件
│   │   ├── AppIcon.appiconset/    # 应用图标（iOS/macOS/visionOS）
│   │   └── AccentColor.colorset/  # 主题色
│   └── README.md                  # 详细需求文档（中文）
└── AGENTS.md                      # 本文件
```

### 当前状态

项目目前处于**初始阶段**，仅包含 Xcode 生成的模板代码。`CircaAlarm/README.md` 包含一份完整的中文需求文档（约 780 行），详细描述了：

- 产品概述与核心价值
- 核心功能模块设计（睡眠周期计算、兜底策略、闹钟交互）
- 数据记录与分析系统
- 用户设置系统
- 界面原型设计
- 数据结构与存储方案
- 技术实现要点

## 核心算法

### 最佳唤醒时间计算

```swift
func calculateOptimalWakeTime(
    bedTimeClicked: Date,        // "我要睡了"点击时间
    fallAsleepDelay: TimeInterval, // 入睡所需时间（默认10分钟）
    targetWakeTime: Date          // 预设起床时间
) -> Date? {
    let estimatedFallAsleep = bedTimeClicked.addingTimeInterval(fallAsleepDelay)
    let cycleDuration: TimeInterval = 5400 // 90分钟 = 5400秒
    
    let timeUntilTarget = targetWakeTime.timeIntervalSince(estimatedFallAsleep)
    
    // 边界条件：不足一个完整周期
    guard timeUntilTarget >= cycleDuration else {
        return nil // 触发兜底策略
    }
    
    let completedCycles = Int(floor(timeUntilTarget / cycleDuration))
    let optimalWakeTime = estimatedFallAsleep.addingTimeInterval(
        TimeInterval(completedCycles) * cycleDuration
    )
    
    // 精度保护：确保不超过目标时间
    return min(optimalWakeTime, targetWakeTime)
}
```

### 关键设计决策

1. **睡眠周期时长**：固定 90 分钟（基于睡眠科学研究）
2. **入睡延迟**：用户可配置，默认 10 分钟，范围 5-30 分钟
3. **唤醒窗口**：最佳唤醒时间 ±10 分钟（可调 ±5 至 ±30 分钟）
4. **兜底策略**：
   - 智能优先（优先周期优化，失败时严格按预设时间）
   - 最晚时间兜底（设置独立最晚响铃时间）
   - 严格按时（始终在预设时间响铃）

## 数据模型

### SleepRecord（睡眠记录）

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| id | UUID | 主键 |
| date | Date | 记录日期 |
| bedTimeClicked | Date | "我要睡了"点击时间 |
| estimatedFallAsleepTime | Date | 估算入睡时间 |
| targetWakeTime | Date | 预设起床时间 |
| plannedOptimalWakeTime | Date? | 计划最佳唤醒时间（可能为 nil） |
| actualAlarmTime | Date | 实际响铃时间 |
| actualWakeTime | Date? | 实际醒来时间（用户停止闹钟） |
| snoozeCount | Int | 延迟次数 |
| usedFallback | Bool | 是否使用兜底策略 |
| comfortLevel | ComfortLevel? | 舒适度枚举 |

### 数据存储

| 层级 | 机制 | 用途 | 键名规范 |
|:---|:---|:---|:---|
| 轻量设置层 | UserDefaults | UserSettings | `com.bioalarm.[模块].[项]` |
| 大量记录层 | SQLite | SleepRecord 数组 | 文件 `sleep_records.db` |

## 开发约定

### 代码风格

- 使用 Swift 标准命名规范（UpperCamelCase 类型，lowerCamelCase 变量/函数）
- 中文注释（与现有代码风格保持一致）
- 文件头模板：
  ```swift
  //
  //  文件名.swift
  //  CircaAlarm
  //
  //  Created by 牛慧升 on YYYY/MM/DD.
  //
  ```

### 隐私与安全

- **不请求任何网络权限**
- **不集成任何 analytics 或 crash reporting SDK**
- **所有数据处理完全本地**
- 仅需要本地通知权限（用于闹钟触发）
- 可选：SQLCipher 数据库加密（未来版本考虑）

### 国际化

当前版本以**中文为主要语言**，所有用户界面文本和文档均为中文。如需支持多语言，建议后续添加本地化资源。

## 构建与运行

### 环境要求

- macOS（运行 Xcode）
- Xcode 26.2 或更高版本
- iOS 15.0+ SDK
- Swift 5.0+

### 构建步骤

```bash
# 打开项目
cd /Users/niuhuisheng/Documents/JavaWorkSpace.nosync/CircaAlarm
open CircaAlarm.xcodeproj

# 在 Xcode 中：
# 1. 选择目标设备（iPhone Simulator 或真机）
# 2. 点击 Run 按钮（⌘+R）构建并运行
```

### 构建设置

| 配置项 | 值 |
|:---|:---|
| Bundle Identifier | com.alvin.CircaAlarm |
| 版本 | 1.0 |
| 代码签名 | Automatic |
| 沙盒 | 启用（ENABLE_APP_SANDBOX = YES） |
| 并发模型 | MainActor（SWIFT_DEFAULT_ACTOR_ISOLATION） |
| 启用预览 | YES（SwiftUI Preview） |

## 测试策略

（规划中）建议测试覆盖：

1. **单元测试**：核心算法（唤醒时间计算、兜底策略决策）
2. **集成测试**：数据持久化（SQLite 操作、UserDefaults 读写）
3. **UI 测试**：关键用户流程（设置闹钟、标记睡眠、停止闹钟）
4. **边界测试**：跨午夜场景、时区变化、不足一个周期的场景

## 权限要求

| 权限 | 必需性 | 申请时机 |
|:---|:---|:---|
| 本地通知 | **必需** | 首次设置闹钟时 |
| 网络访问 | **无需** | - |
| 传感器（麦克风、加速度计） | **无需** | - |
| HealthKit | 可选（未来） | 未来版本考虑 |

## 后续开发路线图

### Phase 1：核心功能（MVP）
- [ ] 实现主界面（"我要睡了"按钮）
- [ ] 实现睡前确认页（计算预览）
- [ ] 实现响铃界面
- [ ] 本地通知调度
- [ ] 数据持久化层

### Phase 2：数据与统计
- [ ] 历史记录列表
- [ ] 统计图表（趋势、热力图）
- [ ] 健康评估与建议

### Phase 3：增强功能
- [ ] 自定义铃声导入
- [ ] 数据导出（CSV/JSON）
- [ ] 可选 iCloud 同步
- [ ] Apple Watch 配套应用（可选）

## 参考资料

- `CircaAlarm/README.md`：详细需求文档（780 行，中文）
- Apple 官方文档：
  - [SwiftUI](https://developer.apple.com/documentation/swiftui)
  - [UserNotifications](https://developer.apple.com/documentation/usernotifications)
  - [GRDB](https://github.com/groue/GRDB.swift)（推荐 SQLite 封装库）

---

**文档版本**：1.0  
**最后更新**：2026-02-18  
**项目状态**：需求确认完成，待开发实现
