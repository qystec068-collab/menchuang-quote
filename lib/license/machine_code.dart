/// 机器码:一台手机一个,客户把它报给老板,老板据此发激活码。
///
/// 安卓上取 ANDROID_ID(不需要任何权限,同一台机器稳定),
/// 再 SHA256 后取前 16 位十六进制、四位一组,方便口头报/手抄。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 去掉所有非字母数字并转大写 —— 客户手抄/口误的容错(和外贸系统 license.py 一个做法)
String normalizeMachineCode(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

/// 由 ANDROID_ID 派生机器码:XXXX-XXXX-XXXX-XXXX
String machineCodeFromAndroidId(String androidId) {
  final h = sha256.convert(utf8.encode('mc|$androidId')).toString().toUpperCase();
  final s = h.substring(0, 16);
  return [for (var i = 0; i < 16; i += 4) s.substring(i, i + 4)].join('-');
}

/// 没拿到 ANDROID_ID(比如非安卓/测试)时,用一段随机种子兜底
String machineCodeFromSeed(String seed) {
  final h = sha256.convert(utf8.encode('seed|$seed')).toString().toUpperCase();
  final s = h.substring(0, 16);
  return [for (var i = 0; i < 16; i += 4) s.substring(i, i + 4)].join('-');
}
