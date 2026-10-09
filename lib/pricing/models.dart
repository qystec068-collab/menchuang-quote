/// 门窗计价 · 数据模型
///
/// 口径约定(2026-10-08 与鹏二确认):
/// 1) 价格表(型材 + 附加项 + 类别)**全部由师傅自己在首次设置里填**,不内置死数据;
/// 2) 面积按【洞口尺寸】宽×高 计算(mm 输入);
/// 3) "不足平方"不设死规则,师傅可手动输入计价量覆盖(qtyOverridePerPiece);
/// 4) 一个订单可含多个项目(门 / 窗 / 栏杆 / 扶手 ...),按计价单位分三类:
///    - sqm  按㎡:门窗 —— 需要 宽×高
///    - meter 按延米:栏杆 / 扶手 / 雨棚 —— 需要 长度(填在 widthMm),高度可选仅作记录
///    - piece 按樘/个:纱窗、成品件 —— 只看数量
library;

/// 计价单位
enum PricingUnit { sqm, meter, piece }

String pricingUnitLabel(PricingUnit u) {
  switch (u) {
    case PricingUnit.sqm:
      return '㎡';
    case PricingUnit.meter:
      return 'm';
    case PricingUnit.piece:
      return '樘';
  }
}

String pricingUnitKey(PricingUnit u) {
  switch (u) {
    case PricingUnit.sqm:
      return 'sqm';
    case PricingUnit.meter:
      return 'meter';
    case PricingUnit.piece:
      return 'piece';
  }
}

PricingUnit pricingUnitFrom(String s) {
  switch (s) {
    case 'meter':
      return PricingUnit.meter;
    case 'piece':
      return PricingUnit.piece;
    case 'sqm':
    default:
      return PricingUnit.sqm;
  }
}

/// 附加项计费方式
enum ChargeMode {
  perSqm, // 元/㎡
  perMeter, // 元/m(延米)
  perLeaf, // 元/扇(按开扇数)
  perPiece, // 元/樘(按件数)
  perFloor, // 元/层(整单一次)
  fixed, // 元/单(整单固定)
  percent, // %(作用于前面小计)
}

/// 整单抹零方式(向下抹,零头让给客户)
enum RoundMode { none, jiao, yuan, tenYuan }

String chargeModeLabel(ChargeMode m) {
  switch (m) {
    case ChargeMode.perSqm:
      return '元/㎡';
    case ChargeMode.perMeter:
      return '元/m';
    case ChargeMode.perLeaf:
      return '元/扇';
    case ChargeMode.perPiece:
      return '元/樘';
    case ChargeMode.perFloor:
      return '元/层';
    case ChargeMode.fixed:
      return '元/单';
    case ChargeMode.percent:
      return '%';
  }
}

String chargeModeKey(ChargeMode m) {
  switch (m) {
    case ChargeMode.perSqm:
      return 'perSqm';
    case ChargeMode.perMeter:
      return 'perMeter';
    case ChargeMode.perLeaf:
      return 'perLeaf';
    case ChargeMode.perPiece:
      return 'perPiece';
    case ChargeMode.perFloor:
      return 'perFloor';
    case ChargeMode.fixed:
      return 'fixed';
    case ChargeMode.percent:
      return 'percent';
  }
}

ChargeMode chargeModeFrom(String s) {
  switch (s) {
    case 'perSqm':
      return ChargeMode.perSqm;
    case 'perMeter':
      return ChargeMode.perMeter;
    case 'perLeaf':
      return ChargeMode.perLeaf;
    case 'perPiece':
      return ChargeMode.perPiece;
    case 'perFloor':
      return ChargeMode.perFloor;
    case 'percent':
      return ChargeMode.percent;
    case 'fixed':
    default:
      return ChargeMode.fixed;
  }
}

RoundMode roundModeFrom(String s) {
  switch (s) {
    case 'jiao':
      return RoundMode.jiao;
    case 'yuan':
      return RoundMode.yuan;
    case 'tenYuan':
      return RoundMode.tenYuan;
    case 'none':
    default:
      return RoundMode.none;
  }
}

String roundModeKey(RoundMode m) {
  switch (m) {
    case RoundMode.none:
      return 'none';
    case RoundMode.jiao:
      return 'jiao';
    case RoundMode.yuan:
      return 'yuan';
    case RoundMode.tenYuan:
      return 'tenYuan';
  }
}

String roundModeLabel(RoundMode m) {
  switch (m) {
    case RoundMode.none:
      return '不抹零';
    case RoundMode.jiao:
      return '抹到角';
    case RoundMode.yuan:
      return '抹到元';
    case RoundMode.tenYuan:
      return '抹到十元';
  }
}

double _d(Object? v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _s(Object? v) => v == null ? '' : v.toString();

/// 产品系列(型材 / 栏杆 / 扶手 ...),由师傅自己录入
class Series {
  final String id;
  final String category; // 门 / 窗 / 栏杆 / 扶手 / 雨棚 / 纱窗 / 其他
  final String name;
  final String material; // 断桥铝 / 普通铝合金 / 不锈钢 ...
  final PricingUnit unit;
  final double price; // 元/单位
  final double wallThicknessMm;
  final String glassNote;
  final double minChargeQty; // 单件最小计价量(单位同 unit),0 = 不启用
  final double deductPerSideMm; // 下料缩尺(记录用,计价不使用)

  const Series({
    required this.id,
    this.category = '其他',
    required this.name,
    this.material = '',
    this.unit = PricingUnit.sqm,
    required this.price,
    this.wallThicknessMm = 0,
    this.glassNote = '',
    this.minChargeQty = 0,
    this.deductPerSideMm = 0,
  });

  String get unitLabel => pricingUnitLabel(unit);

  factory Series.fromJson(Map<String, dynamic> j) => Series(
        id: _s(j['id']),
        category: _s(j['category']).isEmpty ? '其他' : _s(j['category']),
        name: _s(j['name']),
        material: _s(j['material']),
        unit: pricingUnitFrom(_s(j['unit'])),
        price: _d(j['price']),
        wallThicknessMm: _d(j['wallThicknessMm']),
        glassNote: _s(j['glassNote']),
        minChargeQty: _d(j['minChargeQty']),
        deductPerSideMm: _d(j['deductPerSideMm']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'material': material,
        'unit': pricingUnitKey(unit),
        'price': price,
        'wallThicknessMm': wallThicknessMm,
        'glassNote': glassNote,
        'minChargeQty': minChargeQty,
        'deductPerSideMm': deductPerSideMm,
      };
}

/// 附加项(安装 / 拆旧 / 运输 / 楼层 / 纱窗 / 五金 / 立柱 ...),由师傅自己录入
class ExtraDef {
  final String id;
  final String name;
  final ChargeMode mode;
  final double price;
  final bool defaultOn;

  const ExtraDef({
    required this.id,
    required this.name,
    required this.mode,
    required this.price,
    this.defaultOn = false,
  });

  factory ExtraDef.fromJson(Map<String, dynamic> j) => ExtraDef(
        id: _s(j['id']),
        name: _s(j['name']),
        mode: chargeModeFrom(_s(j['mode']).isEmpty ? 'fixed' : _s(j['mode'])),
        price: _d(j['price']),
        defaultOn: j['defaultOn'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mode': chargeModeKey(mode),
        'price': price,
        'defaultOn': defaultOn,
      };
}

/// 一个项目的报价输入(订单里的一项)
class QuoteInput {
  final String seriesId;
  final String label; // 项目名,如"阳台推拉门";空则自动用型材名
  final double widthMm; // 门窗=洞口宽;栏杆/扶手=长度
  final double heightMm; // 门窗=洞口高;其他可留 0
  final int count; // 数量(樘/件)
  final int leafCount; // 每件开扇数
  final int floorNo; // 楼层(楼层费)
  final double? qtyOverridePerPiece; // 手动输入计价量(单件)
  final double adjustAmount; // 本项目手动加减
  final List<String> extraIds;
  final Map<String, double> extraQty;

  const QuoteInput({
    required this.seriesId,
    this.label = '',
    required this.widthMm,
    this.heightMm = 0,
    this.count = 1,
    this.leafCount = 0,
    this.floorNo = 1,
    this.qtyOverridePerPiece,
    this.adjustAmount = 0,
    this.extraIds = const [],
    this.extraQty = const {},
  });

  Map<String, dynamic> toJson() => {
        'seriesId': seriesId,
        'label': label,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'count': count,
        'leafCount': leafCount,
        'floorNo': floorNo,
        'qtyOverridePerPiece': qtyOverridePerPiece,
        'adjustAmount': adjustAmount,
        'extraIds': extraIds,
        'extraQty': extraQty,
      };

  factory QuoteInput.fromJson(Map<String, dynamic> j) => QuoteInput(
        seriesId: _s(j['seriesId']),
        label: _s(j['label']),
        widthMm: _d(j['widthMm']),
        heightMm: _d(j['heightMm']),
        count: (j['count'] as num?)?.toInt() ?? 1,
        leafCount: (j['leafCount'] as num?)?.toInt() ?? 0,
        floorNo: (j['floorNo'] as num?)?.toInt() ?? 1,
        qtyOverridePerPiece: j['qtyOverridePerPiece'] == null
            ? null
            : _d(j['qtyOverridePerPiece']),
        adjustAmount: _d(j['adjustAmount']),
        extraIds: ((j['extraIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        extraQty: ((j['extraQty'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(k.toString(), _d(v))),
      );
}

/// 报价明细行
class QuoteLine {
  final String name;
  final double qty;
  final String unit;
  final double unitPrice;
  final double amount;
  final String? note;

  const QuoteLine({
    required this.name,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unit': unit,
        'unitPrice': unitPrice,
        'amount': amount,
        'note': note,
      };
}

/// 一个项目的计算结果
class QuoteResult {
  final String shopName;
  final String currency;
  final String label;
  final String seriesName;
  final PricingUnit unit;
  final List<QuoteLine> lines;
  final double widthMm;
  final double heightMm;
  final double rawQtyPerPiece; // 按尺寸算出的计价量(单件)
  final double qtyPerPiece; // 实际使用的计价量(单件)
  final double qtyTotal; // 合计计价量
  final int count;
  final double subtotal;
  final double adjustAmount;
  final double roundingDelta;
  final double total;
  final bool usedQtyOverride;
  final bool usedMinCharge;

  const QuoteResult({
    required this.shopName,
    required this.currency,
    required this.label,
    required this.seriesName,
    required this.unit,
    required this.lines,
    required this.widthMm,
    required this.heightMm,
    required this.rawQtyPerPiece,
    required this.qtyPerPiece,
    required this.qtyTotal,
    required this.count,
    required this.subtotal,
    required this.adjustAmount,
    required this.roundingDelta,
    required this.total,
    required this.usedQtyOverride,
    required this.usedMinCharge,
  });

  String get unitLabel => pricingUnitLabel(unit);

  /// 项目标题行:如 "阳台推拉门  洞口1.50×1.80m 2樘"
  String get headline {
    final n = label.isEmpty ? seriesName : label;
    switch (unit) {
      case PricingUnit.sqm:
        return '$n  洞口${mm(widthMm)}×${mm(heightMm)}m  $count樘';
      case PricingUnit.meter:
        final h = heightMm > 0 ? '  高${mm(heightMm)}m' : '';
        return '$n  长${mm(widthMm)}m$h  $count件';
      case PricingUnit.piece:
        return '$n  $count件';
    }
  }

  /// 单项目文字报价(可直接发微信)
  String toText() {
    final b = StringBuffer();
    b.writeln('【报价单】$shopName');
    b.writeln(headline);
    b.writeln('------------------------');
    for (final l in lines) {
      final note = l.note == null ? '' : ' (${l.note})';
      b.writeln('${l.name}$note');
      b.writeln('  ${numText(l.qty)}${l.unit} × '
          '${l.unitPrice.toStringAsFixed(2)} = ${l.amount.toStringAsFixed(2)}');
    }
    b.writeln('------------------------');
    b.writeln('小计        ${subtotal.toStringAsFixed(2)}');
    if (adjustAmount != 0) {
      b.writeln('调整        ${adjustAmount > 0 ? '+' : ''}'
          '${adjustAmount.toStringAsFixed(2)}');
    }
    if (roundingDelta != 0) {
      b.writeln('抹零        ${roundingDelta.toStringAsFixed(2)}');
    }
    b.writeln('合计        $currency${total.toStringAsFixed(2)}');
    return b.toString().trimRight();
  }

  static String mm(double v) => (v / 1000.0).toStringAsFixed(2);

  static String numText(double v) {
    if ((v - v.roundToDouble()).abs() < 1e-9) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}
