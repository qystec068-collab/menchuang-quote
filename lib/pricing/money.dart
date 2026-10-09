/// 金额/面积取整工具。
///
/// 浮点直接加减 0.5 再 round,在 .005/.995 这类边界会翻车
/// (例如 0.145*100 = 14.499999999999998),所以统一走"放大到分再 round",
/// 向下取整则加 epsilon(1e-6)。
library;

import 'models.dart';

/// 四舍五入到分(2 位小数)。
///
/// 注意:这里必须用 floor(c + 0.5),不能写成 round(c + 0.5)——
/// 后者等于加了两次 0.5,金额会凭空多 1 分(1836.00 → 1836.01)。
/// 加 1e-6 是为了救 0.145*100 = 14.499999999999998 这类浮点边界。
double round2(double v) {
  if (!v.isFinite) return v;
  final c = v * 100.0;
  final n = c >= 0
      ? (c + 0.5 + 1e-6).floorToDouble()
      : -((-c + 0.5 + 1e-6).floorToDouble());
  return n / 100.0;
}

/// 向下取整到 1/perUnit(perUnit=10 → 抹到角;1 → 抹到元)。
double floorStep(double v, int perUnit) {
  if (perUnit <= 1) return (v + 1e-6).floorToDouble();
  final x = v * perUnit;
  return (x + 1e-6).floorToDouble() / perUnit;
}

/// 按价格表的抹零方式处理整单总额(抹零 = 向下取,零头让给客户)。
double applyRoundMode(double v, RoundMode mode) {
  switch (mode) {
    case RoundMode.none:
      return round2(v);
    case RoundMode.jiao:
      return floorStep(v, 10);
    case RoundMode.yuan:
      return floorStep(v, 1);
    case RoundMode.tenYuan:
      return ((v + 1e-6) / 10).floorToDouble() * 10.0;
  }
}

/// 毫米 → 米,保留两位(1500 → "1.50")
String mmToM(double mm) => (mm / 1000.0).toStringAsFixed(2);
