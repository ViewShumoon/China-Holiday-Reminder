/// CalendarService diff 同步测试（假桥，离线）。
library;

import 'package:china_holiday_reminder/notifications/calendar_bridge.dart';
import 'package:china_holiday_reminder/notifications/calendar_plan.dart';
import 'package:china_holiday_reminder/notifications/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_calendar_bridge.dart';

CalendarEventPlan planItem(String key, {String title = 't'}) =>
    CalendarEventPlan(
      key: key,
      title: title,
      description: 'd',
      start: DateTime(2026, 10, 1, 9),
      end: DateTime(2026, 10, 1, 9, 30),
      allDay: false,
      reminderMinutes: 0,
    );

void main() {
  late FakeCalendarBridge bridge;
  late CalendarService service;

  setUp(() {
    bridge = FakeCalendarBridge();
    service = CalendarService(bridge: bridge);
  });

  test('首次同步全量插入', () async {
    final result = await service.sync([planItem('chr:a'), planItem('chr:b')]);
    expect(result.status, CalendarSyncStatus.ok);
    expect(result.inserted, 2);
    expect(result.updated, 0);
    expect(result.deleted, 0);
    expect(bridge.byKey.length, 2);
  });

  test('重复同步无变化 → 零操作', () async {
    final plan = [planItem('chr:a'), planItem('chr:b')];
    await service.sync(plan);
    final result = await service.sync(plan);
    expect(result.inserted, 0);
    expect(result.updated, 0);
    expect(result.deleted, 0);
    expect(bridge.inserted.length, 2);
  });

  test('哈希变化 → 删除重建并计数为 updated', () async {
    await service.sync([planItem('chr:a')]);
    final oldId = bridge.byKey['chr:a']!.id;

    final result = await service.sync([planItem('chr:a', title: 'new')]);
    expect(result.updated, 1);
    expect(result.deleted, 0);
    expect(bridge.byKey['chr:a']!.id, isNot(oldId));
    expect(bridge.byKey['chr:a']!.hash, isNot(bridge.inserted.first.hash));
  });

  test('计划外的旧事件被清理', () async {
    await service.sync([planItem('chr:a'), planItem('chr:gone')]);
    final result = await service.sync([planItem('chr:a')]);
    expect(result.deleted, 1);
    expect(bridge.byKey.keys, ['chr:a']);
  });

  test('空计划 = 全量清理（关闭渠道时调用）', () async {
    await service.sync([planItem('chr:a'), planItem('chr:b')]);
    final result = await service.sync(const []);
    expect(result.deleted, 2);
    expect(bridge.byKey, isEmpty);
    expect(result.ok, isTrue);
  });

  test('无权限 → permissionDenied 且不写设备', () async {
    bridge.granted = false;
    final result = await service.sync([planItem('chr:a')]);
    expect(result.status, CalendarSyncStatus.permissionDenied);
    expect(bridge.byKey, isEmpty);
  });

  test('平台不支持 → unsupported', () async {
    bridge.supported = false;
    final result = await service.sync([planItem('chr:a')]);
    expect(result.status, CalendarSyncStatus.unsupported);
    expect(bridge.byKey, isEmpty);
  });

  test('非本应用前缀的设备事件绝不触碰', () async {
    bridge.byKey['user:manual'] = const CalendarEventRecord(
      id: 1,
      key: 'user:manual',
      hash: '',
    );
    final result = await service.sync([planItem('chr:a')]);
    expect(result.deleted, 0);
    expect(bridge.byKey.containsKey('user:manual'), isTrue);
  });
}
