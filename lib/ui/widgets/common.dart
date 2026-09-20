/// UI 通用格式化与小部件。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../notifications/briefing_text.dart' show weekdayCn;

export '../../notifications/briefing_text.dart' show monthDay, weekdayCn;

/// "09:00" 形式。
String formatClock(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// "10月1日" 形式（依赖 main 中的 initializeDateFormatting）。
String formatMonthDay(DateTime date) =>
    DateFormat('M月d日', 'zh_CN').format(date);

/// "10月1日(周四)" 形式。
String formatDateWeekday(DateTime date) =>
    '${formatMonthDay(date)}(${weekdayCn(date)})';

/// 设置分组标题。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
