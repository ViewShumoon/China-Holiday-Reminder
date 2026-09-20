import 'dart:convert';
import 'dart:io';

import 'package:china_holiday_reminder/models/holiday.dart';

/// 读取 assets/fixtures 下的真实数据样本（离线）。
HolidayYear loadFixture(String fileName) {
  final raw = File('assets/fixtures/$fileName').readAsStringSync();
  return HolidayYear.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// 合并多个年份的原始记录并按时间排序。
List<HolidayDay> mergedDays(List<HolidayYear> years) =>
    [for (final y in years) ...y.days]..sort((a, b) => a.date.compareTo(b.date));
