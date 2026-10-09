/// 价格表:师傅自己维护的一套数据(类别 + 型材 + 附加项 + 抹零规则)。
/// 纯数据,不依赖 Flutter/IO,方便单测与以后的"设置页编辑 + 导入导出"。
library;

import 'dart:convert';

import 'models.dart';

class PriceTable {
  final String shopName;
  final String shopPhone;
  final String currency;
  final RoundMode roundTotal;
  final List<String> categories; // 项目类别:门 / 窗 / 栏杆 / 扶手 ...
  final List<Series> series;
  final List<ExtraDef> extras;

  const PriceTable({
    this.shopName = '',
    this.shopPhone = '',
    this.currency = '¥',
    this.roundTotal = RoundMode.yuan,
    this.categories = defaultCategories,
    this.series = const [],
    this.extras = const [],
  });

  /// 首次设置的默认类别(师傅可增删)
  static const List<String> defaultCategories = [
    '门',
    '窗',
    '栏杆',
    '扶手',
    '雨棚',
    '纱窗',
    '其他',
  ];

  /// 全新(未设置)的价格表 —— 软件首次打开就用它进设置页
  factory PriceTable.blank() => const PriceTable();

  /// 设置是否填完:有店名且有至少一种型材
  bool get isReady => shopName.trim().isNotEmpty && series.isNotEmpty;

  Series? seriesById(String id) {
    for (final s in series) {
      if (s.id == id) return s;
    }
    return null;
  }

  ExtraDef? extraById(String id) {
    for (final e in extras) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 某个类别下的型材
  List<Series> seriesIn(String category) =>
      series.where((s) => s.category == category).toList();

  /// 类别列表(priceTable 里出现过的类别也会补进来)
  List<String> get allCategories {
    final out = <String>[...categories];
    for (final s in series) {
      if (!out.contains(s.category)) out.add(s.category);
    }
    return out;
  }

  PriceTable copyWith({
    String? shopName,
    String? shopPhone,
    String? currency,
    RoundMode? roundTotal,
    List<String>? categories,
    List<Series>? series,
    List<ExtraDef>? extras,
  }) =>
      PriceTable(
        shopName: shopName ?? this.shopName,
        shopPhone: shopPhone ?? this.shopPhone,
        currency: currency ?? this.currency,
        roundTotal: roundTotal ?? this.roundTotal,
        categories: categories ?? this.categories,
        series: series ?? this.series,
        extras: extras ?? this.extras,
      );

  factory PriceTable.fromJson(Map<String, dynamic> j) => PriceTable(
        shopName: (j['shopName'] ?? '').toString(),
        shopPhone: (j['shopPhone'] ?? '').toString(),
        currency: (j['currency'] ?? '¥').toString(),
        roundTotal: roundModeFrom((j['roundTotal'] ?? 'yuan').toString()),
        categories: ((j['categories'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        series: ((j['series'] as List?) ?? const [])
            .map((e) => Series.fromJson(e as Map<String, dynamic>))
            .toList(),
        extras: ((j['extras'] as List?) ?? const [])
            .map((e) => ExtraDef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'shopName': shopName,
        'shopPhone': shopPhone,
        'currency': currency,
        'roundTotal': roundModeKey(roundTotal),
        'categories': categories,
        'series': series.map((e) => e.toJson()).toList(),
        'extras': extras.map((e) => e.toJson()).toList(),
      };

  static PriceTable fromJsonString(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    final t = PriceTable.fromJson(map);
    // 老数据里没有 categories 时补默认值
    if (t.categories.isEmpty) {
      return t.copyWith(categories: defaultCategories);
    }
    return t;
  }

  String toJsonString({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());
}
