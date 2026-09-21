/// MD3 Expressive 分组设置卡片（基于 m3e_segmented_list）。
library;

import 'package:flutter/material.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';

/// 将设置行组合为 M3 Expressive 分段列表：
/// 首尾行外角大圆角、相邻行间内角小圆角并带细间隙，
/// 行背景为 [ColorScheme.surfaceContainerHigh]。
/// 子项需自带内边距（容器内 padding 置零）。
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3ESegmentedColumn(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: scheme.surfaceContainerHigh,
      padding: EdgeInsets.zero,
      outerRadius: 28,
      innerRadius: 8,
      gap: 2,
      // 用透明 Material 承接子项（ListTile 等）的水波纹，
      // 避免其绘制到分段 DecoratedBox 之下。
      children: [
        for (final child in children)
          Material(type: MaterialType.transparency, child: child),
      ],
    );
  }
}
