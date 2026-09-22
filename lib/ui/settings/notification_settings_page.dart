/// 设置子页：提醒与通知（通知方式多选 + 事件内容设置 + 各渠道权限入口）。
library;

import 'package:flutter/material.dart';

import '../../data/app_settings.dart';
import '../../notifications/calendar_service.dart';
import '../../notifications/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_scaffold.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({
    required this.settings,
    required this.notifications,
    required this.calendar,
    super.key,
  });

  final AppSettings settings;
  final NotificationService notifications;
  final CalendarService calendar;

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  void _confirm(BuildContext context) => showQuickConfirm(context, '已更新通知安排');

  /// 日历渠道（优先）：开启即引导授权，未授予也可开启，由权限行补救；
  /// 关闭即时触发 app.dart 重排 → 清空设备上的本应用事件。
  Future<void> _toggleCalendarChannel(
    BuildContext context,
    bool value,
  ) async {
    if (!value) {
      await settings.setChannelCalendar(false);
      if (context.mounted) showQuickConfirm(context, '已关闭日历提醒');
      return;
    }
    if (!calendar.supported) {
      await settings.setChannelCalendar(true);
      if (context.mounted) showQuickConfirm(context, '当前平台暂不支持写入日历');
      return;
    }
    final granted =
        await calendar.hasPermission() || await calendar.requestPermission();
    await settings.setChannelCalendar(true);
    if (context.mounted) {
      showQuickConfirm(
        context,
        granted ? '已启用日历提醒' : '已启用，请在下方授予日历权限',
      );
    }
  }

  /// App 本地通知渠道（备选，默认关）：开启需通知权限，未授予则保持关闭。
  Future<void> _toggleLocalChannel(BuildContext context, bool value) async {
    if (!value) {
      await settings.setChannelLocal(false);
      if (context.mounted) showQuickConfirm(context, '已关闭 App 通知');
      return;
    }
    final granted = await notifications.requestPermission();
    await settings.setChannelLocal(granted);
    if (context.mounted) {
      showQuickConfirm(
        context,
        granted ? '已启用 App 通知' : '未获得通知权限，已保持关闭',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final permissionRows = <Widget>[
          if (settings.channelCalendar) _CalendarPermissionTile(calendar),
          if (settings.channelLocal)
            _NotificationPermissionTile(notifications: notifications),
        ];
        return SettingsPageScaffold(
          title: '提醒与通知',
          children: [
            const SectionHeader('通知方式'),
            SettingsGroup(
              children: [
                CheckboxListTile(
                  title: const Text('系统日历事件（优先）'),
                  subtitle: const Text(
                    '写入系统日历，由日历应用发送提醒，无需本应用后台运行',
                  ),
                  value: settings.channelCalendar,
                  onChanged: (value) =>
                      _toggleCalendarChannel(context, value ?? false),
                ),
                CheckboxListTile(
                  title: const Text('App 本地通知（备选）'),
                  subtitle: const Text(
                    '由本应用排期通知，需要通知权限，默认关闭',
                  ),
                  value: settings.channelLocal,
                  onChanged: (value) =>
                      _toggleLocalChannel(context, value ?? false),
                ),
              ],
            ),
            if (permissionRows.isNotEmpty) ...[
              const SectionHeader('权限与系统设置'),
              SettingsGroup(children: permissionRows),
            ],
            const SectionHeader('节前简报'),
            SettingsGroup(
              children: [
                SwitchListTile(
                  title: const Text('节前简报'),
                  subtitle: const Text('法定节假日开始前几天生成放假简报'),
                  value: settings.briefingEnabled,
                  onChanged: (value) async {
                    await settings.setBriefingEnabled(value);
                    if (context.mounted) _confirm(context);
                  },
                ),
                AnimatedOpacity(
                  opacity: settings.briefingEnabled ? 1 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 1,
                              label: Text('提前 1 天'),
                            ),
                            ButtonSegment(
                              value: 2,
                              label: Text('提前 2 天'),
                            ),
                            ButtonSegment(
                              value: 3,
                              label: Text('提前 3 天'),
                            ),
                          ],
                          selected: {settings.advanceDays},
                          showSelectedIcon: false,
                          onSelectionChanged: settings.briefingEnabled
                              ? (selection) async {
                                  await settings.setAdvanceDays(
                                    selection.first,
                                  );
                                  if (context.mounted) _confirm(context);
                                }
                              : null,
                        ),
                      ),
                      ListTile(
                        title: const Text('发送时刻'),
                        trailing: Text(
                          formatClock(
                            settings.briefingTime,
                            use24: settings.use24Hour,
                          ),
                        ),
                        enabled: settings.briefingEnabled,
                        onTap: () => _pickTime(
                          context,
                          settings.briefingTime,
                          (time) async {
                            await settings.setBriefingTime(time);
                            if (context.mounted) _confirm(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionHeader('调休提醒'),
            SettingsGroup(
              children: [
                SwitchListTile(
                  title: const Text('调休提醒'),
                  subtitle: const Text('调休上班日前一天生成上班提醒'),
                  value: settings.makeupEnabled,
                  onChanged: (value) async {
                    await settings.setMakeupEnabled(value);
                    if (context.mounted) _confirm(context);
                  },
                ),
                ListTile(
                  title: const Text('提醒时刻'),
                  subtitle: const Text('调休上班日的前一天'),
                  trailing: Text(
                    formatClock(
                      settings.makeupTime,
                      use24: settings.use24Hour,
                    ),
                  ),
                  enabled: settings.makeupEnabled,
                  onTap: () => _pickTime(
                    context,
                    settings.makeupTime,
                    (time) async {
                      await settings.setMakeupTime(time);
                      if (context.mounted) _confirm(context);
                    },
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

/// 日历权限状态 + 授权 / 跳转系统设置。
class _CalendarPermissionTile extends StatefulWidget {
  const _CalendarPermissionTile(this.calendar);

  final CalendarService calendar;

  @override
  State<_CalendarPermissionTile> createState() =>
      _CalendarPermissionTileState();
}

class _CalendarPermissionTileState extends State<_CalendarPermissionTile> {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await widget.calendar.hasPermission();
    if (mounted) setState(() => _granted = value);
  }

  @override
  Widget build(BuildContext context) {
    final supported = widget.calendar.supported;
    final subtitle = !supported
        ? '当前平台不支持写入日历'
        : switch (_granted) {
            true => '日历权限已授予',
            false => '未授予日历权限，点击授权',
            _ => '检查日历权限…',
          };
    return ListTile(
      title: const Text('日历权限'),
      subtitle: Text(
        subtitle,
        style: _granted == false && supported
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      onTap: supported
          ? () async {
              final granted = await widget.calendar.requestPermission();
              if (!granted) await widget.calendar.openAppSettings();
              await _refresh();
            }
          : null,
    );
  }
}

/// 通知权限开关状态 + 跳转系统设置（App 本地通知渠道）。
class _NotificationPermissionTile extends StatelessWidget {
  const _NotificationPermissionTile({required this.notifications});

  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: notifications.notificationsEnabled(),
      builder: (context, snapshot) {
        final enabled = snapshot.data;
        final subtitle = switch (enabled) {
          true => '系统通知已开启',
          false => '系统通知已关闭，点击前往开启',
          _ => '点击打开系统通知设置',
        };
        return ListTile(
          title: const Text('通知权限'),
          subtitle: Text(
            subtitle,
            style: enabled == false
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
          onTap: () => notifications.openNotificationSettings(),
        );
      },
    );
  }
}
