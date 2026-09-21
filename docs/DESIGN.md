# 中国法定节假日提醒器 — 设计方案

> 一款简单小巧的 Flutter 应用（Material Design 3），在法定节假日前推送简报、在调休上班日前推送提醒。
> 本地优先、无后端、无账号，目标平台 Android。

## 1. 需求与目标

| # | 需求 | 承接设计 |
|---|---|---|
| R1 | 一段法定节假日开始前，发送该假期的简报 | 节前简报通知（§4） |
| R2 | 调休上班日前，提醒"某日是调休，需要上班" | 调休提醒通知（§4） |
| R3 | 简单小巧 | 零后端、裸 ChangeNotifier、两个页面（§2、§5） |
| R4 | Flutter + Material Design 3 | `ColorScheme.fromSeed`、NavigationBar、SegmentedButton 等 M3 组件（§5） |

## 2. 总体架构

```
┌─────────────────────────────────────────────┐
│  UI 层        home_page / settings_page     │
│               (ListenableBuilder 绑定)       │
├─────────────────────────────────────────────┤
│  领域层       models/holiday.dart           │
│               分组算法 / 调休关联 / 简报文案   │
├─────────────────────────────────────────────┤
│  服务层       holiday_repository  settings  │
│               notification_service          │
├─────────────────────────────────────────────┤
│  基础设施     http / shared_preferences /    │
│               flutter_local_notifications   │
└─────────────────────────────────────────────┘
```

技术选型：

| 关注点 | 选型 | 理由 |
|---|---|---|
| 状态管理 | 裸 `ChangeNotifier` + `ListenableBuilder` | 两页应用，不引入 Provider/Riverpod，保持小巧 |
| 通知 | `flutter_local_notifications` + `timezone` | 唯一成熟的跨端本地调度方案 |
| 网络 | `http` | 只需 GET 一个 JSON |
| 缓存 / 设置 | `shared_preferences` | 数据 JSON 串 + 少量开关，无需数据库 |
| 日期格式化 | `intl` | 中文星期 / 日期 |

## 3. 数据层

### 3.1 数据来源

使用社区维护的 [NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)（即国务院公告的结构化数据，含公告原文链接 `papers`）。

- 主地址：`https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/{year}.json`
- 备地址：`https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json`（主地址超时时切换）

数据格式（每年一个文件）：

```json
{
  "year": 2026,
  "papers": ["https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm"],
  "days": [
    { "name": "春节",   "date": "2026-02-15", "isOffDay": true  },
    { "name": "国庆节", "date": "2026-09-20", "isOffDay": false }
  ]
}
```

- `isOffDay: true` → 放假；`false` → 调休上班。

### 3.2 刷新策略

- 启动 / 回前台时检查，每天最多请求一次；
- 成功后写入 SharedPreferences 缓存，离线可用；
- 每年 11 月起顺带拉取下一年文件，成功后合并进时间线（覆盖元旦等跨年假期）；
- 次年安排未公布时（如 2027），UI 显示空态提示，数据发布后自动跟进。

### 3.3 派生模型（`lib/models/holiday.dart`）

| 模型 | 说明 |
|---|---|
| `HolidayDay` | 单条记录 `{name, date, isOffDay}` |
| `HolidaySegment` | 假期段：把 `isOffDay=true` 的条目按**日历连续**合并 |
| `MakeupDay` | 调休上班日：`isOffDay=false` 的条目，就近关联到 ±10 天内的假期段 |

分组算法必须处理的真实边界：

1. **相邻但不同源的假期不合并**——2026 年中秋（9/25–27）与国庆（10/1–7）之间隔着工作日，应拆为两段、各自关联自己的调休日；
2. **合并名原样展示**——如 2025 年的「国庆节、中秋节」在数据中即为一格；
3. **调休可远离假期段**——如 2026-09-20（国庆调休）在假期段前 11 天，关联窗口需覆盖。

## 4. 通知系统

### 4.0 通知渠道（可多选）

| 渠道 | 定位 | 默认 | 机制 |
|---|---|---|---|
| 系统日历事件 | 优先 | **开** | 静默写入设备日历（CalendarContract），由日历 App 的提醒推送，本应用无需存活 |
| App 本地通知 | 备选 | **关** | flutter_local_notifications `zonedSchedule` 精确闹钟排期 |

- 两渠道互相独立，开关存于 `AppSettings`（`settings_channel_calendar` / `settings_channel_local`）；
- 渠道开关只决定"投递方式"，「节前简报 / 调休提醒」两个内容开关对两个渠道共同生效；
- 本地渠道关闭时 `cancelAll()` 清理；日历渠道关闭时按 `chr:` 键前缀删除本应用创建的全部事件（绝不误删用户事件）；
- 日历桥为应用内自维护的 MethodChannel（`android/app/.../CalendarBridge.kt`，通道 `app/calendar_bridge`）：
  静默写入 / 按 SYNC_DATA1 键回读 / 删除 / 权限申请；未采用 device_calendar（timezone ^0.9 与本项目冲突）、add_2_calendar（仅弹插入界面，无静默写入与更新删除）。

### 4.1 通知种类

两个 Android `NotificationChannel`：`节前简报`（低优先级横幅）、`调休提醒`（默认优先级）。

| 通知 | 触发时机 | 内容模板 |
|---|---|---|
| 节前简报 | `段首日 − N 天`（N ∈ 1/2/3，设置项，默认 1）当天 09:00 | 标题「3 天后就是国庆节」<br>正文「10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班」 |
| 调休提醒 | 调休日**前一天** 20:00 | 「明天 9/20(周日) 是国庆调休上班日，别忘了去上班」 |

同一套内容在日历渠道生成 **两类事件**（"两者都写"）：

| 日历事件 | 形态 | 键 |
|---|---|---|
| 假期区间 | 多日全天事件（纯展示，不提醒） | `chr:span:段首日` |
| 节前简报 | 提醒时刻起 30 分钟的定时事件，开场即提醒 | `chr:brief:段首日` |
| 调休上班日 | 当日全天事件（纯展示，不提醒） | `chr:mday:调休日` |
| 调休提醒 | 前一天时刻起 30 分钟的定时事件，开场即提醒 | `chr:mrem:调休日` |

### 4.2 调度规则

- 仅在四个时机重算：启动 / 回前台 / 设置变更 / 数据刷新；
- 本地通知：`cancelAll()` 后对**未来约 45 天**内的事件重新 `zonedSchedule`——45 天窗口足以覆盖最近 1 个假期段及其全部调休日，且每次打开 App 都会滚动续排；
- 日历事件：`buildCalendarPlan` 产出窗口内计划，与设备现状做 **幂等 diff**（SYNC_DATA2 内容指纹变化 → 删除重建；窗口滚出 → 清理），由 `CalendarService.sync` 落桥执行；
- Android 13+ 首次启动引导 `POST_NOTIFICATIONS`（仅本地渠道开启时）；日历渠道在设置页开启时引导 `READ/WRITE_CALENDAR`；
- 调度优先 `AndroidScheduleMode.exactAllowWhileIdle`，捕获系统精确闹钟权限异常后自动降级 `inexactAllowWhileIdle`。

### 4.3 文案生成

简报正文由纯函数生成，便于完整单测：

```dart
String buildBriefing(HolidaySegment seg, List<MakeupDay> makeups, int advanceDays);
```

## 5. UI 设计（Material Design 3）

主题色：默认系统取色（Material You），可在"个性化"中改用莫奈色板种子色；深色模式支持 跟随系统 / 浅色 / 深色。NavigationBar 两个目的地（首页 / 设置）。

### 5.1 首页

1. **「今天」状态条**（仅相关时出现）：
   - 放假中：「国庆假期进行中，还剩 3 天」
   - 调休中：「今天是调休上班日」
   - 节后首日：「假期结束，明天恢复上班」
2. **下一个假期大卡片**：名称、倒计时大数字、放假区间、调休安排 chips、下次简报发送时间预览；
3. **未来事件列表**（至多 3 条）：下一个假期 + 最近调休日，`ListTile` 形式；
4. **空态**：次年数据未公布时显示「2027 年放假安排尚未发布」。

### 5.2 设置

设置主页与子页均为 MD3 大标题折叠栏（`SliverAppBar.large`：进入时大标题，上滑渐缩对齐返回箭头，下拉还原）；内容采用大圆角分组卡片（`surfaceContainerHigh` 背景 + 行间细分割线），图标为单色、无圆形底色背景。设置主页四个入口点击进入子页：

| 子页 | 内容 |
|---|---|
| 提醒与通知 | 通知方式多选（系统日历·优先 默认开 / App 本地通知·备选 默认关）+ 按已选渠道出现「权限与系统设置」（日历权限授权 / 通知权限跳转）；节前简报（开关 / 提前 1/2/3 天 `SegmentedButton` / 发送时刻 `showTimePicker`）；调休提醒（开关 / 提醒时刻） |
| 个性化 | 主题色：系统取色（Material You）或莫奈色板种子色（圆形色块单选）；深色模式：跟随系统 / 浅色 / 深色 |
| 数据 | 数据来源（NateScarlet/holiday-cn 项目链接）、已加载年份、上次更新时间、立即刷新、国务院公告原文链接 |
| 关于 | 应用图标 / 名称 / 版本（`package_info_plus`）、简介、数据来源、开源许可（`LicensePage`） |

任一项变更后即时重排通知，并以 SnackBar 确认。

## 6. 工程结构

```
lib/
  main.dart                      # timezone 初始化、依赖装配
  app.dart                       # MaterialApp / 主题 / NavigationBar
  models/holiday.dart            # HolidayDay / Segment / MakeupDay + 分组算法
  data/holiday_repository.dart   # 获取、备源、缓存、派生时间线 (ChangeNotifier)
  data/app_settings.dart         # SharedPreferences 封装 (ChangeNotifier)
  data/monet_colors.dart         # 莫奈主题色板
  notifications/notification_service.dart   # 本地通知渠道（备选）
  notifications/briefing_text.dart          # 文案纯函数（两渠道共用）
  notifications/calendar_plan.dart          # 日历事件计划纯函数（buildCalendarPlan + FNV-1a 指纹）
  notifications/calendar_bridge.dart        # 日历桥接口 + Android MethodChannel 实现
  notifications/calendar_service.dart       # 日历渠道：权限 + 幂等 diff 同步
  ui/home_page.dart
  ui/settings_page.dart          # 设置主页（四个子页入口）
  ui/settings/                   # 提醒与通知 / 个性化 / 数据 / 关于 子页
  ui/widgets/                    # 假期卡片、状态条等
android/app/src/main/kotlin/.../
  CalendarBridge.kt              # 日历桥原生实现（CalendarContract 静默写入/回读/删除 + 权限）
test/
  segment_grouping_test.dart     # 使用 2025/2026 真实 fixture
  makeup_association_test.dart
  briefing_text_test.dart
  notification_schedule_test.dart # 本地通知渠道纯函数
  calendar_plan_test.dart         # 日历事件计划纯函数
  calendar_service_test.dart      # diff 同步（假桥）
  fake_calendar_bridge.dart       # 内存版日历桥
assets/fixtures/                 # 2025.json / 2026.json 样本，离线测试用
```

## 7. 实施步骤

1. `flutter create --platforms android`，`flutter pub add flutter_local_notifications timezone http shared_preferences intl`；
2. 模型 + 分组算法 + 单测（先测试后实现）；
3. `HolidayRepository`（网络 + 缓存）与 `AppSettings`；
4. `NotificationService` + `briefing_text` 及其单测；
5. 首页 / 设置页 UI + M3 主题；
6. 平台配置：Android manifest（`POST_NOTIFICATIONS`、`READ/WRITE_CALENDAR`、`INTERNET`、minSdk）；
7. `flutter analyze` 零告警、`flutter test` 全绿，Android 模拟器手动验证通知弹出。

## 8. 验收标准

- [ ] `flutter analyze` 无 error / warning；
- [ ] 纯函数单测（分组 / 调休关联 / 简报文案）≥ 10 例，全部通过；
- [ ] 以 2026 年真实数据验证：中秋与国庆拆为两段；9/20、10/10 正确关联国庆节；
- [ ] 设定"明天 = 2026-09-21"场景时，简报与调休文案内容正确；
- [ ] 断网启动 App 可凭缓存正常展示首页与调度通知；
- [ ] Android 13+ 首次启动正确引导通知授权。

## 9. 默认值汇总

| 项 | 默认值 |
|---|---|
| 通知方式 · 系统日历事件（优先） | 开 |
| 通知方式 · App 本地通知（备选） | 关 |
| 节前简报提前天数 | 1 天（可选 1/2/3） |
| 节前简报时刻 | 09:00 |
| 调休提醒时刻 | 前一天 20:00 |
| 数据检查频率 | 每日一次 |
| 通知滚动窗口 | 未来 45 天 |
| 主题色 | 系统取色（Material You，可切莫奈色板） |
| 深色模式 | 跟随系统 |
