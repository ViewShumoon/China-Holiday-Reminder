/// 设置子页：关于（应用信息、数据来源、开源许可）。
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';

class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key});

  static const _dataRepoUrl = 'https://github.com/NateScarlet/holiday-cn';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final version = snapshot.data?.version ?? '';
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.emoji_events,
                        size: 36,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('假期提醒', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      version.isEmpty ? '版本获取中…' : '版本 $version',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader('应用'),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('简介'),
                subtitle: const Text(
                  '法定节假日前推送放假简报，调休上班日前一天推送提醒。\n'
                  '本地优先：无后端、无账号、无广告，通知离线可排。',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('数据来源'),
                subtitle: const Text(
                  'NateScarlet/holiday-cn（国务院公告结构化数据）',
                ),
                onTap: () async {
                  try {
                    await launchUrl(
                      Uri.parse(_dataRepoUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  } on Object {
                    if (context.mounted) showQuickConfirm(context, '无法打开链接');
                  }
                },
              ),
              const SectionHeader('法律与许可'),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('开源许可'),
                subtitle: const Text('查看 Flutter 框架、插件与依赖包的开源许可证'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LicensePage(
                        applicationName: '假期提醒',
                        applicationVersion: version,
                        applicationLegalese:
                            '本地优先的节假日提醒工具 · 数据来自 NateScarlet/holiday-cn',
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
