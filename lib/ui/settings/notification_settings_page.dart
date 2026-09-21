/// 设置子页：提醒与通知（节前简报 / 调休提醒的开关与时机 + 系统通知入口）。
library;

import 'package:flutter/material.dart';

import '../../data/app_settings.dart';
import '../../notifications/notification_service.dart';
import '../widgets/common.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({
    required this.settings,
    required this.notifications,
    super.key,
  });

  final AppSettings settings;
  final NotificationService notifications;

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  void _confirm(BuildContext context) => showQuickConfirm(context, '已更新通知安排');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()
            ),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 160.0,
                flexibleSpace: const FlexibleSpaceBar(title: Text('提醒与通知')),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SectionHeader('节前简报'),
                  SettingsGroup(
                    children: [
                      SwitchListTile(
                        title: const Text('节前简报'),
                        subtitle: const Text('法定节假日开始前几天推送放假简报'),
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
                        subtitle: const Text('调休上班日前一天推送上班提醒'),
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
                        onTap: () => _pickTime(context, settings.makeupTime, (
                          time,
                        ) async {
                          await settings.setMakeupTime(time);
                          if (context.mounted) _confirm(context);
                        }),
                      ),
                    ],
                  ),
                  const SectionHeader('系统通知'),
                  SettingsGroup(
                    children: [
                      _SystemNotificationTile(notifications: notifications),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 系统通知开关状态 + 跳转系统设置。
class _SystemNotificationTile extends StatelessWidget {
  const _SystemNotificationTile({required this.notifications});

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
