/// 生成一对 Ed25519 密钥(只做一次)。
///
///   dart bin/gen_keypair.dart [--out 私钥保存路径]
///
/// 公钥 → 填进 lib/license/reg_code.dart 的 kRegPublicKeyB64(可以公开)
/// 私钥 → 自己收好,发码工具要用;别进代码库、别发聊天、别打包进 APK
library;

import 'dart:io';

import '../lib/license/reg_code.dart';

void main(List<String> args) async {
  final (seed, pub) = await RegIssuer.generateKeyPair();

  var outPath = 'license_private_key.txt';
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--out') outPath = args[i + 1];
  }

  if (File(outPath).existsSync()) {
    stdout.writeln('$outPath 已存在,不覆盖(先备份/改名再跑)。');
    return;
  }
  File(outPath).writeAsStringSync('# 门窗计价 · Ed25519 私钥(别提交到代码库)\n$seed\n');

  stdout.writeln('=== Ed25519 密钥对 ===');
  stdout.writeln();
  stdout.writeln('公钥(填进 lib/license/reg_code.dart 的 kRegPublicKeyB64):');
  stdout.writeln(pub);
  stdout.writeln();
  stdout.writeln('私钥已写到: $outPath (权限自己管好)');
  stdout.writeln('私钥内容不在屏幕上打印,只在这一个文件里。');
}
