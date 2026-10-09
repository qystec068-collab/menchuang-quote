import 'package:flutter/material.dart';

import '../pricing/engine.dart';
import '../pricing/models.dart';
import '../pricing/price_table.dart';
import '../storage/app_store.dart';
import 'common.dart';

/// 计价页:选型材 → 填尺寸 → 勾附加费 → 实时出价 → 加入订单
class QuoteScreen extends StatefulWidget {
  final VoidCallback? onAdded;

  const QuoteScreen({super.key, this.onAdded});

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  String? _category;
  String? _seriesId;
  final _label = TextEditingController();
  final _w = TextEditingController();
  final _h = TextEditingController();
  final _len = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _leaf = TextEditingController(text: '0');
  final _floor = TextEditingController(text: '1');
  final _qtyOverride = TextEditingController();
  final Set<String> _extras = {};

  PriceTable get table => AppStore.instance.priceTable;

  @override
  void initState() {
    super.initState();
    _extras.addAll(table.extras.where((e) => e.defaultOn).map((e) => e.id));
  }

  @override
  void dispose() {
    for (final c in [_label, _w, _h, _len, _count, _leaf, _floor, _qtyOverride]) {
      c.dispose();
    }
    super.dispose();
  }

  Series? get _series => _seriesId == null ? null : table.seriesById(_seriesId!);

  void _pickCategory(String? c) {
    final first = c == null ? null : table.seriesIn(c);
    setState(() {
      _category = c;
      _seriesId = (first == null || first.isEmpty) ? null : first.first.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = table.allCategories;
    if (_category == null && cats.isNotEmpty) {
      _category = cats.firstWhere(
        (c) => table.seriesIn(c).isNotEmpty,
        orElse: () => cats.first,
      );
    }
    final inCat = table.seriesIn(_category ?? '');
    final s = _series;
    final result = _compute();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        const SectionTitle('选型材'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    const InputDecoration(labelText: '类别', isDense: true),
                items: cats
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _pickCategory,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: inCat.any((e) => e.id == _seriesId)
                    ? _seriesId
                    : null,
                decoration: const InputDecoration(
                    labelText: '型材(单价)', isDense: true),
                items: inCat
                    .map((e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(
                              '${e.name}  ${e.price.toStringAsFixed(0)}/${e.unitLabel}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _seriesId = v),
              ),
            ),
          ],
        ),
        if (s != null)
          Text(
            '${s.price.toStringAsFixed(2)} 元/${s.unitLabel}'
            '${s.material.isEmpty ? '' : '  ${s.material}'}'
            '${s.glassNote.isEmpty ? '' : '  ${s.glassNote}'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        const SectionTitle('尺寸与数量'),
        TextFieldBox(label: '项目名(如 阳台推拉门)', controller: _label),
        if (s != null && s.unit == PricingUnit.sqm) ...[
          Row(
            children: [
              Expanded(
                  child: NumField(
                      label: '洞口宽 (mm)',
                      controller: _w,
                      onChanged: _refresh)),
              const SizedBox(width: 8),
              Expanded(
                  child: NumField(
                      label: '洞口高 (mm)',
                      controller: _h,
                      onChanged: _refresh)),
            ],
          ),
        ],
        if (s != null && s.unit == PricingUnit.meter)
          NumField(
              label: '长度 (米)', controller: _len, onChanged: _refresh),
        Row(
          children: [
            Expanded(
                child: NumField(
                    label: '数量(樘/件)',
                    controller: _count,
                    integer: true,
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(
                child: NumField(
                    label: '每件开扇数(可空)',
                    controller: _leaf,
                    integer: true,
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(
                child: NumField(
                    label: '楼层(可空)',
                    controller: _floor,
                    integer: true,
                    onChanged: _refresh)),
          ],
        ),
        NumField(
          label: '计价量手动填(可空)',
          controller: _qtyOverride,
          hint: s == null ? '' : '不足平方想按多少算,就填多少${s.unitLabel}',
          onChanged: _refresh,
        ),
        const SectionTitle('附加费'),
        if (table.extras.isEmpty)
          const Text('还没设附加费,去「设置」里加',
              style: TextStyle(color: Colors.grey)),
        ...table.extras.map((e) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _extras.contains(e.id),
              title: Text(e.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text('${e.price.toStringAsFixed(2)} ${chargeModeLabel(e.mode)}',
                  style: const TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _extras.add(e.id);
                } else {
                  _extras.remove(e.id);
                }
              }),
            )),
        const SectionTitle('这一项多少钱'),
        if (result == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('把尺寸填上就出价', style: TextStyle(color: Colors.grey)),
          )
        else ...[
          Text(result.headline, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Divider(),
          ...result.lines.map((l) => LineTile(l)),
          const Divider(),
          TotalRow(label: '这一项合计', amount: result.total, big: true),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              AppStore.instance.addItem(QuoteInput(
                seriesId: _seriesId!,
                label: _label.text.trim(),
                widthMm: _inputWidthMm(),
                heightMm: double.tryParse(_h.text) ?? 0,
                count: int.tryParse(_count.text) ?? 1,
                leafCount: int.tryParse(_leaf.text) ?? 0,
                floorNo: int.tryParse(_floor.text) ?? 1,
                qtyOverridePerPiece: double.tryParse(_qtyOverride.text),
                extraIds: _extras.toList(),
              ));
              _label.clear();
              _w.clear();
              _h.clear();
              _len.clear();
              _qtyOverride.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('已加入订单,回到「订单」页看合计')));
              widget.onAdded?.call();
            },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('加入订单'),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  void _refresh() => setState(() {});

  /// 存进引擎的 widthMm:门窗=洞口宽(mm);栏杆=长度(米→mm)
  double _inputWidthMm() {
    final s = _series;
    if (s == null) return 0;
    if (s.unit == PricingUnit.meter) {
      return (double.tryParse(_len.text) ?? 0) * 1000;
    }
    if (s.unit == PricingUnit.piece) return 0;
    return double.tryParse(_w.text) ?? 0;
  }

  QuoteResult? _compute() {
    final s = _series;
    if (s == null) return null;
    if (s.unit == PricingUnit.sqm &&
        (double.tryParse(_w.text) ?? 0) <= 0) {
      return null;
    }
    if (s.unit == PricingUnit.meter &&
        (double.tryParse(_len.text) ?? 0) <= 0) {
      return null;
    }
    try {
      return PricingEngine(table).quote(
        QuoteInput(
          seriesId: s.id,
          label: _label.text.trim(),
          widthMm: _inputWidthMm(),
          heightMm: s.unit == PricingUnit.sqm
              ? (double.tryParse(_h.text) ?? 0)
              : 0,
          count: int.tryParse(_count.text) ?? 1,
          leafCount: int.tryParse(_leaf.text) ?? 0,
          floorNo: int.tryParse(_floor.text) ?? 1,
          qtyOverridePerPiece: double.tryParse(_qtyOverride.text),
          extraIds: _extras.toList(),
        ),
        roundMode: RoundMode.none,
      );
    } catch (_) {
      return null;
    }
  }
}
