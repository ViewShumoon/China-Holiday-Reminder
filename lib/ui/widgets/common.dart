/// UI 通用格式化与小部件。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../notifications/briefing_text.dart' show weekdayCn;

export '../../notifications/briefing_text.dart' show monthDay, weekdayCn;

/// "09:00"（24 小时制）或 "上午9:00"（12 小时制）形式。
String formatClock(TimeOfDay time, {bool use24 = true}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24) {
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final period = time.hour < 12 ? '上午' : '下午';
  final hour = time.hour % 12;
  return '$period${hour == 0 ? 12 : hour}:$minute';
}

/// 设置变更后的一行式即时反馈。
void showQuickConfirm(BuildContext context, [String message = '已更新']) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
}

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
      padding: const EdgeInsets.fromLTRB(28, 24, 16, 10),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

