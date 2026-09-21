/// 首页（设计 §5.1）：状态条、下一个假期大卡片、未来事件列表、空态。
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_settings.dart';
import '../data/holiday_repository.dart';
import '../models/holiday.dart';
import 'widgets/common.dart';
import 'widgets/status_banner.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.repository,
    required this.settings,
    super.key,
  });

  final HolidayRepository repository;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([repository, settings]),
      builder: (context, _) {
        final today = startOfDate(DateTime.now());
        final timeline = repository.timeline;
        final next = nextSegment(timeline, today);
        final status = todayStatus(timeline, today);
        final upcoming = _upcomingEvents(timeline, today);

        final Widget body;
        body = ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (status != null) StatusBanner(text: status),
            if (next != null)
              _NextHolidayCard(
                segment: next,
                timeline: timeline,
                settings: settings,
                today: today,
              ),
            if (upcoming.isNotEmpty) ...[
              const SectionHeader('未来事件'),
              for (final event in upcoming) event.tile(context),
            ],
            if (next == null && upcoming.isEmpty)
              _EmptyHint(repository: repository, timeline: timeline, today: today),
          ],
        );
        return Scaffold(
          appBar: AppBar(title: const Text('假期提醒')),
          body: RefreshIndicator(
            onRefresh: () => repository.refresh(force: true),
            child: body,
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.repository,
    required this.timeline,
    required this.today,
  });

  final HolidayRepository repository;
  final HolidayTimeline timeline;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final message = !repository.hasData
        ? '暂无放假安排数据\n请下拉刷新或检查网络'
        : '${(timeline.years.isNotEmpty ? timeline.years.last : today.year) + 1} 年放假安排尚未发布';
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// 下一个尚未开始的最近假期段。
HolidaySegment? nextSegment(HolidayTimeline timeline, DateTime today) {
  for (final segment in timeline.segments) {
    if (segment.start.isAfter(today)) return segment;
  }
  return null;
}

class _EventItem {
  const _EventItem({required this.date, required this.tileBuilder});

  final DateTime date;
  final Widget Function(BuildContext) tileBuilder;

  Widget tile(BuildContext context) => tileBuilder(context);
}

List<_EventItem> _upcomingEvents(
  HolidayTimeline timeline,
  DateTime today,
) {
  final items = <_EventItem>[];
  for (final segment in timeline.segments) {
    if (segment.start.isAfter(today)) {
      final makeupCount = timeline.makeupsOf(segment).length;
      items.add(
        _EventItem(
          date: segment.start,
          tileBuilder: (context) => ListTile(
            leading: const Icon(Icons.event),
            title: Text('${segment.name}假期'),
            subtitle: Text(
              '放假 ${segment.lengthInDays} 天'
              '${makeupCount > 0 ? ' · 含调休 $makeupCount 天' : ''}',
            ),
          ),
        ),
      );
    }
  }
  for (final makeup in timeline.makeups) {
    if (makeup.day.date.isAfter(today)) {
      items.add(
        _EventItem(
          date: makeup.day.date,
          tileBuilder: (context) => ListTile(
            leading: const Icon(Icons.work_outline),
            title: Text('调休上班 ${formatDateWeekday(makeup.day.date)}'),
            subtitle: Text('${makeup.holidayName}安排'),
          ),
        ),
      );
    }
  }
  items.sort((a, b) => a.date.compareTo(b.date));
  return items.take(3).toList();
}

class _NextHolidayCard extends StatelessWidget {
  const _NextHolidayCard({
    required this.segment,
    required this.timeline,
    required this.settings,
    required this.today,
  });

  final HolidaySegment segment;
  final HolidayTimeline timeline;
  final AppSettings settings;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countdown = daysBetween(today, segment.start);
    final makeups = timeline.makeupsOf(segment);
    final briefingAt = DateTime(
      segment.start.year,
      segment.start.month,
      segment.start.day - settings.advanceDays,
      settings.briefingTime.hour,
      settings.briefingTime.minute,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    segment.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (countdown <= 0)
                  Text(
                    '进行中',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$countdown',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('天后开始', style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDateWeekday(segment.start)} 至 '
              '${formatDateWeekday(segment.end)} · 放假 ${segment.lengthInDays} 天',
              style: theme.textTheme.bodyMedium,
            ),
            if (makeups.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final makeup in makeups)
                    Chip(
                      avatar: const Icon(Icons.work_outline, size: 18),
                      label: Text(
                        '${monthDay(makeup.day.date)}'
                        '(${weekdayCn(makeup.day.date)})上班',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.notifications_active_outlined, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    settings.briefingEnabled
                        ? '将于 ${DateFormat('M月d日 HH:mm', 'zh_CN').format(briefingAt)} 发送节前简报'
                        : '节前简报已关闭',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
