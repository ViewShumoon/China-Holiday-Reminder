/// 应用设置（SharedPreferences 封装，变更后即时通知重排）。
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode, TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

import 'monet_colors.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  static const _channelCalendarKey = 'settings_channel_calendar';
  static const _channelLocalKey = 'settings_channel_local';
  static const _briefingOnKey = 'settings_briefing_enabled';
  static const _advanceDaysKey = 'settings_advance_days';
  static const _briefingTimeKey = 'settings_briefing_time';
  static const _makeupOnKey = 'settings_makeup_enabled';
  static const _makeupTimeKey = 'settings_makeup_time';
  static const _themeModeKey = 'settings_theme_mode';
  static const _seedColorKey = 'settings_seed_color';
  static const _firstDayOfWeekKey = 'settings_first_day_of_week';
  static const _use24HourKey = 'settings_use_24h';

  /// 通知滚动窗口：未来 45 天，足以覆盖最近 1 个假期段及其全部调休日。
  static const scheduleWindow = Duration(days: 45);
  static const allowedAdvanceDays = [1, 2, 3];

  /// 一周起始日合法取值（对应 DateTime.weekday：1=周一 … 7=周日）。
  static const allowedFirstDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    await settings.restore();
    return settings;
  }

  bool _briefingEnabled = true;
  int _advanceDays = 1;
  TimeOfDay _briefingTime = const TimeOfDay(hour: 9, minute: 0);
  bool _makeupEnabled = true;
  TimeOfDay _makeupTime = const TimeOfDay(hour: 20, minute: 0);
  ThemeMode _themeMode = ThemeMode.system;
  int _firstDayOfWeek = DateTime.monday;
  bool _use24Hour = true;

  /// 通知渠道（多选、互相独立）：系统日历（优先，默认开）与 App 本地通知（备选，默认关）。
  bool _channelCalendar = true;
  bool _channelLocal = false;

  /// null → 系统取色（Material You）；非 null → 色板种子色。
  Color? _seedColor;

  bool get briefingEnabled => _briefingEnabled;
  int get advanceDays => _advanceDays;
  TimeOfDay get briefingTime => _briefingTime;
  bool get makeupEnabled => _makeupEnabled;
  TimeOfDay get makeupTime => _makeupTime;
  ThemeMode get themeMode => _themeMode;
  Color? get seedColor => _seedColor;
  bool get useSystemColors => _seedColor == null;
  int get firstDayOfWeek => _firstDayOfWeek;
  bool get use24Hour => _use24Hour;
  bool get channelCalendar => _channelCalendar;
  bool get channelLocal => _channelLocal;

  /// 是否任一通知渠道处于启用状态。
  bool get hasAnyChannel => _channelCalendar || _channelLocal;

  /// 从 SharedPreferences 恢复设置。
  Future<void> restore() async {
    _briefingEnabled = _prefs.getBool(_briefingOnKey) ?? true;
    _advanceDays = _prefs.getInt(_advanceDaysKey) ?? 1;
    if (!allowedAdvanceDays.contains(_advanceDays)) _advanceDays = 1;
    _briefingTime = _readTime(_briefingTimeKey) ??
        const TimeOfDay(hour: 9, minute: 0);
    _makeupEnabled = _prefs.getBool(_makeupOnKey) ?? true;
    _makeupTime = _readTime(_makeupTimeKey) ??
        const TimeOfDay(hour: 20, minute: 0);
    _themeMode = switch (_prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final seed = _prefs.getInt(_seedColorKey);
    // 仅接受仍在色板内的持久化种子色，否则回退系统取色。
    _seedColor = seed == null ? null : MonetColors.find(Color(seed))?.color;
    _firstDayOfWeek = _prefs.getInt(_firstDayOfWeekKey) ?? DateTime.monday;
    if (!allowedFirstDays.contains(_firstDayOfWeek)) {
      _firstDayOfWeek = DateTime.monday;
    }
    _use24Hour = _prefs.getBool(_use24HourKey) ?? true;
    _channelCalendar = _prefs.getBool(_channelCalendarKey) ?? true;
    _channelLocal = _prefs.getBool(_channelLocalKey) ?? false;
    notifyListeners();
  }

  Future<void> setBriefingEnabled(bool value) async {
    _briefingEnabled = value;
    await _prefs.setBool(_briefingOnKey, value);
    notifyListeners();
  }

  Future<void> setAdvanceDays(int value) async {
    assert(allowedAdvanceDays.contains(value));
    _advanceDays = value;
    await _prefs.setInt(_advanceDaysKey, value);
    notifyListeners();
  }

  Future<void> setBriefingTime(TimeOfDay value) async {
    _briefingTime = value;
    await _prefs.setString(_briefingTimeKey, _writeTime(value));
    notifyListeners();
  }

  Future<void> setMakeupEnabled(bool value) async {
    _makeupEnabled = value;
    await _prefs.setBool(_makeupOnKey, value);
    notifyListeners();
  }

  Future<void> setMakeupTime(TimeOfDay value) async {
    _makeupTime = value;
    await _prefs.setString(_makeupTimeKey, _writeTime(value));
    notifyListeners();
  }

  Future<void> setChannelCalendar(bool value) async {
    _channelCalendar = value;
    await _prefs.setBool(_channelCalendarKey, value);
    notifyListeners();
  }

  Future<void> setChannelLocal(bool value) async {
    _channelLocal = value;
    await _prefs.setBool(_channelLocalKey, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _prefs.setString(_themeModeKey, value.name);
    notifyListeners();
  }

  /// [color] 为 null 时回到系统取色。
  Future<void> setSeedColor(Color? color) async {
    assert(color == null || MonetColors.find(color) != null);
    _seedColor = color;
    if (color == null) {
      await _prefs.remove(_seedColorKey);
    } else {
      await _prefs.setInt(_seedColorKey, color.toARGB32());
    }
    notifyListeners();
  }

  Future<void> setFirstDayOfWeek(int value) async {
    assert(allowedFirstDays.contains(value));
    _firstDayOfWeek = value;
    await _prefs.setInt(_firstDayOfWeekKey, value);
    notifyListeners();
  }

  Future<void> setUse24Hour(bool value) async {
    _use24Hour = value;
    await _prefs.setBool(_use24HourKey, value);
    notifyListeners();
  }

  TimeOfDay? _readTime(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _writeTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}
