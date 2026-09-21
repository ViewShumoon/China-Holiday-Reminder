/// 通知调度：纯函数计算未来窗口内应排的通知 + 插件封装。
library;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_settings.dart';
import '../models/holiday.dart';
import 'briefing_text.dart';

/// 一条待排通知（纯值对象，便于单测）。
class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  final int id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// 本地墙上时间（北京时间语义）。
  final DateTime scheduledAt;

  @override
  String toString() =>
      'ScheduledNotification($id, $kind, ${scheduledAt.toString()}, $title)';
}

enum NotificationKind { briefing, makeup }

/// 调度通知 id：日序数 << 1 | 种类，保证稳定且互不冲突。
int notificationIdFor(DateTime date, NotificationKind kind) =>
    (date.year * 10000 + date.month * 100 + date.day) * 2 +
    (kind == NotificationKind.briefing ? 0 : 1);

/// 重算规则（设计 §4.2）：cancelAll 后对未来 [windowDays] 天内的事件重新排期。
/// 节前简报：段首日 − N 天 @ briefingTime；调休提醒：调休日前一天 @ makeupTime。
List<ScheduledNotification> buildSchedule({
  required HolidayTimeline timeline,
  required AppSettings settings,
  required DateTime now,
  int windowDays = 45,
}) {
  final events = <ScheduledNotification>[];
  final horizon = now.add(Duration(days: windowDays));

  if (settings.briefingEnabled) {
    for (final segment in timeline.segments) {
      final fireDate = _atTime(
        segment.start.subtract(Duration(days: settings.advanceDays)),
        settings.briefingTime,
      );
      if (!_inWindow(fireDate, now, horizon)) continue;
      events.add(
        ScheduledNotification(
          id: notificationIdFor(fireDate, NotificationKind.briefing),
          kind: NotificationKind.briefing,
          title: briefingTitle(segment, settings.advanceDays),
          body: buildBriefing(segment, timeline.makeupsOf(segment), settings.advanceDays),
          scheduledAt: fireDate,
        ),
      );
    }
  }

  if (settings.makeupEnabled) {
    for (final makeup in timeline.makeups) {
      final fireDate = _atTime(
        makeup.day.date.subtract(const Duration(days: 1)),
        settings.makeupTime,
      );
      if (!_inWindow(fireDate, now, horizon)) continue;
      events.add(
        ScheduledNotification(
          id: notificationIdFor(fireDate, NotificationKind.makeup),
          kind: NotificationKind.makeup,
          title: makeupTitle(),
          body: makeupBody(makeup),
          scheduledAt: fireDate,
        ),
      );
    }
  }

  events.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return events;
}

DateTime _atTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

bool _inWindow(DateTime at, DateTime now, DateTime horizon) =>
    at.isAfter(now) && !at.isAfter(horizon);

/// 平台通知服务封装（渠道、权限、调度降级）。
class NotificationService {
  NotificationService();

  static const briefingChannelId = 'holiday_briefing';
  static const makeupChannelId = 'holiday_makeup';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 初始化插件与时区（本应用面向中国假期，固定北京时间语义）。
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        briefingChannelId,
        '节前简报',
        description: '法定节假日开始前的放假简报',
        importance: Importance.low,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        makeupChannelId,
        '调休提醒',
        description: '调休上班日前一天的上班提醒',
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  /// Android 13+ 首次启动引导通知授权。
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  /// 系统层面的通知总开关（null = 平台不支持/未知）。
  Future<bool?> notificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    return android?.areNotificationsEnabled();
  }

  /// 跳转本应用的系统通知设置页。
  Future<void> openNotificationSettings() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    await android?.openAppNotificationSettings();
  }

  /// 重排：cancelAll 后对窗口内事件 zonedSchedule（设计 §4.2）。
  Future<void> reschedule(List<ScheduledNotification> events) async {
    await _plugin.cancelAll();
    for (final event in events) {
      await _scheduleOne(event);
    }
  }

  /// 全量清除（本地渠道关闭时调用）。
  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> _scheduleOne(ScheduledNotification event) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        event.kind == NotificationKind.briefing
            ? briefingChannelId
            : makeupChannelId,
        event.kind == NotificationKind.briefing ? '节前简报' : '调休提醒',
      ),
    );
    final scheduledDate = tz.TZDateTime.from(event.scheduledAt, tz.local);
    final mode = await _preferredScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: event.id,
        title: event.title,
        body: event.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: mode,
      );
    } on PlatformException {
      // 精确闹钟权限异常时降级为非精确。
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      await _plugin.zonedSchedule(
        id: event.id,
        title: event.title,
        body: event.body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<AndroidScheduleMode> _preferredScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final canExact = await android.canScheduleExactNotifications();
    return (canExact ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
