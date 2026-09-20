import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final y2025 = loadFixture('2025.json');
  final y2026 = loadFixture('2026.json');
  final t2026 = HolidayTimeline.fromDays(y2026.days);

  MakeupDay makeupOn(HolidayTimeline t, String date) =>
      t.makeups.firstWhere((m) => formatDate(m.day.date) == date);

  group('associateMakeupDays（2026 真实数据）', () {
    test('9/20 距国庆节段 11 天，仍正确关联到国庆节', () {
      final m = makeupOn(t2026, '2026-09-20');
      expect(m.segment, isNotNull);
      expect(m.segment!.name, '国庆节');
      expect(m.segment!.start, DateTime(2026, 10, 1));
    });

    test('10/10 关联到国庆节', () {
      expect(makeupOn(t2026, '2026-10-10').segment!.name, '国庆节');
    });

    test('9/20 虽距中秋段（9/25）更近，但按名称优先归属国庆', () {
      final midAutumn = t2026.segments
          .where((s) => s.name == '中秋节')
          .single;
      expect(
        daysBetween(parseDate('2026-09-20'), midAutumn.start),
        lessThan(11),
      );
      expect(makeupOn(t2026, '2026-09-20').holidayName, '国庆节');
    });

    test('春节调休 2/14、2/28 均关联春节段', () {
      expect(makeupOn(t2026, '2026-02-14').segment!.name, '春节');
      expect(makeupOn(t2026, '2026-02-28').segment!.name, '春节');
    });

    test('元旦调休 1/4、劳动节调休 5/9 正确关联', () {
      expect(makeupOn(t2026, '2026-01-04').segment!.name, '元旦');
      expect(makeupOn(t2026, '2026-05-09').segment!.name, '劳动节');
    });

    test('端午节无调休', () {
      expect(t2026.makeups.where((m) => m.segment?.name == '端午节'), isEmpty);
    });

    test('makeupsOf(国庆节) 恰好为 9/20 与 10/10，按日期升序', () {
      final national = t2026.segments
          .where((s) => s.name == '国庆节')
          .single;
      final list = t2026.makeupsOf(national);
      expect(
        list.map((m) => formatDate(m.day.date)),
        ['2026-09-20', '2026-10-10'],
      );
    });
  });

  group('associateMakeupDays（2025 真实数据）', () {
    test('合并名调休「国庆节、中秋节」关联到合并假期段', () {
      final t2025 = HolidayTimeline.fromDays(y2025.days);
      final merged = t2025.segments
          .where((s) => s.name == '国庆节、中秋节')
          .single;
      final list = t2025.makeupsOf(merged).toList();
      expect(
        list.map((m) => formatDate(m.day.date)),
        containsAll(['2025-09-28', '2025-10-11']),
      );
    });
  });

  group('associateMakeupDays（构造用例）', () {
    test('窗口内无任何假期段时 segment 为 null', () {
      final timeline = HolidayTimeline.fromDays([
        day('2027-01-01', '元旦', true),
        day('2027-06-01', '某节', false),
      ]);
      final far = timeline.makeups
          .firstWhere((m) => formatDate(m.day.date) == '2027-06-01');
      expect(far.segment, isNull);
    });

    test('窗口内仅有名称无关的段时，就近关联该段', () {
      final timeline = HolidayTimeline.fromDays([
        day('2027-05-01', '劳动节', true),
        day('2027-05-02', '劳动节', true),
        day('2027-05-03', '某节', false),
        day('2027-05-10', '劳动节', false),
      ]);
      final unrelated = timeline.makeups
          .firstWhere((m) => formatDate(m.day.date) == '2027-05-03');
      expect(unrelated.segment!.name, '劳动节');
      final sameName = timeline.makeups
          .firstWhere((m) => formatDate(m.day.date) == '2027-05-10');
      expect(sameName.segment!.name, '劳动节');
    });
  });
}

HolidayDay day(String date, String name, bool isOffDay) => HolidayDay(
  name: name,
  date: parseDate(date),
  isOffDay: isOffDay,
);
