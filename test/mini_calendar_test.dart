/// 卡片短日历：周数随假期 + 调休跨越的自然周扩展，休/班角标计数。
library;

import 'package:china_holiday_reminder/models/holiday.dart';
import 'package:china_holiday_reminder/ui/widgets/mini_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final timeline = HolidayTimeline.fromDays(loadFixture('2026.json').days);

  HolidaySegment segmentStartingOn(DateTime d) =>
      timeline.segments.firstWhere((s) => s.start == d);

  Future<void> pumpCalendar(
    WidgetTester tester,
    HolidaySegment segment, {
    int firstDayOfWeek = DateTime.monday,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MiniCalendar(
                segment: segment,
                makeups: timeline.makeupsOf(segment),
                today: DateTime(2026, 2, 17),
                firstDayOfWeek: firstDayOfWeek,
              ),
            ),
          ),
        ),
      ),
    );
  }

  final dayCells = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('cal-day-'),
  );

  testWidgets('国庆：调休 9/20 在前、10/10 在后 → 4 周', (tester) async {
    await pumpCalendar(tester, segmentStartingOn(DateTime(2026, 10, 1)));
    expect(dayCells, findsNWidgets(28));
    expect(find.text('休'), findsNWidgets(7));
    expect(find.text('班'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('cal-day-2026-09-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-day-2026-10-11')), findsOneWidget);
  });

  testWidgets('春节：调休 2/14 在前、2/28 在后 → 扩展为 3 周', (tester) async {
    await pumpCalendar(tester, segmentStartingOn(DateTime(2026, 2, 15)));
    expect(dayCells, findsNWidgets(21));
    expect(find.text('休'), findsNWidgets(9));
    expect(find.text('班'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('cal-day-2026-02-09')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-day-2026-03-01')), findsOneWidget);
    expect(find.text('3月'), findsOneWidget);
  });

  testWidgets('中秋：9/25(周五)至9/27(周日)无调休 → 1 周', (tester) async {
    await pumpCalendar(tester, segmentStartingOn(DateTime(2026, 9, 25)));
    expect(dayCells, findsNWidgets(7));
    expect(find.text('休'), findsNWidgets(3));
    expect(find.text('班'), findsNothing);
    expect(find.byKey(const ValueKey('cal-day-2026-09-21')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-day-2026-09-27')), findsOneWidget);
  });

  testWidgets('元旦：跨年 + 1/4(周日)调休 → 1 周', (tester) async {
    await pumpCalendar(tester, segmentStartingOn(DateTime(2026, 1, 1)));
    expect(dayCells, findsNWidgets(7));
    expect(find.text('休'), findsNWidgets(3));
    expect(find.text('班'), findsNWidgets(1));
    expect(find.byKey(const ValueKey('cal-day-2025-12-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('cal-day-2026-01-04')), findsOneWidget);
    expect(find.text('1月'), findsOneWidget);
  });

  testWidgets('周日起始：首列为周日，表头「日」对齐首列', (tester) async {
    await pumpCalendar(
      tester,
      segmentStartingOn(DateTime(2026, 9, 25)),
      firstDayOfWeek: DateTime.sunday,
    );
    // 9/27 为周日（新一周首日），周日起始会把它独立成一周 → 2 周。
    expect(dayCells, findsNWidgets(14));
    final sunday = find.byKey(const ValueKey('cal-day-2026-09-20'));
    final monday = find.byKey(const ValueKey('cal-day-2026-09-21'));
    expect(sunday, findsOneWidget);
    expect(
      tester.getTopLeft(sunday).dx,
      lessThan(tester.getTopLeft(monday).dx),
    );
    expect(
      tester.getCenter(find.text('日')).dx,
      closeTo(tester.getCenter(sunday).dx, 2),
    );
  });
}
