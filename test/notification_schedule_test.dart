import 'package:china_holiday_reminder/data/app_settings.dart';
import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:china_holiday_reminder/notifications/notification_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  final timeline = HolidayTimeline.fromDays(loadFixture('2026.json').days);

  Future<AppSettings> freshSettings() async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    await settings.restore();
    return settings;
  }

  // 验收场景：今天 = 2026-09-20（明天 9/21）中午。
  final now = DateTime(2026, 9, 20, 12, 0);

  group('buildSchedule（默认设置：提前 1 天 09:00 / 前一天 20:00）', () {
    test('生成中秋、国庆两条简报与 10/10 调休提醒', () async {
      final events = buildSchedule(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      expect(
        events.map((e) => '${e.kind}:${e.scheduledAt}'),
        [
          'NotificationKind.briefing:2026-09-24 09:00:00.000',
          'NotificationKind.briefing:2026-09-30 09:00:00.000',
          'NotificationKind.makeup:2026-10-09 20:00:00.000',
        ],
      );
      expect(
        events.first.title,
        '明天就是中秋节',
      );
    });

    test('9/30 国庆简报文案（含两个调休日）', () async {
      final events = buildSchedule(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      final national = events.firstWhere(
        (e) => e.kind == NotificationKind.briefing &&
            e.scheduledAt == DateTime(2026, 9, 30, 9),
      );
      expect(national.title, '明天就是国庆节');
      expect(
        national.body,
        '10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班',
      );
    });

    test('9/20 调休的提醒时刻（9/19 20:00）已过，不再排期', () async {
      final events = buildSchedule(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      expect(
        events.where(
          (e) =>
              e.kind == NotificationKind.makeup &&
              e.body.contains('9/20'),
        ),
        isEmpty,
      );
    });

    test('10/10 调休提醒：前一天 20:00，文案正确', () async {
      final events = buildSchedule(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      final makeup = events
          .where((e) => e.kind == NotificationKind.makeup)
          .single;
      expect(makeup.scheduledAt, DateTime(2026, 10, 9, 20));
      expect(makeup.title, '调休上班提醒');
      expect(
        makeup.body,
        '明天 10/10(周六) 是国庆节调休上班日，别忘了去上班',
      );
    });
  });

  group('buildSchedule（设置变更）', () {
    test('提前 3 天：国庆简报在 9/28 09:00，标题「3 天后就是国庆节」', () async {
      final settings = await freshSettings();
      await settings.setAdvanceDays(3);
      final events = buildSchedule(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      final national = events.firstWhere(
        (e) => e.kind == NotificationKind.briefing &&
            e.title == '3 天后就是国庆节',
      );
      expect(national.scheduledAt, DateTime(2026, 9, 28, 9));
      expect(
        national.body,
        '10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班',
      );
    });

    test('自定义简报时刻 08:30', () async {
      final settings = await freshSettings();
      await settings.setBriefingTime(const TimeOfDay(hour: 8, minute: 30));
      final events = buildSchedule(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      expect(
        events.where((e) => e.kind == NotificationKind.briefing).every(
          (e) => e.scheduledAt.hour == 8 && e.scheduledAt.minute == 30,
        ),
        isTrue,
      );
    });

    test('关闭开关后对应通知消失', () async {
      final settings = await freshSettings();
      await settings.setBriefingEnabled(false);
      var events = buildSchedule(timeline: timeline, settings: settings, now: now);
      expect(events.every((e) => e.kind == NotificationKind.makeup), isTrue);

      await settings.setMakeupEnabled(false);
      events = buildSchedule(timeline: timeline, settings: settings, now: now);
      expect(events, isEmpty);
    });

    test('45 天窗口外的事件不排期', () async {
      final late = DateTime(2026, 12, 1); // 国庆与元旦(2027 未加载) 都超窗口
      final events = buildSchedule(
        timeline: timeline,
        settings: await freshSettings(),
        now: late,
      );
      expect(
        events.every(
          (e) => !e.scheduledAt.isAfter(late.add(const Duration(days: 45))),
        ),
        isTrue,
      );
    });
  });
}
