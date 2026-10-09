import 'package:flutter/material.dart';

import '../pricing/models.dart';
import '../pricing/price_table.dart';
import '../storage/app_store.dart';
import 'common.dart';

/// 价格表设置。软件第一次打开就进这里:师傅自己录型材、附加费,点确定开始用。
class SetupScreen extends StatefulWidget {
  final bool firstRun;

  const SetupScreen({super.key, this.firstRun = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _shop =
      TextEditingController(text: AppStore.instance.priceTable.shopName);
  late final TextEditingController _phone =
      TextEditingController(text: AppStore.instance.priceTable.shopPhone);
  late List<String> _cats = [...AppStore.instance.priceTable.allCategories];
  late List<Series> _series = [...AppStore.instance.priceTable.series];
  late List<ExtraDef> _extras = [...AppStore.instance.priceTable.extras];
  late RoundMode _round = AppStore.instance.priceTable.roundTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstRun ? '第一次使用 · 先设好价格表' : '价格表设置'),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          if (widget.firstRun)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '先填你自己的价格:店名、型材单价、常用附加费。\n'
                  '填完点最下面的「保存并开始使用」,以后随时可以在右上角改。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          const SectionTitle('店铺'),
          TextFieldBox(label: '店名(会印在报价单上)', controller: _shop),
          TextFieldBox(label: '电话', controller: _phone),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DropdownButtonFormField<RoundMode>(
              initialValue: _round,
              decoration: const InputDecoration(
                  labelText: '整单抹零', isDense: true),
              items: RoundMode.values
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(roundModeLabel(m))))
                  .toList(),
              onChanged: (v) => setState(() => _round = v ?? _round),
            ),
          ),
          Row(
            children: [
              const Expanded(child: SectionTitle('项目类别')),
              TextButton.icon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('加类别'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: _cats
                .map((c) => Chip(
                      label: Text(c),
                      onDeleted: _cats.length <= 1
                          ? null
                          : () => setState(() => _cats.remove(c)),
                    ))
                .toList(),
          ),
          Row(
            children: [
              const Expanded(child: SectionTitle('型材(按单位计价)')),
              TextButton.icon(
                onPressed: () => _editSeries(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('加型材'),
              ),
            ],
          ),
          if (_series.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('还没有型材,点「加型材」把常用的录进去',
                  style: TextStyle(color: Colors.grey)),
            ),
          ..._series.map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${s.name}  (${s.category})'),
                  subtitle: Text(
                    '${s.price.toStringAsFixed(2)} 元/${s.unitLabel}'
                    '${s.minChargeQty > 0 ? '   最小计价 ${s.minChargeQty}${s.unitLabel}' : ''}'
                    '${s.material.isEmpty ? '' : '   ${s.material}'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editSeries(initial: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => setState(() => _series.remove(s)),
                      ),
                    ],
                  ),
                ),
              )),
          Row(
            children: [
              const Expanded(child: SectionTitle('常用附加费')),
              TextButton.icon(
                onPressed: () => _editExtra(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('加附加费'),
              ),
            ],
          ),
          if (_extras.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('例如:安装费、拆旧、运输、楼层费、纱窗、立柱',
                  style: TextStyle(color: Colors.grey)),
            ),
          ..._extras.map((e) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    '${e.price.toStringAsFixed(2)} ${chargeModeLabel(e.mode)}'
                    '${e.defaultOn ? '   默认勾选' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editExtra(initial: e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => setState(() => _extras.remove(e)),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: Text(widget.firstRun ? '保存并开始使用' : '保存'),
          ),
          const SizedBox(height: 110),
        ],
      ),
    );
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增类别'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: '例如:纱窗 / 雨棚 / 防盗网', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && !_cats.contains(name)) {
      setState(() => _cats.add(name));
    }
  }

  Future<void> _editSeries({Series? initial}) async {
    final init = initial;
    final nameC = TextEditingController(text: init?.name ?? '');
    final matC = TextEditingController(text: init?.material ?? '');
    final priceC = TextEditingController(
        text: init == null ? '' : init.price.toStringAsFixed(2));
    final wallC = TextEditingController(
        text: init == null || init.wallThicknessMm == 0
            ? ''
            : init.wallThicknessMm.toString());
    final minC = TextEditingController(
        text: init == null || init.minChargeQty == 0
            ? ''
            : init.minChargeQty.toString());
    var cat = init?.category ?? (_cats.isEmpty ? '其他' : _cats.first);
    var unit = init?.unit ?? PricingUnit.sqm;

    final res = await showDialog<Series>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(init == null ? '添加型材' : '编辑型材'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: cat,
                  decoration: const InputDecoration(
                      labelText: '类别', isDense: true),
                  items: _cats
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setLocal(() => cat = v ?? cat),
                ),
                TextFieldBox(label: '名称(如 断桥铝 108 系列)', controller: nameC),
                TextFieldBox(label: '材质(可空)', controller: matC),
                DropdownButtonFormField<PricingUnit>(
                  initialValue: unit,
                  decoration: const InputDecoration(
                      labelText: '计价单位', isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: PricingUnit.sqm, child: Text('按㎡ — 门窗')),
                    DropdownMenuItem(
                        value: PricingUnit.meter,
                        child: Text('按延米 — 栏杆/扶手')),
                    DropdownMenuItem(
                        value: PricingUnit.piece, child: Text('按樘/个 — 成品件')),
                  ],
                  onChanged: (v) => setLocal(() => unit = v ?? unit),
                ),
                NumField(label: '单价(元/单位)', controller: priceC),
                NumField(label: '壁厚 mm(可空)', controller: wallC),
                NumField(
                    label: '最小计价量(可空,不足按它算)',
                    controller: minC,
                    hint: '例如 1.0'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final s = Series(
                  id: init?.id ?? 's${DateTime.now().microsecondsSinceEpoch}',
                  category: cat,
                  name: nameC.text.trim(),
                  material: matC.text.trim(),
                  unit: unit,
                  price: double.tryParse(priceC.text) ?? 0,
                  wallThicknessMm: double.tryParse(wallC.text) ?? 0,
                  minChargeQty: double.tryParse(minC.text) ?? 0,
                );
                if (s.name.isEmpty || s.price <= 0) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx, s);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      final i = init == null
          ? -1
          : _series.indexWhere((e) => e.id == init.id);
      if (i >= 0) {
        _series[i] = res;
      } else {
        _series.add(res);
      }
    });
  }

  Future<void> _editExtra({ExtraDef? initial}) async {
    final init = initial;
    final nameC = TextEditingController(text: init?.name ?? '');
    final priceC = TextEditingController(
        text: init == null ? '' : init.price.toStringAsFixed(2));
    var mode = init?.mode ?? ChargeMode.fixed;
    var defOn = init?.defaultOn ?? false;

    final res = await showDialog<ExtraDef>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(init == null ? '添加附加费' : '编辑附加费'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFieldBox(label: '名目(如 安装费)', controller: nameC),
                DropdownButtonFormField<ChargeMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                      labelText: '怎么算', isDense: true),
                  items: ChargeMode.values
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                                '${chargeModeLabel(m)}  ${_modeHint(m)}'),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => mode = v ?? mode),
                ),
                NumField(label: '金额(按上面单位)', controller: priceC),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('默认勾选', style: TextStyle(fontSize: 14)),
                  value: defOn,
                  onChanged: (v) => setLocal(() => defOn = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final e = ExtraDef(
                  id: init?.id ?? 'e${DateTime.now().microsecondsSinceEpoch}',
                  name: nameC.text.trim(),
                  mode: mode,
                  price: double.tryParse(priceC.text) ?? 0,
                  defaultOn: defOn,
                );
                if (e.name.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx, e);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (res == null) return;
    setState(() {
      final i =
          init == null ? -1 : _extras.indexWhere((e) => e.id == init.id);
      if (i >= 0) {
        _extras[i] = res;
      } else {
        _extras.add(res);
      }
    });
  }

  static String _modeHint(ChargeMode m) {
    switch (m) {
      case ChargeMode.perSqm:
        return '按面积';
      case ChargeMode.perMeter:
        return '按长度';
      case ChargeMode.perLeaf:
        return '按开扇数';
      case ChargeMode.perPiece:
        return '按数量';
      case ChargeMode.perFloor:
        return '按楼层';
      case ChargeMode.fixed:
        return '整单一次';
      case ChargeMode.percent:
        return '按小计百分比';
    }
  }

  Future<void> _save() async {
    final t = PriceTable(
      shopName: _shop.text.trim(),
      shopPhone: _phone.text.trim(),
      roundTotal: _round,
      categories: _cats,
      series: _series,
      extras: _extras,
    );
    if (t.shopName.isEmpty || t.series.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('至少要填店名和一种型材')));
      return;
    }
    await AppStore.instance.savePriceTable(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已保存')));
    if (!widget.firstRun && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
