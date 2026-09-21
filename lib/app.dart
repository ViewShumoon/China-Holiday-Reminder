/// MaterialApp / 主题 / NavigationBar，并接线四类重排时机。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'data/app_settings.dart';
import 'data/holiday_repository.dart';
import 'notifications/notification_service.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';

class ChinaHolidayApp extends StatefulWidget {
  const ChinaHolidayApp({
    required this.settings,
    required this.repository,
    required this.notifications,
    super.key,
  });

  final AppSettings settings;
  final HolidayRepository repository;
  final NotificationService notifications;

  @override
  State<ChinaHolidayApp> createState() => _ChinaHolidayAppState();
}

class _ChinaHolidayAppState extends State<ChinaHolidayApp>
    with WidgetsBindingObserver {
  /// 系统取色不可用平台上的回退种子色。
  static const _fallbackSeed = Color(0xFFBA1A1A);

  int _index = 0;
  bool _ready = false;
  bool _rescheduling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_reschedule);
    widget.repository.addListener(_reschedule);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_reschedule);
    widget.repository.removeListener(_reschedule);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await widget.notifications.initialize();
    await widget.notifications.requestPermission();
    await widget.repository.refresh();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.repository.refresh());
    }
  }

  /// 数据变更 / 设置变更 / 刷新完成 → cancelAll + 窗口内重新排期。
  void _reschedule() {
    if (!_ready || _rescheduling) return;
    _rescheduling = true;
    unawaited(
      Future(() async {
        try {
          final events = buildSchedule(
            timeline: widget.repository.timeline,
            settings: widget.settings,
            now: DateTime.now(),
          );
          await widget.notifications.reschedule(events);
        } finally {
          _rescheduling = false;
        }
      }),
    );
  }

  ThemeData _theme(AppSettings settings, Brightness brightness) {
    if (settings.useSystemColors) {
      // 主题色 = 系统取色，平台不支持时由回退种子色派生。
      return ThemeData(
        useSystemColors: true,
        colorSchemeSeed: _fallbackSeed,
        brightness: brightness,
      );
    }
    // 主题色 = 莫奈色板种子色，关闭系统取色覆盖。
    return ThemeData(
      useSystemColors: false,
      colorSchemeSeed: settings.seedColor,
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final settings = widget.settings;
        return MaterialApp(
          title: '假期提醒',
          debugShowCheckedModeBanner: false,
          theme: _theme(settings, Brightness.light),
          darkTheme: _theme(settings, Brightness.dark),
          themeMode: settings.themeMode,
          home: _Shell(
            index: _index,
            onDestinationChanged: (value) => setState(() => _index = value),
            child: IndexedStack(
              index: _index,
              children: [
                HomePage(
                  repository: widget.repository,
                  settings: widget.settings,
                ),
                SettingsPage(
                  repository: widget.repository,
                  settings: widget.settings,
                  notifications: widget.notifications,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.index,
    required this.onDestinationChanged,
    required this.child,
  });

  final int index;
  final ValueChanged<int> onDestinationChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onDestinationChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
