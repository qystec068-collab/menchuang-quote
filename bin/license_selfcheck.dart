/// 激活码自检(零后端):
///   dart bin/license_selfcheck.dart
///
/// 现场生成一对密钥 → 发码 → 验签,并验证"换机器码 / 过期 / 乱码"必须失败。
library;

import 'dart:io';

import '../lib/license/license_config.dart';
import '../lib/license/machine_code.dart';
import '../lib/license/reg_code.dart';
import '../lib/license/trial.dart';

int _pass = 0;
int _fail = 0;

void check(String what, Object actual, Object expected) {
  if ('$actual' == '$expected') {
    _pass++;
  } else {
    _fail++;
    stdout.writeln('  x $what  实际=$actual  期望=$expected');
  }
}

Future<void> main() async {
  // 1) 机器码
  final mc = machineCodeFromAndroidId('a1b2c3d4e5f60718');
  stdout.writeln('示例机器码: $mc');
  check('机器码长度', mc.length, 19); // 16 + 3 个横杠
  check('机器码可归一化往返', normalizeMachineCode(mc).length, 16);

  // 2) 生成密钥对
  final (seed, pub) = await RegIssuer.generateKeyPair();
  stdout.writeln('测试公钥: $pub');
  final issuer = await RegIssuer.fromSeedBase64(seed);
  check('公钥一致', await issuer.publicKeyBase64(), pub);

  final verifier = RegVerifier(pub);
  check('验签器已配置', verifier.isConfigured, true);

  // 3) 终身码:本机通过
  final code = await issuer.issue(mc);
  stdout.writeln('终身激活码: $code');
  var r = await verifier.verify(code, mc);
  check('终身码-结果', r.ok, true);

  // 4) 换台机器必须失败
  final other = machineCodeFromAndroidId('ffffffffffffffff');
  r = await verifier.verify(code, other);
  check('别的机器码-结果', r.ok, false);

  // 5) 手抄容错:小写/带空格也能激活
  r = await verifier.verify(code, ' ${mc.toLowerCase()} ');
  check('小写带空格-结果', r.ok, true);

  // 6) 过期码
  final past = await issuer.issue(mc, expiryYyMm: '2001');
  r = await verifier.verify(past, mc);
  check('已过期码-结果', r.ok, false);
  stdout.writeln('过期码提示: ${r.reason}');

  // 7) 未来到期
  final future = await issuer.issue(mc, expiryYyMm: '9912');
  r = await verifier.verify(future, mc);
  check('未到期码-结果', r.ok, true);

  // 8) 串改/乱码
  r = await verifier.verify('REG-xxxxxxxxxxxx', mc);
  check('乱码-结果', r.ok, false);
  r = await verifier.verify(code.replaceRange(10, 11, 'A'), mc);
  check('改动一位-结果', r.ok, false);

  // 9) 别的私钥签的码必须失败(防自己造码)
  final (seed2, _) = await RegIssuer.generateKeyPair();
  final fake = await RegIssuer.fromSeedBase64(seed2);
  final fakeCode = await fake.issue(mc);
  r = await verifier.verify(fakeCode, mc);
  check('他人私钥签的码-结果', r.ok, false);

  // 10) 试用期 7 天 + 防回拨
  stdout.writeln('\n--- 试用期(售价 ${kAppPriceYuan.toStringAsFixed(0)} 元,${kTrialDays} 天)---');
  final day0 = DateTime(2026, 10, 1, 9);
  final trial = TrialState.fresh(day0);
  check('第0天-剩', trial.daysLeft(day0), kTrialDays);
  check('第0天-未过期', trial.isExpired(day0), false);
  final day6 = day0.add(const Duration(days: 6));
  check('第6天-剩', trial.daysLeft(day6), 1);
  check('第6天-未过期', trial.isExpired(day6), false);
  final day7 = day0.add(const Duration(days: 7));
  check('第7天-过期', trial.isExpired(day7), true);
  check('第7天-剩0', trial.daysLeft(day7), 0);

  // 回拨:先把 lastSeen 推到第 5 天,再把时间拨回第 1 天
  final t5 = trial.sawNow(day0.add(const Duration(days: 5)));
  final rolled = day0.add(const Duration(days: 1));
  check('回拨-被识别', t5.clockRollback(rolled), true);
  check('回拨-天数不回退', t5.daysUsed(rolled), 5);
  check('回拨-剩', t5.daysLeft(rolled), 2);
  check('回拨-提示', t5.describe(rolled).contains('时间被改过'), true);

  // 正常前进不算回拨
  check('正常前进-不算回拨',
      trial.clockRollback(day0.add(const Duration(minutes: 1))), false);

  // 激活后不再受试用期限制
  final lic = trial.activate();
  check('激活后-不过期', lic.isExpired(day7.add(const Duration(days: 100))), false);
  check('激活后-文案', lic.describe(day7), '已激活 · 终身使用');

  // 存取往返
  final rt = TrialState.fromJson(lic.toJson());
  check('试用状态往返-已激活', rt.licensed, true);

  stdout.writeln('\n通过 $_pass 项,失败 $_fail 项');
  if (_fail > 0) exit(1);
}
