/// 日历渠道：生成应写入系统日历的事件计划（纯函数，离线可测）。
///
/// 每个内容项写两类事件（方案「两者都写」）：
/// - 全天区间事件负责在日历中展示假期/调休日；
/// - 定时提醒事件（30 分钟、开场即提醒）负责在精确时刻由日历 App 推送。
library;

import 'package:flutter/material.dart' show TimeOfDay;

import '../data/app_settings.dart';
import '../models/holiday.dart';
import 'briefing_text.dart';

/// 本应用写入日历事件的 key 前缀（存于 CalendarContract SYNC_DATA1），
/// 同步 diff 与全量清理都以它为界，绝不误删用户自建事件。
const calendarKeyPrefix = 'chr:';

/// 一条应存在于系统日历中的事件（值对象）。
class CalendarEventPlan {
  const CalendarEventPlan({
    required this.key,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.allDay,
    this.reminderMinutes,
  });

  /// 稳定唯一键：'chr:span:…' 等，写入 SYNC_DATA1。
  final String key;
  final String title;
  final String description;

  /// 本地墙上时间；全天事件为当日 0 点，结束时间为次日/段后一天 0 点（不含）。
  final DateTime start;
  final DateTime end;

  final bool allDay;

  /// 开场前 N 分钟提醒（0 = 开场时刻），null 表示不提醒。
  final int? reminderMinutes;

  /// 内容指纹（写入 SYNC_DATA2）：文案或时间任一变化即触发重建。
  String get hash => _fnv1a(
    '$title|$description|${start.toIso8601String()}|'
    '${end.toIso8601String()}|$allDay|$reminderMinutes',
  );

  @override
  String toString() => 'CalendarEventPlan($key, $title, $start)';
}

/// 滚动重算（设计 §4.2）：产出 [windowDays] 窗口内应存在的日历事件。
/// 只消费「节前简报 / 调休提醒」内容开关；通知渠道开关由调用方判断。
List<CalendarEventPlan> buildCalendarPlan({
  required HolidayTimeline timeline,
  required AppSettings settings,
  required DateTime now,
  int windowDays = 45,
}) {
  final plans = <CalendarEventPlan>[];
  final horizon = now.add(Duration(days: windowDays));

  if (settings.briefingEnabled) {
    for (final segment in timeline.segments) {
      final spanStart = startOfDate(segment.start);
      final spanEnd = startOfDate(segment.end).add(const Duration(days: 1));
      if (_overlapsWindow(spanStart, spanEnd, now, horizon)) {
        plans.add(
          CalendarEventPlan(
            key: '${calendarKeyPrefix}span:${formatDate(segment.start)}',
            title: '${segment.name} · 放假',
            description:
                '${monthDay(segment.start)}(${weekdayCn(segment.start)})'
                '至${monthDay(segment.end)}(${weekdayCn(segment.end)})'
                '共 ${segment.lengthInDays} 天',
            start: spanStart,
            end: spanEnd,
            allDay: true,
          ),
        );
      }
      final fire = _atTime(
        segment.start.subtract(Duration(days: settings.advanceDays)),
        settings.briefingTime,
      );
      if (_startsInWindow(fire, now, horizon)) {
        plans.add(
          CalendarEventPlan(
            key: '${calendarKeyPrefix}brief:${formatDate(segment.start)}',
            title: briefingTitle(segment, settings.advanceDays),
            description: buildBriefing(
              segment,
              timeline.makeupsOf(segment),
              settings.advanceDays,
            ),
            start: fire,
            end: fire.add(const Duration(minutes: 30)),
            allDay: false,
            reminderMinutes: 0,
          ),
        );
      }
    }
  }

  if (settings.makeupEnabled) {
    for (final makeup in timeline.makeups) {
      final dayStart = startOfDate(makeup.day.date);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final holidayName = makeup.holidayName;
      if (_overlapsWindow(dayStart, dayEnd, now, horizon)) {
        plans.add(
          CalendarEventPlan(
            key: '${calendarKeyPrefix}mday:${formatDate(dayStart)}',
            title: '调休上班 · $holidayName',
            description: '今天是$holidayName调休上班日，别忘了去上班',
            start: dayStart,
            end: dayEnd,
            allDay: true,
          ),
        );
      }
      final fire = _atTime(
        makeup.day.date.subtract(const Duration(days: 1)),
        settings.makeupTime,
      );
      if (_startsInWindow(fire, now, horizon)) {
        plans.add(
          CalendarEventPlan(
            key: '${calendarKeyPrefix}mrem:${formatDate(dayStart)}',
            title: makeupTitle(),
            description: makeupBody(makeup),
            start: fire,
            end: fire.add(const Duration(minutes: 30)),
            allDay: false,
            reminderMinutes: 0,
          ),
        );
      }
    }
  }

  plans.sort((a, b) => a.start.compareTo(b.start));
  return plans;
}

bool _overlapsWindow(
  DateTime start,
  DateTime end,
  DateTime now,
  DateTime horizon,
) => end.isAfter(now) && !start.isAfter(horizon);

bool _startsInWindow(DateTime at, DateTime now, DateTime horizon) =>
    at.isAfter(now) && !at.isAfter(horizon);

DateTime _atTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

/// FNV-1a 64 位：跨进程稳定的内容哈希（Dart int 乘法按 64 位回绕）。
String _fnv1a(String input) {
  var hash = 0xCBF29CE484222325;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * 0x100000001B3) & 0x7FFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
