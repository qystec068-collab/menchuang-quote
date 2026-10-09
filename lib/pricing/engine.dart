/// 计价引擎(纯逻辑,无 IO / 无 UI)。
///
/// 顺序:型材 → 非比例附加项 → 比例附加项(按小计) → 手动调整 → 抹零。
/// 所有明细金额都四舍五入到分。
/// 订单里各项目计算时传 roundMode: RoundMode.none,抹零只在整单做一次。
library;

import 'models.dart';
import 'money.dart';
import 'price_table.dart';

class PricingEngine {
  final PriceTable table;

  PricingEngine(this.table);

  QuoteResult quote(QuoteInput input, {RoundMode? roundMode}) {
    final series = table.seriesById(input.seriesId);
    if (series == null) {
      throw ArgumentError('未知型材: ${input.seriesId}');
    }
    final count = input.count <= 0 ? 1 : input.count;

    // ---- 计价量:按单位取 面积 / 长度 / 件数 ----
    double rawQty;
    switch (series.unit) {
      case PricingUnit.sqm:
        rawQty = round2(input.widthMm * input.heightMm / 1000000.0);
        break;
      case PricingUnit.meter:
        rawQty = round2(input.widthMm / 1000.0);
        break;
      case PricingUnit.piece:
        rawQty = 1.0;
        break;
    }
    var qty = input.qtyOverridePerPiece != null
        ? round2(input.qtyOverridePerPiece!)
        : rawQty;
    final usedOverride = input.qtyOverridePerPiece != null;
    var usedMin = false;
    if (series.minChargeQty > 0 && qty < series.minChargeQty) {
      qty = series.minChargeQty;
      usedMin = true;
    }
    final qtyTotal = round2(qty * count);

    final lines = <QuoteLine>[];

    // ---- 1) 型材 ----
    lines.add(QuoteLine(
      name: series.name,
      qty: qtyTotal,
      unit: series.unitLabel,
      unitPrice: series.price,
      amount: round2(qtyTotal * series.price),
      note: usedOverride
          ? '计价量手动输入 ${qty.toStringAsFixed(2)}${series.unitLabel}'
          : (usedMin
              ? '按最小计价量 ${series.minChargeQty.toStringAsFixed(2)}${series.unitLabel}'
              : null),
    ));

    // 附加项可能按 ㎡ / m 计,这里同时准备两种基础量
    final areaTotal = round2(input.widthMm * input.heightMm / 1000000.0 * count);
    final lenTotal = round2(input.widthMm / 1000.0 * count);

    // ---- 2) 非比例附加项 ----
    double sum = lines.first.amount;
    final percentExtras = <ExtraDef>[];
    for (final id in input.extraIds) {
      final def = table.extraById(id);
      if (def == null) continue;
      if (def.mode == ChargeMode.percent) {
        percentExtras.add(def);
        continue;
      }
      double qty2;
      String unit2;
      switch (def.mode) {
        case ChargeMode.perSqm:
          qty2 = areaTotal;
          unit2 = '㎡';
          break;
        case ChargeMode.perMeter:
          qty2 = lenTotal;
          unit2 = 'm';
          break;
        case ChargeMode.perLeaf:
          qty2 = (input.leafCount * count).toDouble();
          unit2 = '扇';
          break;
        case ChargeMode.perPiece:
          qty2 = input.extraQty[id] ?? count.toDouble();
          unit2 = '樘';
          break;
        case ChargeMode.perFloor:
          qty2 = input.floorNo <= 0 ? 1.0 : input.floorNo.toDouble();
          unit2 = '层';
          break;
        case ChargeMode.fixed:
          qty2 = 1;
          unit2 = '单';
          break;
        case ChargeMode.percent:
          qty2 = 0;
          unit2 = '';
          break;
      }
      if (qty2 == 0) continue;
      final amount = round2(qty2 * def.price);
      lines.add(QuoteLine(
        name: def.name,
        qty: qty2,
        unit: unit2,
        unitPrice: def.price,
        amount: amount,
      ));
      sum += amount;
    }
    sum = round2(sum);

    // ---- 3) 比例附加项 ----
    for (final def in percentExtras) {
      final amount = round2(sum * def.price / 100.0);
      lines.add(QuoteLine(
        name: def.name,
        qty: def.price,
        unit: '%',
        unitPrice: sum,
        amount: amount,
        note: '按小计 ${sum.toStringAsFixed(2)} 计',
      ));
      sum = round2(sum + amount);
    }

    // ---- 4) 手动调整 + 5) 抹零 ----
    final subtotal = sum;
    final beforeRound = round2(subtotal + input.adjustAmount);
    final mode = roundMode ?? table.roundTotal;
    final rounded = round2(applyRoundMode(beforeRound, mode));
    final delta = round2(rounded - beforeRound);

    return QuoteResult(
      shopName: table.shopName,
      currency: table.currency,
      label: input.label,
      seriesName: series.name,
      unit: series.unit,
      lines: lines,
      widthMm: input.widthMm,
      heightMm: input.heightMm,
      rawQtyPerPiece: rawQty,
      qtyPerPiece: qty,
      qtyTotal: qtyTotal,
      count: count,
      subtotal: subtotal,
      adjustAmount: input.adjustAmount,
      roundingDelta: delta,
      total: rounded,
      usedQtyOverride: usedOverride,
      usedMinCharge: usedMin,
    );
  }
}
