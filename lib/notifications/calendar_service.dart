/// 日历渠道服务：权限转发 + 幂等 diff 同步（增 / 改 / 删）。
library;

import 'calendar_bridge.dart';
import 'calendar_plan.dart';

enum CalendarSyncStatus { ok, permissionDenied, unsupported }

class CalendarSyncResult {
  const CalendarSyncResult({
    required this.status,
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
    this.failed = 0,
  });

  final CalendarSyncStatus status;

  /// 新增条数。
  final int inserted;

  /// 内容/时间变化 → 删除重建的条数。
  final int updated;

  /// 计划外（窗口滚出 / 开关关闭）被清理的条数。
  final int deleted;

  /// 写入失败的条数（如设备上无可写日历）。
  final int failed;

  bool get ok => status == CalendarSyncStatus.ok && failed == 0;
}

class CalendarService {
  CalendarService({CalendarBridge? bridge})
    : _bridge = bridge ?? const MethodChannelCalendarBridge();

  final CalendarBridge _bridge;

  bool get supported => _bridge.supported;

  Future<bool> hasPermission() => _bridge.hasPermission();

  /// 引导系统授权，返回是否已授予。
  Future<bool> requestPermission() => _bridge.requestPermission();

  /// 跳转系统应用设置页（权限被永久拒绝时的兜底入口）。
  Future<void> openAppSettings() => _bridge.openAppSettings();

  /// 使设备日历中的本应用事件与 [plan] 一致（空计划 = 全量清理）。
  /// 未支持 / 无权限时静默跳过，待权限授予后的下一次重排自然补上。
  Future<CalendarSyncResult> sync(List<CalendarEventPlan> plan) async {
    if (!_bridge.supported) {
      return const CalendarSyncResult(status: CalendarSyncStatus.unsupported);
    }
    if (!await _bridge.hasPermission()) {
      return const CalendarSyncResult(
        status: CalendarSyncStatus.permissionDenied,
      );
    }

    final existing = {
      for (final record in await _bridge.listEvents(calendarKeyPrefix))
        record.key: record,
    };
    final wanted = {for (final item in plan) item.key: item};

    final staleIds = <int>[];
    final toInsert = <CalendarEventDraft>[];
    var inserted = 0;
    var updated = 0;
    for (final entry in wanted.entries) {
      final old = existing.remove(entry.key);
      if (old != null && old.hash == entry.value.hash) continue; // 一致，跳过。
      if (old != null) {
        staleIds.add(old.id);
        updated++;
      } else {
        inserted++;
      }
      toInsert.add(_draftOf(entry.value));
    }
    final deleted = existing.length;
    staleIds.addAll(existing.values.map((record) => record.id));

    if (staleIds.isNotEmpty) await _bridge.deleteEvents(staleIds);
    var failed = 0;
    for (final draft in toInsert) {
      final insertedId = await _tryInsert(draft);
      if (insertedId == null) failed++;
    }
    return CalendarSyncResult(
      status: CalendarSyncStatus.ok,
      inserted: inserted,
      updated: updated,
      deleted: deleted,
      failed: failed,
    );
  }

  /// 单条写入失败（如设备无可写日历）记为 failed，不阻断其余同步。
  Future<int?> _tryInsert(CalendarEventDraft draft) async {
    try {
      return await _bridge.insertEvent(draft);
    } on Object {
      return null;
    }
  }

  static CalendarEventDraft _draftOf(CalendarEventPlan plan) =>
      CalendarEventDraft(
        key: plan.key,
        hash: plan.hash,
        title: plan.title,
        description: plan.description,
        startMillis: plan.start.millisecondsSinceEpoch,
        endMillis: plan.end.millisecondsSinceEpoch,
        allDay: plan.allDay,
        reminderMinutes: plan.reminderMinutes,
      );
}
