/// 设置页（设计 §5.2）：任一项变更后即时重排通知，并以 SnackBar 确认。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_settings.dart';
import '../data/holiday_repository.dart';
import 'widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.repository,
    required this.settings,
    super.key,
  });

  final HolidayRepository repository;
  final AppSettings settings;

  void _confirm(BuildContext context, [String message = '已更新通知安排']) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      );
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repository, settings]),
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SectionHeader('节前简报'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('提前 1 天')),
                        ButtonSegment(value: 2, label: Text('提前 2 天')),
                        ButtonSegment(value: 3, label: Text('提前 3 天')),
                      ],
                      selected: {settings.advanceDays},
                      showSelectedIcon: false,
                      onSelectionChanged: settings.briefingEnabled
                          ? (selection) async {
                              await settings.setAdvanceDays(selection.first);
                              if (context.mounted) _confirm(context);
                            }
                          : null,
                    ),
                  ),
                  ListTile(
                    title: const Text('发送时刻'),
                    trailing: Text(formatClock(settings.briefingTime)),
                    enabled: settings.briefingEnabled,
                    onTap: () => _pickTime(context, settings.briefingTime, (
                      time
                    ) async {
                      await settings.setBriefingTime(time);
                      if (context.mounted) _confirm(context);
                    }),
                  ),
                ],
              ),
            ),
            const SectionHeader('调休提醒'),
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
              trailing: Text(formatClock(settings.makeupTime)),
              enabled: settings.makeupEnabled,
              onTap: () => _pickTime(context, settings.makeupTime, (time) async {
                await settings.setMakeupTime(time);
                if (context.mounted) _confirm(context);
              }),
            ),
            const SectionHeader('数据'),
            ListTile(
              title: Text(
                repository.loadedYears.isEmpty
                    ? '尚无数据'
                    : '已加载 ${repository.loadedYears.join('、')} 年安排',
              ),
              subtitle: Text(
                repository.lastCheck == null
                    ? '从未更新'
                    : '更新于 ${DateFormat('yyyy-MM-dd HH:mm').format(repository.lastCheck!)}',
              ),
            ),
            ListTile(
              leading: repository.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: const Text('立即刷新'),
              subtitle: repository.lastError == null
                  ? null
                  : Text(
                      repository.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              enabled: !repository.busy,
              onTap: () async {
                await repository.refresh(force: true);
                if (context.mounted) {
                  _confirm(context, repository.lastError ?? '数据已更新');
                }
              },
            ),
            for (final url in repository.timeline.papers)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('国务院公告原文'),
                subtitle: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  try {
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  } on Object {
                    if (context.mounted) _confirm(context, '无法打开链接');
                  }
                },
              ),
          ],
        );
      },
    );
  }
}
