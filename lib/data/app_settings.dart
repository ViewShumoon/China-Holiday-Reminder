/// 应用设置（SharedPreferences 封装，变更后即时通知重排）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs);

  static const _briefingOnKey = 'settings_briefing_enabled';
  static const _advanceDaysKey = 'settings_advance_days';
  static const _briefingTimeKey = 'settings_briefing_time';
  static const _makeupOnKey = 'settings_makeup_enabled';
  static const _makeupTimeKey = 'settings_makeup_time';

  /// 通知滚动窗口：未来 45 天（iOS 有 64 条待触发通知上限）。
  static const scheduleWindow = Duration(days: 45);
  static const allowedAdvanceDays = [1, 2, 3];

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

  bool get briefingEnabled => _briefingEnabled;
  int get advanceDays => _advanceDays;
  TimeOfDay get briefingTime => _briefingTime;
  bool get makeupEnabled => _makeupEnabled;
  TimeOfDay get makeupTime => _makeupTime;

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
