/// 设置主页：原生 Android 风格的入口列表，点击进入各子页。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_settings.dart';
import '../data/holiday_repository.dart';
import '../data/monet_colors.dart';
import '../notifications/notification_service.dart';
import 'settings/about_settings_page.dart';
import 'settings/appearance_settings_page.dart';
import 'settings/data_settings_page.dart';
import 'settings/notification_settings_page.dart';
import 'widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.repository,
    required this.settings,
    required this.notifications,
    super.key,
  });

  final HolidayRepository repository;
  final AppSettings settings;
  final NotificationService notifications;

  String _reminderSummary() {
    final parts = <String>[];
    if (settings.briefingEnabled) {
      parts.add(
        '简报提前 ${settings.advanceDays} 天 ${formatClock(settings.briefingTime)}',
      );
    }
    if (settings.makeupEnabled) {
      parts.add('调休 ${formatClock(settings.makeupTime)}');
    }
    return parts.isEmpty ? '全部提醒已关闭' : parts.join(' · ');
  }

  String get _appearanceSummary {
    final seed = settings.useSystemColors
        ? '系统取色'
        : MonetColors.find(settings.seedColor!)?.name ?? '莫奈色';
    final mode = switch (settings.themeMode) {
      ThemeMode.system => '跟随系统',
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
    };
    return '$seed · $mode';
  }

  String get _dataSummary {
    if (repository.lastCheck == null) return '从未更新';
    return '更新于 ${DateFormat('yyyy-MM-dd HH:mm').format(repository.lastCheck!)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repository, settings]),
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _SettingsEntry(
              icon: Icons.notifications_active_outlined,
              background: scheme.primaryContainer,
              foreground: scheme.onPrimaryContainer,
              title: '提醒与通知',
              subtitle: _reminderSummary(),
              page: NotificationSettingsPage(
                settings: settings,
                notifications: notifications,
              ),
            ),
            _SettingsEntry(
              icon: Icons.palette_outlined,
              background: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              title: '个性化',
              subtitle: _appearanceSummary,
              page: AppearanceSettingsPage(settings: settings),
            ),
            _SettingsEntry(
              icon: Icons.storage_outlined,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
              title: '数据',
              subtitle: _dataSummary,
              page: DataSettingsPage(repository: repository),
            ),
            _SettingsEntry(
              icon: Icons.info_outline,
              background: scheme.errorContainer,
              foreground: scheme.onErrorContainer,
              title: '关于',
              subtitle: '应用简介 · 数据来源 · 开源许可',
              page: const AboutSettingsPage(),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, color: foreground),
      ),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        );
      },
    );
  }
}
