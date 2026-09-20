/// 节假日数据仓库：网络获取（主/备源）、SharedPreferences 缓存、派生时间线。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/holiday.dart';

/// 数据源：NateScarlet/holiday-cn（国务院公告结构化数据）。
class HolidayDataSource {
  const HolidayDataSource._();

  static const primaryTemplate =
      'https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/{year}.json';
  static const fallbackTemplate =
      'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{year}.json';

  static List<String> urlsFor(int year) => [
    primaryTemplate.replaceAll('{year}', '$year'),
    fallbackTemplate.replaceAll('{year}', '$year'),
  ];
}

/// 缓存里一年的数据（原始 JSON 可直接复用解析）。
class CachedYear {
  const CachedYear({required this.year, required this.papers, required this.days});

  factory CachedYear.fromJson(Map<String, dynamic> json) => CachedYear(
    year: json['year'] as int,
    papers: (json['papers'] as List<dynamic>? ?? []).cast<String>(),
    days: (json['days'] as List<dynamic>? ?? [])
        .map((e) => HolidayDay.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final int year;
  final List<String> papers;
  final List<HolidayDay> days;
}

class HolidayRepository extends ChangeNotifier {
  HolidayRepository(
    this._prefs, {
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const _cacheKeyPrefix = 'holiday_cn_';
  static const _lastCheckKey = 'holiday_cn_last_check';

  final SharedPreferences _prefs;
  final http.Client _client;
  final DateTime Function() _clock;

  final Map<int, List<HolidayDay>> _daysByYear = {};
  final Map<int, List<String>> _papersByYear = {};
  HolidayTimeline _timeline = const HolidayTimeline();
  DateTime? _lastCheck;
  String? _lastError;
  bool _busy = false;

  HolidayTimeline get timeline => _timeline;
  DateTime? get lastCheck => _lastCheck;
  String? get lastError => _lastError;
  bool get busy => _busy;
  List<int> get loadedYears => _daysByYear.keys.toList()..sort();
  bool get hasData => _daysByYear.isNotEmpty;

  static Future<HolidayRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = HolidayRepository(prefs);
    await repo._restoreCache();
    return repo;
  }

  /// 离线启动：先恢复缓存。
  Future<void> _restoreCache() async {
    _lastCheck = DateTime.tryParse(_prefs.getString(_lastCheckKey) ?? '');
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_cacheKeyPrefix) || key == _lastCheckKey) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        _ingest(jsonDecode(raw) as Map<String, dynamic>);
      } on Object {
        await _prefs.remove(key);
      }
    }
    _rebuildTimeline();
  }

  /// 刷新策略（设计 §3.2）：每天最多一次；11 月起顺带拉取下一年。
  /// [force] 手动刷新可突破每日限制。
  Future<void> refresh({bool force = false}) async {
    final now = _clock();
    if (_busy) return;
    if (!force && _lastCheck != null && _isSameDay(_lastCheck!, now)) return;
    _busy = true;
    _lastError = null;
    notifyListeners();

    final targets = <int>{
      now.year,
      if (now.month >= 11) now.year + 1,
      ..._daysByYear.keys.where((y) => y > now.year),
    };
    var failed = false;
    for (final year in targets) {
      if (!await _fetchYear(year)) failed = true;
    }
    if (failed) _lastError = '数据更新失败，当前展示缓存数据';
    _lastCheck = now;
    await _prefs.setString(_lastCheckKey, now.toIso8601String());
    _rebuildTimeline();
    _busy = false;
    notifyListeners();
  }

  Future<bool> _fetchYear(int year) async {
    for (final url in HolidayDataSource.urlsFor(year)) {
      try {
        final response = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is! Map<String, dynamic>) continue;
        _ingest(json);
        await _prefs.setString('$_cacheKeyPrefix$year', jsonEncode(json));
        return true;
      } on Object {
        continue; // 主地址超时/异常 → 切换备地址
      }
    }
    return false;
  }

  void _ingest(Map<String, dynamic> json) {
    final year = CachedYear.fromJson(json);
    _daysByYear[year.year] = year.days;
    _papersByYear[year.year] = year.papers;
  }

  void _rebuildTimeline() {
    final years = loadedYears;
    final days = [for (final y in years) ...?_daysByYear[y]];
    final segments = groupHolidaySegments(days);
    _timeline = HolidayTimeline(
      segments: segments,
      makeups: associateMakeupDays(days, segments),
      years: years,
      papers: [for (final y in years) ...?_papersByYear[y]],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
