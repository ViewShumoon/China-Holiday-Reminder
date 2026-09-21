/// 日历事件计划纯函数测试（2026 真实数据样本，now = 2026-09-20 12:00）。
library;

import 'package:china_holiday_reminder/data/app_settings.dart';
import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:china_holiday_reminder/notifications/calendar_plan.dart';
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

  /// 今天 = 2026-09-20（国庆调休上班日）中午，窗口 45 天 → 截至 11-04。
  final now = DateTime(2026, 9, 20, 12, 0);

  group('buildCalendarPlan（默认设置）', () {
    test('窗口内产出：调休全天 + 中秋/国庆简报与区间 + 国庆调休', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      expect(
        plans.map((p) => p.key),
        [
          'chr:mday:2026-09-20',
          'chr:brief:2026-09-25',
          'chr:span:2026-09-25',
          'chr:brief:2026-10-01',
          'chr:span:2026-10-01',
          'chr:mrem:2026-10-10',
          'chr:mday:2026-10-10',
        ],
      );
      // 按开始时间升序。
      for (var i = 1; i < plans.length; i++) {
        expect(
          !plans[i].start.isBefore(plans[i - 1].start),
          isTrue,
          reason: '${plans[i].key} 顺序错误',
        );
      }
    });

    test('全天区间事件：10/1–10/7，结束次日 0 点（不含），无提醒', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      final span = plans.firstWhere((p) => p.key == 'chr:span:2026-10-01');
      expect(span.allDay, isTrue);
      expect(span.reminderMinutes, isNull);
      expect(span.start, DateTime(2026, 10, 1, 0, 0));
      expect(span.end, DateTime(2026, 10, 8, 0, 0));
      expect(span.title, endsWith('· 放假'));
      expect(span.description, contains('共 7 天'));
    });

    test('简报为 30 分钟定时事件，开场即提醒（分钟偏移 0）', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      final brief = plans.firstWhere((p) => p.key == 'chr:brief:2026-10-01');
      expect(brief.allDay, isFalse);
      expect(brief.reminderMinutes, 0);
      expect(brief.start, DateTime(2026, 9, 30, 9, 0));
      expect(brief.end.difference(brief.start), const Duration(minutes: 30));
      expect(brief.title, '明天就是国庆节');
      expect(
        brief.description,
        '10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班',
      );
    });

    test('调休上班日全天事件 + 前一天 20:00 的定时提醒', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      final day = plans.firstWhere((p) => p.key == 'chr:mday:2026-10-10');
      expect(day.allDay, isTrue);
      expect(day.start, DateTime(2026, 10, 10, 0, 0));
      expect(day.end, DateTime(2026, 10, 11, 0, 0));
      expect(day.title, startsWith('调休上班'));

      final rem = plans.firstWhere((p) => p.key == 'chr:mrem:2026-10-10');
      expect(rem.allDay, isFalse);
      expect(rem.reminderMinutes, 0);
      expect(rem.start, DateTime(2026, 10, 9, 20, 0));
      expect(rem.title, '调休上班提醒');
      expect(rem.description, contains('10/10(周六)'));
    });

    test('今天的调休日（9/20）仍写入全天事件，但其提醒已过期', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: now,
      );
      expect(plans.any((p) => p.key == 'chr:mday:2026-09-20'), isTrue);
      expect(plans.any((p) => p.key == 'chr:mrem:2026-09-20'), isFalse);
    });
  });

  group('buildCalendarPlan（设置变更）', () {
    test('提前 3 天：简报事件改到 9/28 09:00，标题随之更新', () async {
      final settings = await freshSettings();
      await settings.setAdvanceDays(3);
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      final brief = plans.firstWhere((p) => p.key == 'chr:brief:2026-10-01');
      expect(brief.start, DateTime(2026, 9, 28, 9, 0));
      expect(brief.title, '3 天后就是国庆节');
    });

    test('自定义简报时刻 08:30', () async {
      final settings = await freshSettings();
      await settings.setBriefingTime(const TimeOfDay(hour: 8, minute: 30));
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      for (final brief in plans.where((p) => p.key.startsWith('chr:brief:'))) {
        expect(brief.start.hour, 8);
        expect(brief.start.minute, 30);
      }
    });

    test('关闭节前简报 → 无 span/brief 事件', () async {
      final settings = await freshSettings();
      await settings.setBriefingEnabled(false);
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      expect(
        plans.where(
          (p) => p.key.contains('span') || p.key.contains('brief'),
        ),
        isEmpty,
      );
    });

    test('两个内容开关全关 → 空计划', () async {
      final settings = await freshSettings();
      await settings.setBriefingEnabled(false);
      await settings.setMakeupEnabled(false);
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      );
      expect(plans, isEmpty);
    });

    test('窗口滚动：12 月起 2026 事件全部滚出', () async {
      final plans = buildCalendarPlan(
        timeline: timeline,
        settings: await freshSettings(),
        now: DateTime(2026, 12, 1, 12, 0),
      );
      expect(plans, isEmpty);
    });
  });

  group('内容指纹 hash', () {
    test('同输入哈希稳定，且为 16 位十六进制', () async {
      final settings = await freshSettings();
      final a = buildCalendarPlan(timeline: timeline, settings: settings, now: now);
      final b = buildCalendarPlan(timeline: timeline, settings: settings, now: now);
      expect([for (final p in a) p.hash], [for (final p in b) p.hash]);
      expect(a.first.hash, matches(RegExp(r'^[0-9a-f]{1,16}$')));
    });

    test('提前天数变化 → 简报事件哈希改变', () async {
      final settings = await freshSettings();
      final before = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      ).firstWhere((p) => p.key == 'chr:brief:2026-10-01');

      await settings.setAdvanceDays(3);
      final after = buildCalendarPlan(
        timeline: timeline,
        settings: settings,
        now: now,
      ).firstWhere((p) => p.key == 'chr:brief:2026-10-01');
      expect(before.hash, isNot(after.hash));
    });
  });
}
