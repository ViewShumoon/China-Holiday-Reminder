/// 莫奈名画启发主题色板（种子色），供个性化页选择。
library;

import 'dart:ui' show Color;

class MonetColor {
  const MonetColor({
    required this.name,
    required this.painting,
    required this.color,
  });

  /// 色名（界面展示）。
  final String name;

  /// 出处画作（提示文案）。
  final String painting;

  /// 种子色。
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is MonetColor && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);
}

abstract final class MonetColors {
  static const List<MonetColor> palette = [
    MonetColor(
      name: '日出印象',
      painting: '《印象·日出》',
      color: Color(0xFFE2725B),
    ),
    MonetColor(
      name: '睡莲池',
      painting: '《睡莲》',
      color: Color(0xFF5F8D7A),
    ),
    MonetColor(
      name: '紫藤桥',
      painting: '《日本桥》',
      color: Color(0xFF8A6FB0),
    ),
    MonetColor(
      name: '干草堆',
      painting: '《干草堆》',
      color: Color(0xFFC79A45),
    ),
    MonetColor(
      name: '伦敦雾',
      painting: '《国会大厦》',
      color: Color(0xFF5C7A9E),
    ),
    MonetColor(
      name: '吉维尼玫瑰',
      painting: '《玫瑰小径》',
      color: Color(0xFFC4627E),
    ),
    MonetColor(
      name: '阿让特伊',
      painting: '《阿让特伊的帆船》',
      color: Color(0xFF4A6FA5),
    ),
  ];

  /// 按种子色查色板项；不在色板内返回 null。
  static MonetColor? find(Color color) =>
      palette.where((e) => e.color == color).firstOrNull;
}
