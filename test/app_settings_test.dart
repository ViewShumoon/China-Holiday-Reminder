/// AppSettings 外观项（主题模式 / 主题色）持久化与恢复。
library;

import 'package:china_holiday_reminder/data/app_settings.dart';
import 'package:china_holiday_reminder/data/monet_colors.dart';
import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('默认：系统取色 + 跟随系统', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.useSystemColors, isTrue);
    expect(settings.seedColor, isNull);
    expect(settings.themeMode, ThemeMode.system);
  });

  test('莫奈种子色跨实例持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppSettings.load();
    await first.setSeedColor(MonetColors.palette.last.color);
    await first.setThemeMode(ThemeMode.dark);

    final restored = await AppSettings.load();
    expect(restored.useSystemColors, isFalse);
    expect(restored.seedColor, MonetColors.palette.last.color);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('不在色板内的种子色回退系统取色', () async {
    SharedPreferences.setMockInitialValues({
      'settings_seed_color': const Color(0xFF010203).toARGB32(),
    });
    final settings = await AppSettings.load();
    expect(settings.useSystemColors, isTrue);
  });

  test('setSeedColor(null) 回到系统取色', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await settings.setSeedColor(MonetColors.palette.first.color);
    await settings.setSeedColor(null);

    final restored = await AppSettings.load();
    expect(restored.useSystemColors, isTrue);
  });

  test('默认：周一为一周开始 + 24 小时制', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.firstDayOfWeek, DateTime.monday);
    expect(settings.use24Hour, isTrue);
  });

  test('一周开始 / 时间格式跨实例持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppSettings.load();
    await first.setFirstDayOfWeek(DateTime.sunday);
    await first.setUse24Hour(false);

    final restored = await AppSettings.load();
    expect(restored.firstDayOfWeek, DateTime.sunday);
    expect(restored.use24Hour, isFalse);
  });

  test('非法的一周开始值回退周一', () async {
    SharedPreferences.setMockInitialValues({
      'settings_first_day_of_week': 99,
    });
    final settings = await AppSettings.load();
    expect(settings.firstDayOfWeek, DateTime.monday);
  });
}
