import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final y2025 = loadFixture('2025.json');
  final y2026 = loadFixture('2026.json');
  final t2026 = HolidayTimeline.fromDays(y2026.days);

  group('groupHolidaySegments（2026 真实数据）', () {
    test('元旦合并为 1/1–1/3 一段', () {
      final newYear = t2026.segments
          .where((s) => s.name == '元旦')
          .toList();
      expect(newYear, hasLength(1));
      expect(newYear.single.start, DateTime(2026, 1, 1));
      expect(newYear.single.end, DateTime(2026, 1, 3));
      expect(newYear.single.lengthInDays, 3);
    });

    test('春节合并为 2/15–2/23 共 9 天', () {
      final spring = t2026.segments.where((s) => s.name == '春节').single;
      expect(spring.start, DateTime(2026, 2, 15));
      expect(spring.end, DateTime(2026, 2, 23));
      expect(spring.lengthInDays, 9);
    });

    test('中秋与国庆之间隔着工作日，必须拆为两段', () {
      final midAutumn = t2026.segments
          .where((s) => s.name == '中秋节')
          .single;
      final national = t2026.segments
          .where((s) => s.name == '国庆节')
          .single;
      expect(midAutumn.start, DateTime(2026, 9, 25));
      expect(midAutumn.end, DateTime(2026, 9, 27));
      expect(midAutumn.lengthInDays, 3);
      expect(national.start, DateTime(2026, 10, 1));
      expect(national.end, DateTime(2026, 10, 7));
      expect(national.lengthInDays, 7);
    });

    test('段数与顺序正确（按日期升序）', () {
      expect(
        t2026.segments.map((s) => '${s.name}${s.start.month}-${s.start.day}'),
        [
          '元旦1-1',
          '春节2-15',
          '清明节4-4',
          '劳动节5-1',
          '端午节6-19',
          '中秋节9-25',
          '国庆节10-1',
        ],
      );
    });
  });

  group('groupHolidaySegments（2025 真实数据）', () {
    test('合并名「国庆节、中秋节」原样保留为一段', () {
      final t2025 = HolidayTimeline.fromDays(y2025.days);
      final merged = t2025.segments
          .where((s) => s.name.contains('、'))
          .toList();
      expect(merged, hasLength(1));
      expect(merged.single.name, '国庆节、中秋节');
      expect(merged.single.start, DateTime(2025, 10, 1));
      expect(merged.single.end, DateTime(2025, 10, 8));
      expect(merged.single.lengthInDays, 8);
    });
  });

  group('groupHolidaySegments（构造用例）', () {
    test('不同名即使日历连续也不合并', () {
      final segments = groupHolidaySegments([
        day('2026-12-31', '元旦', true),
        day('2027-01-01', '元旦', true),
        day('2027-01-02', '其他节', true),
      ]);
      expect(segments, hasLength(2));
      expect(segments.first.lengthInDays, 2);
    });

    test('跨年数据合并后元旦段可跨越年份', () {
      final timeline = HolidayTimeline.fromDays(mergedDays([y2026]));
      expect(timeline.segments.first.start, DateTime(2026, 1, 1));
    });
  });
}

HolidayDay day(String date, String name, bool isOffDay) => HolidayDay(
  name: name,
  date: parseDate(date),
  isOffDay: isOffDay,
);
