/// 设置子页：个性化（主题色取色 / 莫奈色板、深色模式）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/app_settings.dart';
import '../../data/monet_colors.dart';
import '../widgets/common.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('个性化')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SectionHeader('主题色'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '系统取色跟随手机壁纸（Material You），莫奈色板取自印象派名画。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _ColorChoice(
                      label: '系统取色',
                      tooltip: '跟随手机壁纸的动态取色',
                      selected: settings.useSystemColors,
                      onTap: () async {
                        await settings.setSeedColor(null);
                        if (context.mounted) showQuickConfirm(context, '主题色已更新');
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
              ),
              const SectionHeader('深色模式'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
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
              ),
            ],
          ),
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
