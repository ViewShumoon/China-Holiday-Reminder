import 'package:china_holiday_reminder/notifications/calendar_bridge.dart';

/// 内存版日历桥：以 key → 记录 的映射模拟设备日历（离线单测用）。
class FakeCalendarBridge implements CalendarBridge {
  FakeCalendarBridge({this.supported = true, this.granted = true});

  @override
  bool supported;

  bool granted;

  final Map<String, CalendarEventRecord> byKey = {};
  final List<CalendarEventDraft> inserted = [];
  int openAppSettingsCalls = 0;

  int _nextId = 100;

  @override
  Future<List<CalendarEventRecord>> listEvents(String prefix) async => [
    for (final record in byKey.values)
      if (record.key.startsWith(prefix)) record,
  ];

  @override
  Future<int?> insertEvent(CalendarEventDraft draft) async {
    inserted.add(draft);
    byKey[draft.key] = CalendarEventRecord(
      id: _nextId++,
      key: draft.key,
      hash: draft.hash,
    );
    return byKey[draft.key]!.id;
  }

  @override
  Future<void> deleteEvents(List<int> ids) async {
    final doomed = ids.toSet();
    byKey.removeWhere((_, record) => doomed.contains(record.id));
  }

  @override
  Future<bool> hasPermission() async => supported && granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;
}
