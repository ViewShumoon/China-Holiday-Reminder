/// 日历渠道平台桥：设备日历读写接口的薄封装（diff/清理逻辑在 CalendarService）。
///
/// Android 实现在应用内自维护（android/app/.../CalendarBridge.kt，
/// 直接走 CalendarContract，静默写入、可回读、可更新/删除），
/// 通道名 'app/calendar_bridge'；其余平台视为不支持。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// 设备上已存在的本应用事件记录（bridge 列表返回）。
class CalendarEventRecord {
  const CalendarEventRecord({
    required this.id,
    required this.key,
    required this.hash,
  });

  final int id;
  final String key;
  final String hash;
}

/// 写入一条日历事件所需参数（bridge 插入入参）。
class CalendarEventDraft {
  const CalendarEventDraft({
    required this.key,
    required this.hash,
    required this.title,
    required this.description,
    required this.startMillis,
    required this.endMillis,
    required this.allDay,
    this.reminderMinutes,
  });

  final String key;
  final String hash;
  final String title;
  final String description;
  final int startMillis;
  final int endMillis;
  final bool allDay;
  final int? reminderMinutes;
}

/// 可注入的日历桥接口（单测用假实现替换）。
abstract class CalendarBridge {
  bool get supported;

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<void> openAppSettings();

  Future<List<CalendarEventRecord>> listEvents(String prefix);

  /// 返回设备侧事件 id；失败返回 null。
  Future<int?> insertEvent(CalendarEventDraft draft);

  Future<void> deleteEvents(List<int> ids);
}

class MethodChannelCalendarBridge implements CalendarBridge {
  const MethodChannelCalendarBridge();

  static const MethodChannel _channel = MethodChannel('app/calendar_bridge');

  @visibleForTesting
  static MethodChannel get channel => _channel;

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');

  @override
  Future<List<CalendarEventRecord>> listEvents(String prefix) async {
    final rows = await _channel.invokeMethod<List<Object?>>(
      'listEvents',
      {'prefix': prefix},
    );
    return [
      for (final row in rows ?? const <Object?>[])
        CalendarEventRecord(
          id: (row as Map<Object?, Object?>)['id']! as int,
          key: row['key']! as String,
          hash: row['hash'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<int?> insertEvent(CalendarEventDraft draft) =>
      _channel.invokeMethod<int>('insertEvent', {
        'key': draft.key,
        'hash': draft.hash,
        'title': draft.title,
        'description': draft.description,
        'startMillis': draft.startMillis,
        'endMillis': draft.endMillis,
        'allDay': draft.allDay,
        'reminderMinutes': draft.reminderMinutes,
      });

  @override
  Future<void> deleteEvents(List<int> ids) =>
      _channel.invokeMethod<void>('deleteEvents', {'ids': ids});
}
