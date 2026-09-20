/// 「今天」状态条（设计 §5.1-1）。
library;

import 'package:flutter/material.dart';

import '../../models/holiday.dart';

/// 今天相关的状态文案；不相关时返回 null。
String? todayStatus(HolidayTimeline timeline, DateTime today) {
  final day = startOfDate(today);
  for (final segment in timeline.segments) {
    if (!day.isBefore(segment.start) && !day.isAfter(segment.end)) {
      final remaining = daysBetween(day, segment.end) + 1;
      return '${segment.name}假期进行中，还剩 $remaining 天';
    }
    if (daysBetween(segment.end, day) == 1) {
      final hasMore = timeline.makeups.any((m) => m.day.date == day);
      if (!hasMore) return '假期结束，明天恢复上班';
    }
  }
  if (timeline.makeups.any((m) => m.day.date == day)) return '今天是调休上班日';
  return null;
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.today, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
