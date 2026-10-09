import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../pricing/order.dart';
import '../storage/app_store.dart';
import 'common.dart';

/// 历史订单 + 统计(本月单数/金额、未收欠款)
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final table = store.priceTable;
    final calc = OrderCalculator(table);
    final now = DateTime.now();

    var monthCount = 0;
    var monthAmount = 0.0;
    var allAmount = 0.0;
    var dueAll = 0.0;
    for (final o in store.orders) {
      final q = calc.quote(o);
      allAmount += q.total;
      dueAll += q.due;
      if (o.date.year == now.year && o.date.month == now.month) {
        monthCount++;
        monthAmount += q.total;
      }
    }

    if (store.orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('还没有订单。\n在「计价」页算好项目,「订单」页保存后就会出现在这里。',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TotalRow(label: '本月 $monthCount 单', amount: monthAmount),
                TotalRow(label: '累计 ${store.orders.length} 单', amount: allAmount),
                TotalRow(
                  label: '未收欠款',
                  amount: dueAll,
                  color: dueAll > 0 ? Colors.red.shade700 : null,
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('订单'),
        ...store.orders.map((o) {
          final q = calc.quote(o);
          final d = o.date;
          String p(int v) => v < 10 ? '0$v' : '$v';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(o.customer.isEmpty ? '(未填客户)' : o.customer),
              subtitle: Text(
                '${d.year}-${p(d.month)}-${p(d.day)}  ${o.items.length}个项目'
                '${q.due > 0 ? '  欠 ${moneyText(q.due)}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(moneyText(q.total),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () => _showDetail(context, q),
              onLongPress: () => _confirmDelete(context, store, o.id),
            ),
          );
        }),
        const SizedBox(height: 110),
      ],
    );
  }

  void _showDetail(BuildContext context, OrderQuote q) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.toText(), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: q.toText()));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制这份报价单'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppStore store, String id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除订单?'),
        content: const Text('删掉就找不回来了。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('不删')),
          FilledButton(
            onPressed: () {
              store.deleteOrder(id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
