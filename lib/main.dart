/// 入口：时区初始化、依赖装配。
library;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_settings.dart';
import 'data/holiday_repository.dart';
import 'notifications/calendar_service.dart';
import 'notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  final settings = await AppSettings.load();
  final repository = await HolidayRepository.load();

  runApp(
    ChinaHolidayApp(
      settings: settings,
      repository: repository,
      notifications: NotificationService(),
      calendar: CalendarService(),
    ),
  );
}
