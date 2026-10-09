import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pricing/order.dart';
import '../storage/app_store.dart';
import 'common.dart';

/// 当前订单:一个订单里可以有好几个项目(门 / 窗 / 栏杆 ...),最后出总价。
class OrderScreen extends StatefulWidget {
  final VoidCallback? onAddItem;

  const OrderScreen({super.key, this.onAddItem});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  final _discount = TextEditingController();
  final _deposit = TextEditingController();

  @override
  void dispose() {
    for (final c in [_customer, _phone, _address, _note, _discount, _deposit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final draft = store.draft;
    final q = OrderCalculator(store.priceTable).quote(draft);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        const SectionTitle('客户'),
        TextFieldBox(label: '客户名', controller: _customer,
            onChanged: (v) => store.updateDraft(customer: v)),
        Row(
          children: [
            Expanded(
                child: TextFieldBox(
                    label: '电话',
                    controller: _phone,
                    onChanged: (v) => store.updateDraft(phone: v))),
            const SizedBox(width: 8),
            Expanded(
                child: TextFieldBox(
                    label: '地址',
                    controller: _address,
                    onChanged: (v) => store.updateDraft(address: v))),
          ],
        ),
        const SectionTitle('项目'),
        OutlinedButton.icon(
          onPressed: widget.onAddItem,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加项目'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44)),
        ),
        if (draft.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
                '还没有项目。\n点上面「添加项目」→ 选型材、填尺寸 → 点「加入订单」,会回到这里。',
                style: TextStyle(color: Colors.grey)),
          ),
        ...List.generate(q.items.length, (i) {
          final it = q.items[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(it.headline,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => store.removeItem(i)),
                      ),
                    ],
                  ),
                  ...it.lines.map((l) => LineTile(l)),
                  const Divider(height: 12),
                  TotalRow(label: '项目小计', amount: it.total),
                ],
              ),
            ),
          );
        }),
        const SectionTitle('整单'),
        Row(
          children: [
            Expanded(
                child: NumField(
                    label: '优惠(填负数)',
                    controller: _discount,
                    onChanged: () => store.updateDraft(
                        discount: double.tryParse(_discount.text) ?? 0))),
            const SizedBox(width: 8),
            Expanded(
                child: NumField(
                    label: '已收/订金',
                    controller: _deposit,
                    onChanged: () => store.updateDraft(
                        deposit: double.tryParse(_deposit.text) ?? 0))),
          ],
        ),
        TextFieldBox(label: '备注', controller: _note, maxLines: 2,
            onChanged: (v) => store.updateDraft(note: v)),
        const Divider(height: 24),
        TotalRow(label: '项目合计', amount: q.itemsSubtotal),
        if (q.discount != 0) TotalRow(label: '优惠', amount: q.discount),
        if (q.roundingDelta != 0)
          TotalRow(label: '抹零', amount: q.roundingDelta),
        const SizedBox(height: 4),
        TotalRow(label: '合计', amount: q.total, big: true),
        if (q.deposit != 0) ...[
          TotalRow(label: '已收', amount: q.deposit),
          TotalRow(
              label: '欠款',
              amount: q.due,
              color: q.due > 0 ? Colors.red.shade700 : null),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: draft.items.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                            ClipboardData(text: q.toText()));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('报价单已复制,去微信粘贴给客户')));
                      },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制报价单'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: draft.items.isEmpty
                    ? null
                    : () async {
                        await store.commitDraft();
                        if (!context.mounted) return;
                        _customer.clear();
                        _phone.clear();
                        _address.clear();
                        _note.clear();
                        _discount.clear();
                        _deposit.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('订单已保存,可在「历史」里查')));
                        setState(() {});
                      },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('保存订单'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
