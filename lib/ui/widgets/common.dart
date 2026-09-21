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

/// MD3 分组设置卡片：大圆角背景，行间细分割线。
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}
