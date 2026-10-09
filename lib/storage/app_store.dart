import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../pricing/models.dart';
import '../pricing/order.dart';
import '../pricing/price_table.dart';

/// 全app的数据中枢:价格表 + 订单,存本地 JSON(离线优先,工地没网也能用)。
class AppStore extends ChangeNotifier {
  AppStore._();

  static final AppStore instance = AppStore._();

  PriceTable priceTable = PriceTable.blank();
  List<Order> orders = [];
  Order draft = Order(id: '', date: DateTime.now());
  bool loaded = false;

  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}${Platform.pathSeparator}menchuang_data.json');
      if (await _file!.exists()) {
        final raw = await _file!.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final t = (map['priceTable'] as Map?)?.cast<String, dynamic>();
        if (t != null) priceTable = PriceTable.fromJson(t);
        orders = ((map['orders'] as List?) ?? const [])
            .map((e) => Order.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {
      // 首次运行 / 文件损坏:用空表,让师傅重新设置
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final map = {
        'priceTable': priceTable.toJson(),
        'orders': orders.map((e) => e.toJson()).toList(),
      };
      await _file?.writeAsString(jsonEncode(map));
    } catch (_) {
      // 存盘失败不阻断使用
    }
  }

  Future<void> savePriceTable(PriceTable t) async {
    priceTable = t;
    await save();
    notifyListeners();
  }

  // ---- 当前订单 ----

  void newDraft() {
    draft = Order(id: _newOrderId(), date: DateTime.now());
    notifyListeners();
  }

  void updateDraft({
    String? customer,
    String? phone,
    String? address,
    String? note,
    double? discount,
    double? deposit,
  }) {
    draft = draft.copyWith(
      customer: customer,
      phone: phone,
      address: address,
      note: note,
      discount: discount,
      deposit: deposit,
    );
    notifyListeners();
  }

  void addItem(QuoteInput input) {
    draft = draft.copyWith(items: [...draft.items, OrderItem(input)]);
    if (draft.id.isEmpty) draft = draft.copyWith(id: _newOrderId());
    notifyListeners();
  }

  void removeItem(int index) {
    final list = [...draft.items];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    draft = draft.copyWith(items: list);
    notifyListeners();
  }

  Future<void> commitDraft({bool keepDraft = false}) async {
    if (draft.items.isEmpty) return;
    if (draft.id.isEmpty) draft = draft.copyWith(id: _newOrderId());
    orders.insert(0, draft);
    draft = Order(id: _newOrderId(), date: DateTime.now());
    await save();
    notifyListeners();
  }

  Future<void> deleteOrder(String id) async {
    orders.removeWhere((o) => o.id == id);
    await save();
    notifyListeners();
  }

  static String _newOrderId() {
    final d = DateTime.now();
    String p(int v) => v < 10 ? '0$v' : '$v';
    return 'O-${d.year}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }
}
