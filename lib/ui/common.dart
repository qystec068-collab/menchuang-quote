import 'package:flutter/material.dart';

import '../pricing/models.dart';

/// 金额显示:¥1,234.56
String moneyText(double v) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(2);
  final dot = s.indexOf('.');
  final intPart = s.substring(0, dot);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}¥$buf.${s.substring(dot + 1)}';
}

/// 数量显示:整数不带小数点
String qtyText(double v) =>
    (v - v.roundToDouble()).abs() < 1e-9 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool integer;
  final VoidCallback? onChanged;

  const NumField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.integer = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: controller,
          onChanged: onChanged == null ? null : (_) => onChanged!(),
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class TextFieldBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const TextFieldBox({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

/// 明细行
class LineTile extends StatelessWidget {
  final QuoteLine line;
  const LineTile(this.line, {super.key});

  @override
  Widget build(BuildContext context) {
    final sub = '${qtyText(line.qty)}${line.unit} × ${line.unitPrice.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontSize: 14)),
                Text(
                  line.note == null ? sub : '$sub   ${line.note}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            line.amount.toStringAsFixed(2),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// "合计"一行
class TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool big;
  final Color? color;

  const TotalRow({
    super.key,
    required this.label,
    required this.amount,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: big ? 16 : 14)),
            Text(
              moneyText(amount),
              style: TextStyle(
                fontSize: big ? 20 : 14,
                fontWeight: big ? FontWeight.bold : FontWeight.w600,
                color: color ?? (big ? Theme.of(context).colorScheme.primary : null),
              ),
            ),
          ],
        ),
      );
}
