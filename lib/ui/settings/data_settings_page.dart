/// 设置子页：数据（holiday-cn 来源、更新状态、手动刷新、公告原文）。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/holiday_repository.dart';
import '../widgets/common.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_scaffold.dart';

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({required this.repository, super.key});

  final HolidayRepository repository;

  static const _repoUrl = 'https://github.com/NateScarlet/holiday-cn';

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object {
      if (context.mounted) showQuickConfirm(context, '无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        return SettingsPageScaffold(
          title: '数据',
          children: [
            const SectionHeader('数据来源'),
            SettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('NateScarlet/holiday-cn'),
                  subtitle: const Text('国务院公告结构化数据，点击项目主页'),
                  onTap: () => _openUrl(context, _repoUrl),
                ),
              ],
            ),
            const SectionHeader('更新状态'),
            SettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    repository.loadedYears.isEmpty
                        ? '尚无数据'
                        : '已加载 ${repository.loadedYears.join('、')} 年安排',
                  ),
                  subtitle: Text(
                    repository.lastCheck == null
                        ? '从未更新'
                        : '上次更新 ${DateFormat('yyyy-MM-dd HH:mm').format(repository.lastCheck!)}',
                  ),
                ),
                ListTile(
                  leading: repository.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync),
                  title: const Text('立即刷新'),
                  subtitle: Text(
                    repository.lastError ?? '每天启动 / 回前台时自动检查一次，也可手动刷新',
                    style: repository.lastError == null
                        ? null
                        : TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                  ),
                  enabled: !repository.busy,
                  onTap: () async {
                    await repository.refresh(force: true);
                    if (context.mounted) {
                      showQuickConfirm(
                        context,
                        repository.lastError ?? '数据已更新',
                      );
                    }
                  },
                ),
              ],
            ),
            if (repository.timeline.papers.isNotEmpty) ...[
              const SectionHeader('国务院公告原文'),
              SettingsGroup(
                children: [
                  for (final url in repository.timeline.papers)
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(
                        url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      onTap: () => _openUrl(context, url),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
