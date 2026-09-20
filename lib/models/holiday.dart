/// 法定节假日数据模型与派生算法（纯 Dart，便于离线单测）。
library;

/// 单条记录，对应 holiday-cn 数据源里 `days` 数组的一项。
class HolidayDay {
  const HolidayDay({
    required this.name,
    required this.date,
    required this.isOffDay,
  });

  factory HolidayDay.fromJson(Map<String, dynamic> json) => HolidayDay(
    name: json['name'] as String,
    date: parseDate(json['date'] as String),
    isOffDay: json['isOffDay'] as bool,
  );

  final String name;
  final DateTime date;
  final bool isOffDay;

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': formatDate(date),
    'isOffDay': isOffDay,
  };
}

/// 一年的原始数据（含公告链接）。
class HolidayYear {
  const HolidayYear({
    required this.year,
    required this.papers,
    required this.days,
  });

  factory HolidayYear.fromJson(Map<String, dynamic> json) => HolidayYear(
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

/// 假期段：把 `isOffDay == true` 的条目按日历连续（且同名）合并。
class HolidaySegment {
  const HolidaySegment({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final DateTime start;
  final DateTime end;

  /// 放假天数（含首尾）。
  int get lengthInDays => daysBetween(start, end) + 1;

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}

/// 调休上班日：`isOffDay == false` 的条目，[segment] 为就近关联到的假期段
/// （优先同名，见 [associateMakeupDays]），可能为 null（窗口内无假期段）。
class MakeupDay {
  const MakeupDay({required this.day, this.segment});

  final HolidayDay day;
  final HolidaySegment? segment;

  String get holidayName => segment?.name ?? day.name;
}

/// 派生时间线：跨年份数据合并后的假期段与调休日集合。
class HolidayTimeline {
  const HolidayTimeline({
    this.segments = const [],
    this.makeups = const [],
    this.years = const [],
    this.papers = const [],
  });

  factory HolidayTimeline.fromDays(List<HolidayDay> days) {
    final segments = groupHolidaySegments(days);
    return HolidayTimeline(
      segments: segments,
      makeups: associateMakeupDays(days, segments),
    );
  }

  final List<HolidaySegment> segments;
  final List<MakeupDay> makeups;
  final List<int> years;
  final List<String> papers;

  /// 归属于某假期段的调休日（按日期升序）。
  List<MakeupDay> makeupsOf(HolidaySegment segment) => makeups
      .where((m) => m.segment != null && _sameSegment(m.segment!, segment))
      .toList()
    ..sort((a, b) => a.day.date.compareTo(b.day.date));

  static bool _sameSegment(HolidaySegment a, HolidaySegment b) =>
      a.name == b.name && a.start == b.start && a.end == b.end;
}

/// 调休关联窗口（天）。2026-09-20（国庆调休）距 10/1 假期段 11 天，
/// 故窗口必须大于 10。
const int kMakeupAssociationWindowInDays = 15;

/// 分组算法：仅当两条放假记录 **日历连续** 且 **同名** 时合并为同一段，
/// 保证 2026 年中秋（9/25–27）与国庆（10/1–7）拆为两段。
List<HolidaySegment> groupHolidaySegments(List<HolidayDay> days) {
  final offDays =
      days.where((d) => d.isOffDay).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final segments = <HolidaySegment>[];
  for (final d in offDays) {
    if (segments.isNotEmpty) {
      final last = segments.last;
      if (last.name == d.name && daysBetween(last.end, d.date) == 1) {
        segments[segments.length - 1] = HolidaySegment(
          name: last.name,
          start: last.start,
          end: d.date,
        );
        continue;
      }
    }
    segments.add(
      HolidaySegment(name: d.name, start: d.date, end: d.date),
    );
  }
  return segments;
}

/// 调休关联：每个调休日在 [kMakeupAssociationWindowInDays] 窗口内挑选假期段，
/// 排序键为 (名称匹配等级, 距离)。名称匹配处理「国庆节、中秋节」这类合并名。
List<MakeupDay> associateMakeupDays(
  List<HolidayDay> days,
  List<HolidaySegment> segments,
) {
  final makeupDays =
      days.where((d) => !d.isOffDay).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final result = <MakeupDay>[];
  for (final m in makeupDays) {
    HolidaySegment? best;
    var bestRank = 3;
    var bestDistance = kMakeupAssociationWindowInDays + 1;
    for (final s in segments) {
      final distance = _distanceToSegment(m.date, s);
      if (distance > kMakeupAssociationWindowInDays) continue;
      final rank = _nameRank(m.name, s.name);
      if (rank < bestRank || (rank == bestRank && distance < bestDistance)) {
        best = s;
        bestRank = rank;
        bestDistance = distance;
      }
    }
    result.add(MakeupDay(day: m, segment: best));
  }
  return result;
}

/// 0 = 名称完全一致；1 = 合并名有交集（「国庆节、中秋节」∩「国庆节」）；2 = 无关。
int _nameRank(String makeupName, String segmentName) {
  if (makeupName == segmentName) return 0;
  final a = makeupName.split('、');
  final b = segmentName.split('、');
  if (a.any(b.contains)) return 1;
  return 2;
}

/// 日期到假期段的天数距离：段内为 0，否则取到最近端点的天数。
int _distanceToSegment(DateTime date, HolidaySegment segment) {
  if (!date.isBefore(segment.start) && !date.isAfter(segment.end)) return 0;
  final before = daysBetween(date, segment.start);
  final after = daysBetween(segment.end, date);
  if (date.isBefore(segment.start)) return before;
  return after;
}

/// 两个日历日之间的天数（忽略时间部分）。
int daysBetween(DateTime from, DateTime to) =>
    DateTime(to.year, to.month, to.day).difference(
      DateTime(from.year, from.month, from.day),
    ).inDays;

/// 剥离时间部分。
DateTime startOfDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2026-09-20" 形式（与数据源一致）。
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// 从 "2026-09-20" 解析为本地日期（零点）。
DateTime parseDate(String s) {
  final parts = s.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
