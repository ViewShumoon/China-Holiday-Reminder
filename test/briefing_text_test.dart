import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:china_holiday_reminder/notifications/briefing_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final t2026 = HolidayTimeline.fromDays(loadFixture('2026.json').days);
  final national = t2026.segments
      .where((s) => s.name == '国庆节')
      .single;
  final nationalMakeups = t2026.makeupsOf(national);
  final midAutumn = t2026.segments
      .where((s) => s.name == '中秋节')
      .single;

  group('节前简报文案', () {
    test('标题：提前 3 天', () {
      expect(briefingTitle(national, 3), '3 天后就是国庆节');
    });

    test('标题：提前 1 / 2 天', () {
      expect(briefingTitle(midAutumn, 1), '明天就是中秋节');
      expect(briefingTitle(midAutumn, 2), '后天就是中秋节');
    });

    test('正文：国庆段 + 两个调休日（设计方案模板）', () {
      expect(
        buildBriefing(national, nationalMakeups, 3),
        '10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班',
      );
    });

    test('正文：无调休的假期段不带分号', () {
      expect(
        buildBriefing(midAutumn, t2026.makeupsOf(midAutumn), 1),
        '9/25(周五)至9/27(周日)放假 3 天',
      );
    });

    test('正文：2025 合并名假期段', () {
      final t2025 = HolidayTimeline.fromDays(loadFixture('2025.json').days);
      final merged = t2025.segments
          .where((s) => s.name == '国庆节、中秋节')
          .single;
      expect(
        buildBriefing(merged, t2025.makeupsOf(merged), 2),
        contains('10/1(周三)至10/8(周三)放假 8 天；'),
      );
    });
  });

  group('调休提醒文案', () {
    test('9/20 的提醒正文', () {
      final m = t2026.makeups
          .firstWhere((x) => formatDate(x.day.date) == '2026-09-20');
      expect(
        makeupBody(m),
        '明天 9/20(周日) 是国庆节调休上班日，别忘了去上班',
      );
    });

    test('标题固定', () {
      expect(makeupTitle(), '调休上班提醒');
    });
  });

  test('weekdayCn 映射正确', () {
    expect(weekdayCn(DateTime(2026, 9, 20)), '周日');
    expect(weekdayCn(DateTime(2026, 9, 21)), '周一');
    expect(weekdayCn(DateTime(2026, 10, 1)), '周四');
  });
}
