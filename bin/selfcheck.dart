/// 计价引擎自检(零依赖):
///   dart bin/selfcheck.dart
///
/// 用示例价格表跑几组真实尺寸,把总价与手算结果逐项比对;
/// 任何一项不符就退出码 1。
library;

import 'dart:convert';
import 'dart:io';

import '../lib/pricing/engine.dart';
import '../lib/pricing/models.dart';
import '../lib/pricing/money.dart';
import '../lib/pricing/order.dart';
import '../lib/pricing/price_table.dart';

int _pass = 0;
int _fail = 0;

void check(String what, Object actual, Object expected) {
  if ('$actual' == '$expected') {
    _pass++;
  } else {
    _fail++;
    stdout.writeln('  x $what  实际=$actual  期望=$expected');
  }
}

void checkNear(String what, double actual, double expected) {
  if ((actual - expected).abs() < 0.005) {
    _pass++;
  } else {
    _fail++;
    stdout.writeln('  x $what  实际=$actual  期望=$expected');
  }
}

void section(String s) => stdout.writeln('\n=== $s ===');

void main() {
  final table =
      PriceTable.fromJsonString(File('config/price_table.sample.json').readAsStringSync());
  final engine = PricingEngine(table);
  final orders = OrderCalculator(table);

  stdout.writeln('价格表: ${table.shopName}');
  stdout.writeln('类别 ${table.allCategories.join("/")}');
  stdout.writeln('型材 ${table.series.length} 种,附加项 ${table.extras.length} 项,'
      '抹零=${roundModeLabel(table.roundTotal)}');

  // ---- A:按㎡ 的门窗 ----
  section('A 窗:洞口1.50×1.80m ×2樘,断桥铝108(680/㎡)+安装/拆旧/楼层/运输');
  final a = engine.quote(const QuoteInput(
    seriesId: 'tz108',
    label: '客厅窗',
    widthMm: 1500,
    heightMm: 1800,
    count: 2,
    leafCount: 2,
    floorNo: 3,
    extraIds: ['install', 'remove', 'floorfee', 'transport'],
  ));
  stdout.writeln(a.toText());
  checkNear('A 单件面积', a.rawQtyPerPiece, 2.70);
  checkNear('A 合计面积', a.qtyTotal, 5.40);
  checkNear('A 型材金额', a.lines[0].amount, 3672.00);
  checkNear('A 小计', a.subtotal, 4201.00);
  checkNear('A 合计', a.total, 4201.00);

  // ---- B:比例附加 + 抹零 ----
  section('B 同 A + 管理利润3%');
  final b = engine.quote(const QuoteInput(
    seriesId: 'tz108',
    widthMm: 1500,
    heightMm: 1800,
    count: 2,
    leafCount: 2,
    floorNo: 3,
    extraIds: ['install', 'remove', 'floorfee', 'transport', 'profit'],
  ));
  checkNear('B 利润金额(4201×3%)', b.lines.last.amount, 126.03);
  checkNear('B 小计', b.subtotal, 4327.03);
  checkNear('B 抹零差额', b.roundingDelta, -0.03);
  checkNear('B 合计(抹到元)', b.total, 4327.00);

  // ---- C:计价量手动输入 ----
  section('C 洞口0.80×0.60m,断桥铝70,师傅手动按 1.00㎡ 计价');
  final c = engine.quote(const QuoteInput(
    seriesId: 'tz70',
    widthMm: 800,
    heightMm: 600,
    qtyOverridePerPiece: 1.00,
  ));
  checkNear('C 尺寸算出的面积', c.rawQtyPerPiece, 0.48);
  checkNear('C 实际计价面积', c.qtyPerPiece, 1.00);
  checkNear('C 合计', c.total, 620.00);
  check('C 标记手动输入', c.usedQtyOverride, true);

  // ---- D:最小计价量规则 ----
  section('D 洞口0.80×0.60m,断桥铝60(最小计价 1.00㎡)');
  final d = engine.quote(const QuoteInput(
    seriesId: 'tz60',
    widthMm: 800,
    heightMm: 600,
  ));
  checkNear('D 计价面积', d.qtyPerPiece, 1.00);
  checkNear('D 合计', d.total, 520.00);
  check('D 标记最小计价量', d.usedMinCharge, true);

  // ---- E:手动优惠 + 抹到十元 ----
  section('E 优惠100 + 抹到十元');
  final e = PricingEngine(table.copyWith(roundTotal: RoundMode.tenYuan)).quote(
    const QuoteInput(
      seriesId: 'pt70',
      widthMm: 2000,
      heightMm: 1500,
      count: 3,
      adjustAmount: -100,
    ),
  );
  checkNear('E 小计(9㎡×280)', e.subtotal, 2520.00);
  checkNear('E 合计', e.total, 2420.00);

  // ---- F:取整边界 ----
  section('F 金额取整边界');
  checkNear('round2(0.145)', round2(0.145), 0.15);
  checkNear('round2(2.70*680)', round2(2.70 * 680), 1836.00);
  checkNear('抹到角 4601.07', floorStep(4601.07, 10), 4601.00);
  checkNear('抹到元 4601.99', floorStep(4601.99, 1), 4601.00);

  // ---- G:栏杆/扶手按延米 ----
  section('G 栏杆:长3.20m ×1,不锈钢320/m + 立柱45/m');
  final g = engine.quote(const QuoteInput(
    seriesId: 'lt-ss',
    label: '阳台栏杆',
    widthMm: 3200,
    count: 1,
    extraIds: ['post'],
  ));
  stdout.writeln(g.toText());
  checkNear('G 计价长度', g.qtyPerPiece, 3.20);
  checkNear('G 型材金额', g.lines[0].amount, 1024.00);
  checkNear('G 立柱金额', g.lines[1].amount, 144.00);
  checkNear('G 合计', g.total, 1168.00);

  // ---- H:纱窗按樘 ----
  section('H 纱窗:按樘 150,4樘');
  final h = engine.quote(const QuoteInput(
    seriesId: 'sc-pc',
    label: '厨房纱窗',
    widthMm: 0,
    count: 4,
  ));
  checkNear('H 合计计价量', h.qtyTotal, 4.0);
  checkNear('H 合计', h.total, 600.00);

  // ---- I:整单(门 + 窗 + 栏杆),含优惠和订金 ----
  section('I 整单:门1樘 + 窗2樘(含安装) + 栏杆3.2m,优惠100,订金1000');
  final order = Order(
    id: 'O-20261008-001',
    customer: '张三',
    phone: '13800000000',
    address: '幸福小区 3-2-501',
    date: DateTime(2026, 10, 8),
    items: const [
      OrderItem(QuoteInput(
        seriesId: 'tz60',
        label: '入户门',
        widthMm: 1000,
        heightMm: 2100,
      )),
      OrderItem(QuoteInput(
        seriesId: 'tz108',
        label: '客厅窗',
        widthMm: 1500,
        heightMm: 1800,
        count: 2,
        leafCount: 2,
        extraIds: ['install'],
      )),
      OrderItem(QuoteInput(
        seriesId: 'lt-ss',
        label: '阳台栏杆',
        widthMm: 3200,
      )),
    ],
    discount: -100,
    deposit: 1000,
  );
  final iq = orders.quote(order);
  stdout.writeln(iq.toText());
  checkNear('I 项目1(2.10㎡×520)', iq.items[0].total, 1092.00);
  checkNear('I 项目2(3672+189)', iq.items[1].total, 3861.00);
  checkNear('I 项目3(3.2m×320)', iq.items[2].total, 1024.00);
  checkNear('I 项目合计', iq.itemsSubtotal, 5977.00);
  checkNear('I 整单合计', iq.total, 5877.00);
  checkNear('I 欠款', iq.due, 4877.00);

  // ---- J:价格表 JSON 往返 ----
  section('J 价格表存取往返');
  final round = PriceTable.fromJsonString(table.toJsonString());
  check('J 型材数一致', round.series.length, table.series.length);
  check('J 抹零一致', roundModeKey(round.roundTotal), roundModeKey(table.roundTotal));
  check('J 类别一致', round.categories.length, table.categories.length);
  check('J 空表未就绪', PriceTable.blank().isReady, false);
  check('J 示例表已就绪', table.isReady, true);
  final o2 = Order.fromJson(
      jsonDecode(jsonEncode(order.toJson())) as Map<String, dynamic>);
  check('J 订单往返项目数', o2.items.length, order.items.length);
  check('J 订单往返客户', o2.customer, order.customer);
  check('J 订单往返优惠', o2.discount, order.discount);

  stdout.writeln('\n通过 $_pass 项,失败 $_fail 项');
  if (_fail > 0) exit(1);
}
