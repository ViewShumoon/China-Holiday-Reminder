/// 设置子页：个性化（主题色取色 / 莫奈色板、深色模式）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/app_settings.dart';
import '../../data/monet_colors.dart';
import '../widgets/common.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_scaffold.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        return SettingsPageScaffold(
          title: '个性化',
          children: [
            const SectionHeader('时间日期格式'),
            SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('一周的开始', style: theme.textTheme.titleMedium),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: DateTime.monday,
                              label: Text('周一'),
                            ),
                            ButtonSegment(
                              value: DateTime.tuesday,
                              label: Text('周二'),
                            ),
                            ButtonSegment(
                              value: DateTime.wednesday,
                              label: Text('周三'),
                            ),
                            ButtonSegment(
                              value: DateTime.thursday,
                              label: Text('周四'),
                            ),
                            ButtonSegment(
                              value: DateTime.friday,
                              label: Text('周五'),
                            ),
                            ButtonSegment(
                              value: DateTime.saturday,
                              label: Text('周六'),
                            ),
                            ButtonSegment(
                              value: DateTime.sunday,
                              label: Text('周日'),
                            ),
                          ],
                          selected: {settings.firstDayOfWeek},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) async {
                            await settings.setFirstDayOfWeek(
                              selection.first,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('时间格式', style: theme.textTheme.titleMedium),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('12 小时制'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('24 小时制'),
                          ),
                        ],
                        selected: {settings.use24Hour},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) async {
                          await settings.setUse24Hour(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SectionHeader('外观'),
            SettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text(
                      //   '系统取色跟随手机壁纸（Material You），莫奈色板取自印象派名画。',
                      //   style: theme.textTheme.bodyMedium?.copyWith(
                      //     color: theme.colorScheme.outline,
                      //   ),
                      // ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 16,
                        children: [
                          _ColorChoice(
                            label: '系统取色',
                            tooltip: '跟随手机壁纸的动态取色',
                            selected: settings.useSystemColors,
                            onTap: () async {
                              await settings.setSeedColor(null);
                              if (context.mounted) {
                                showQuickConfirm(context, '主题色已更新');
                              }
                            },
                            swatch: const _SystemColorsSwatch(),
                          ),
                          for (final monet in MonetColors.palette)
                            _ColorChoice(
                              label: monet.name,
                              tooltip: monet.painting,
                              selected: settings.seedColor == monet.color,
                              onTap: () async {
                                await settings.setSeedColor(monet.color);
                                if (context.mounted) {
                                  showQuickConfirm(context, '主题色已更新');
                                }
                              },
                              swatch: ColoredBox(color: monet.color),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('深色模式', style: theme.textTheme.titleMedium),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('跟随系统'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('浅色'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('深色'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) async {
                          await settings.setThemeMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.swatch,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Widget swatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              width: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(child: swatch),
                      if (selected)
                        Icon(
                          Icons.check,
                          size: 22,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 3),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Tooltip(
              message: tooltip,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 系统取色选项的彩虹渐变幻觉圆点。
class _SystemColorsSwatch extends StatelessWidget {
  const _SystemColorsSwatch();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          transform: GradientRotation(math.pi / 4),
          colors: [
            Color(0xFFF2B8B5),
            Color(0xFFFFD081),
            Color(0xFF8CD790),
            Color(0xFF8EC4E6),
            Color(0xFFB99FFA),
            Color(0xFFF2B8B5),
          ],
        ),
      ),
    );
  }
}
