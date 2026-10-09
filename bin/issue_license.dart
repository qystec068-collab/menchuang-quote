/// 电脑上发激活码(手机发码工具没带/没电时的备用,也方便批量)
///
///   dart bin/issue_license.dart --seed-file license_private_key.txt --machine ABCD-1234-EFGH-5678
///   dart bin/issue_license.dart --seed-file key.txt --machine ABCD... --expiry 2708   # 到 2027-08 过期
///
/// 私钥从**文件**读,不从命令行参数传(命令行参数会留在历史/进程列表里)。
library;

import 'dart:io';

import '../lib/license/machine_code.dart';
import '../lib/license/reg_code.dart';

void main(List<String> args) async {
  String? seedFile;
  String? machine;
  var expiry = '';
  var count = 1;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--seed-file':
        if (i + 1 < args.length) seedFile = args[++i];
        break;
      case '--machine':
        if (i + 1 < args.length) machine = args[++i];
        break;
      case '--expiry':
        if (i + 1 < args.length) expiry = args[++i];
        break;
      case '--count':
        if (i + 1 < args.length) count = int.tryParse(args[++i]) ?? 1;
        break;
    }
  }

  if (seedFile == null || machine == null) {
    stderr.writeln('用法: dart bin/issue_license.dart --seed-file <私钥文件> '
        '--machine <机器码> [--expiry YYMM] [--count N]');
    exit(2);
  }

  final f = File(seedFile);
  if (!f.existsSync()) {
    stderr.writeln('找不到私钥文件: $seedFile');
    exit(2);
  }
  final seed = f
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .join();

  final mc = machine.toUpperCase();
  final issuer = await RegIssuer.fromSeedBase64(seed);
  for (var i = 0; i < count; i++) {
    final code = await issuer.issue(mc, expiryYyMm: expiry);
    stdout.writeln(code);
  }
  stderr.writeln('已为机器码 ${normalizeMachineCode(mc)} 生成 $count 个'
      '${expiry.isEmpty ? '(终身)' : '(到 ${expiry.substring(0, 2)}-${expiry.substring(2)} 过期)'}激活码');
}
