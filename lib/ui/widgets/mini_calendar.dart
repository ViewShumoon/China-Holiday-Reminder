/// 卡片内短日历：每行 7 天（周一起始），行数 = 假期与调休跨越的自然周数；
/// 每格右上角以「休」（放假）/「班」（调休上班）标记。
library;

import 'package:flutter/material.dart';

import '../../models/holiday.dart';

class MiniCalendar extends StatelessWidget {
  const MiniCalendar({
    required this.segment,
    required this.makeups,
    required this.today,
    this.firstDayOfWeek = DateTime.monday,
    super.key,
  });

  final HolidaySegment segment;
  final List<MakeupDay> makeups;
  final DateTime today;

  /// 一周起始日（DateTime.weekday：1=周一 … 7=周日）。
  final int firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 一周首日 firstDayOfWeek，则末日为其后第 6 天（1..7 循环）。
    final lastDayOfWeek = (firstDayOfWeek + 5) % 7 + 1;
    final makeupDates = {for (final m in makeups) m.day.date};
    final bounds = <DateTime>[segment.start, segment.end, ...makeupDates];
    final first = bounds.reduce((a, b) => a.isBefore(b) ? a : b);
    final last = bounds.reduce((a, b) => a.isAfter(b) ? a : b);
    final gridStart = first.subtract(
      Duration(days: (first.weekday - firstDayOfWeek + 7) % 7),
    );
    final gridEnd = last.add(
      Duration(days: (lastDayOfWeek - last.weekday + 7) % 7),
    );
    final weekCount = (daysBetween(gridStart, gridEnd) + 1) ~/ 7;

    Widget cell(DateTime date) {
      final isRest = segment.contains(date);
      final isWork = !isRest && makeupDates.contains(date);
      final isWeekend = date.weekday > DateTime.friday;
      final isToday = daysBetween(date, today) == 0;

      final background = isRest
          ? scheme.errorContainer
          : isWork
          ? scheme.tertiaryContainer
          : null;
      final numberColor = isRest
          ? scheme.onErrorContainer
          : isWork
          ? scheme.onTertiaryContainer
          : isWeekend
          ? scheme.error
          : scheme.onSurface;

      return Expanded(
        child: Padding(
          key: ValueKey('cal-day-${formatDate(date)}'),
          padding: const EdgeInsets.all(1.5),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: isToday ? Border.all(color: scheme.primary) : null,
            ),
            child: Stack(
              children: [
                if (date.day == 1)
                  Positioned(
                    left: 3,
                    top: 1,
                    child: Text(
                      '${date.month}月',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ),
                if (isRest || isWork)
                  Positioned(
                    right: 3,
                    top: 1,
                    child: Text(
                      isRest ? '休' : '班',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: numberColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: numberColor,
                        fontWeight: isToday ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayLabels[(firstDayOfWeek - 1 + i) % 7],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        for (var w = 0; w < weekCount; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                cell(gridStart.add(Duration(days: w * 7 + d))),
            ],
          ),
      ],
    );
  }
}
