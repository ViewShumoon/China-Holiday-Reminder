/// 设置主页与子页的渲染冒烟测试。
library;

import 'package:china_holiday_reminder/data/app_settings.dart';
import 'package:china_holiday_reminder/data/holiday_repository.dart';
import 'package:china_holiday_reminder/notifications/notification_service.dart';
import 'package:china_holiday_reminder/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsPage> _page() async {
  SharedPreferences.setMockInitialValues({});
  return SettingsPage(
    repository: await HolidayRepository.load(),
    settings: await AppSettings.load(),
    notifications: NotificationService(),
  );
}

void main() {
  testWidgets('设置主页：大标题 + 四个入口', (tester) async {
    await tester.pumpWidget(MaterialApp(home: await _page()));
    await tester.pump();
    // 大标题折叠栏：展开/收起两份标题。
    expect(find.text('设置'), findsNWidgets(2));
    for (final title in ['提醒与通知', '个性化', '数据', '关于']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('进入个性化子页并切换主题色', (tester) async {
    await tester.pumpWidget(MaterialApp(home: await _page()));
    await tester.pump();
    await tester.tap(find.text('个性化'));
    await tester.pumpAndSettle();
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('深色模式'), findsOneWidget);

    await tester.tap(find.text('伦敦雾'));
    await tester.pumpAndSettle();
    expect(find.text('主题色已更新'), findsOneWidget);

    // 向下滚动到懒加载的「一周的开始 / 时间格式」分组。
    await tester.scrollUntilVisible(find.text('时间格式'), 300);
    expect(find.text('一周的开始'), findsOneWidget);
    expect(find.text('时间格式'), findsOneWidget);
  });

  testWidgets('个性化：切换一周开始与时间格式并持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(
        repository: await HolidayRepository.load(),
        settings: settings,
        notifications: NotificationService(),
      )),
    );
    await tester.pump();
    await tester.tap(find.text('个性化'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('周六'), 200);
    await tester.tap(find.text('周六'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('12 小时制'), 200);
    await tester.tap(find.text('12 小时制'));
    await tester.pumpAndSettle();

    expect(settings.firstDayOfWeek, DateTime.saturday);
    expect(settings.use24Hour, isFalse);

    final restored = await AppSettings.load();
    expect(restored.firstDayOfWeek, DateTime.saturday);
    expect(restored.use24Hour, isFalse);
  });

  testWidgets('进入数据子页可看到来源与刷新', (tester) async {
    await tester.pumpWidget(MaterialApp(home: await _page()));
    await tester.pump();
    await tester.tap(find.text('数据'));
    await tester.pumpAndSettle();
    expect(find.text('NateScarlet/holiday-cn'), findsOneWidget);
    expect(find.text('立即刷新'), findsOneWidget);
  });
}
