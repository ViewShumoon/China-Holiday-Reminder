/// 通知文案纯函数（便于完整单测）。
library;

import '../models/holiday.dart';

/// 节前简报标题，如「3 天后就是国庆节」。
String briefingTitle(HolidaySegment segment, int advanceDays) {
  final lead = switch (advanceDays) {
    1 => '明天',
    2 => '后天',
    _ => '$advanceDays 天后',
  };
  return '$lead就是${segment.name}';
}

/// 节前简报正文，如
/// 「10/1(周四)至10/7(周三)放假 7 天；9/20(周日)、10/10(周六)需上班」。
String buildBriefing(
  HolidaySegment segment,
  List<MakeupDay> makeups,
  int advanceDays,
) {
  final buffer = StringBuffer()
    ..write(
      '${monthDay(segment.start)}(${weekdayCn(segment.start)})'
      '至${monthDay(segment.end)}(${weekdayCn(segment.end)})'
      '放假 ${segment.lengthInDays} 天',
    );
  if (makeups.isNotEmpty) {
    buffer
      ..write('；')
      ..write(
        makeups
            .map((m) => '${monthDay(m.day.date)}(${weekdayCn(m.day.date)})')
            .join('、'),
      )
      ..write('需上班');
  }
  return buffer.toString();
}

/// 调休提醒标题。
String makeupTitle() => '调休上班提醒';

/// 调休提醒正文，如「明天 9/20(周日) 是国庆节调休上班日，别忘了去上班」。
String makeupBody(MakeupDay makeup) =>
    '明天 ${monthDay(makeup.day.date)}(${weekdayCn(makeup.day.date)}) '
    '是${makeup.holidayName}调休上班日，别忘了去上班';

/// "10/1" 形式。
String monthDay(DateTime date) => '${date.month}/${date.day}';

/// "周四" 形式（DateTime.weekday: 1=周一 … 7=周日）。
String weekdayCn(DateTime date) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
