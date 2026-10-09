/// 订单:一个订单里可以有多个项目(门 / 窗 / 栏杆 / 扶手 ...),
/// 每项用计价引擎单独算,最后在整单层面做优惠、抹零、订金、欠款。
library;

import 'money.dart';
import 'models.dart';
import 'engine.dart';
import 'price_table.dart';

/// 订单里的一个项目(项目名 + 计价输入)
class OrderItem {
  final QuoteInput input;

  const OrderItem(this.input);

  Map<String, dynamic> toJson() => {'input': input.toJson()};

  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(QuoteInput.fromJson(j['input'] as Map<String, dynamic>));
}

/// 一张订单
class Order {
  final String id;
  final String customer;
  final String phone;
  final String address;
  final DateTime date;
  final List<OrderItem> items;
  final double discount; // 整单优惠(负数为让利)
  final double deposit; // 已收(订金)
  final String note;

  const Order({
    required this.id,
    this.customer = '',
    this.phone = '',
    this.address = '',
    required this.date,
    this.items = const [],
    this.discount = 0,
    this.deposit = 0,
    this.note = '',
  });

  Order copyWith({
    String? id,
    String? customer,
    String? phone,
    String? address,
    DateTime? date,
    List<OrderItem>? items,
    double? discount,
    double? deposit,
    String? note,
  }) =>
      Order(
        id: id ?? this.id,
        customer: customer ?? this.customer,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        date: date ?? this.date,
        items: items ?? this.items,
        discount: discount ?? this.discount,
        deposit: deposit ?? this.deposit,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer': customer,
        'phone': phone,
        'address': address,
        'date': date.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'deposit': deposit,
        'note': note,
      };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: (j['id'] ?? '').toString(),
        customer: (j['customer'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        date: DateTime.tryParse((j['date'] ?? '').toString()) ?? DateTime.now(),
        items: ((j['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        deposit: (j['deposit'] as num?)?.toDouble() ?? 0,
        note: (j['note'] ?? '').toString(),
      );
}

/// 整单计算结果
class OrderQuote {
  final String shopName;
  final String currency;
  final Order order;
  final List<QuoteResult> items;
  final double itemsSubtotal; // 各项目合计之和
  final double discount;
  final double beforeRound;
  final double roundingDelta;
  final double total;
  final double deposit;
  final double due; // 欠款

  const OrderQuote({
    required this.shopName,
    required this.currency,
    required this.order,
    required this.items,
    required this.itemsSubtotal,
    required this.discount,
    required this.beforeRound,
    required this.roundingDelta,
    required this.total,
    required this.deposit,
    required this.due,
  });

  /// 整单报价单文字(发微信用)
  String toText() {
    final b = StringBuffer();
    b.writeln('【报价单】$shopName');
    final d = order.date;
    final dateStr = '${d.year}-${_2(d.month)}-${_2(d.day)}';
    b.writeln('日期 $dateStr');
    if (order.customer.isNotEmpty) b.writeln('客户 ${order.customer}');
    if (order.phone.isNotEmpty) b.writeln('电话 ${order.phone}');
    if (order.address.isNotEmpty) b.writeln('地址 ${order.address}');
    b.writeln('========================');
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      b.writeln('${i + 1}. ${it.headline}');
      for (final l in it.lines) {
        final note = l.note == null ? '' : ' (${l.note})';
        b.writeln('   ${l.name}$note');
        b.writeln('     ${QuoteResult.numText(l.qty)}${l.unit} × '
            '${l.unitPrice.toStringAsFixed(2)} = ${l.amount.toStringAsFixed(2)}');
      }
      if (it.adjustAmount != 0) {
        b.writeln('   项目调整 ${it.adjustAmount > 0 ? '+' : ''}'
            '${it.adjustAmount.toStringAsFixed(2)}');
      }
      b.writeln('   项目小计 ${it.total.toStringAsFixed(2)}');
    }
    b.writeln('========================');
    b.writeln('项目合计    ${itemsSubtotal.toStringAsFixed(2)}');
    if (discount != 0) {
      b.writeln('优惠        ${discount.toStringAsFixed(2)}');
    }
    if (roundingDelta != 0) {
      b.writeln('抹零        ${roundingDelta.toStringAsFixed(2)}');
    }
    b.writeln('合计        $currency${total.toStringAsFixed(2)}');
    if (deposit != 0) {
      b.writeln('已收        ${deposit.toStringAsFixed(2)}');
      b.writeln('欠款        $currency${due.toStringAsFixed(2)}');
    }
    if (order.note.isNotEmpty) {
      b.writeln('备注 $order.note');
    }
    return b.toString().trimRight();
  }

  static String _2(int v) => v < 10 ? '0$v' : '$v';
}

/// 整单计算器
class OrderCalculator {
  final PriceTable table;

  OrderCalculator(this.table);

  OrderQuote quote(Order order) {
    final items = <QuoteResult>[];
    for (final it in order.items) {
      // 项目级不抹零,抹零统一在整单做
      items.add(PricingEngine(table).quote(it.input, roundMode: RoundMode.none));
    }
    double sub = 0;
    for (final r in items) {
      sub += r.total;
    }
    final itemsSubtotal = round2(sub);
    final beforeRound = round2(itemsSubtotal + order.discount);
    final total = round2(applyRoundMode(beforeRound, table.roundTotal));
    final deposit = round2(order.deposit);
    return OrderQuote(
      shopName: table.shopName,
      currency: table.currency,
      order: order,
      items: items,
      itemsSubtotal: itemsSubtotal,
      discount: round2(order.discount),
      beforeRound: beforeRound,
      roundingDelta: round2(total - beforeRound),
      total: total,
      deposit: deposit,
      due: round2(total - deposit),
    );
  }
}
