/// 注册码(激活码):Ed25519 非对称签名。
///
/// - 客户端**只内置公钥**,验签;造不出码。
/// - 私钥只在老板手里(电脑发码工具 / 手机发码工具导入),**绝不进 APK**。
/// - 格式(与外贸系统 license.py 一致):
///     REG-<base64签名>            终身有效
///     REG-<base64签名>-YYMM       到 YYMM(yy年mm月)过期
/// - 签名内容:REG|<机器码> 或 REG|<机器码>|<YYMM>
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'machine_code.dart';

/// ★ 上线前把 bin/gen_keypair.dart 生成的公钥填到这里(私钥自己收好,别进代码库)
const String kRegPublicKeyB64 = 'FILL_ME_WITH_PUBLIC_KEY';

/// 校验结果
class RegCheck {
  final bool ok;
  final String reason;
  final String expiryYyMm;
  const RegCheck(this.ok, this.reason, [this.expiryYyMm = '']);
}

String regMessage(String machineCode, String expiryYyMm) => expiryYyMm.isEmpty
    ? 'REG|${normalizeMachineCode(machineCode)}'
    : 'REG|${normalizeMachineCode(machineCode)}|$expiryYyMm';

List<int> _decodeB64(String s) {
  final t = s.trim().replaceAll(' ', '+');
  final pad = t.length % 4;
  return base64.decode(pad == 0 ? t : t + '=' * (4 - pad));
}

/// 私钥签名器(只在发码工具里用)
class RegIssuer {
  final SimpleKeyPair _kp;
  RegIssuer._(this._kp);

  /// seedBase64: 32 字节 Ed25519 私钥种子的 base64(bin/gen_keypair.dart 生成)
  static Future<RegIssuer> fromSeedBase64(String seedBase64) async {
    final seed = _decodeB64(seedBase64);
    if (seed.length != 32) {
      throw ArgumentError('私钥种子应为 32 字节,实际 ${seed.length} 字节');
    }
    return RegIssuer._(await Ed25519().newKeyPairFromSeed(seed));
  }

  /// 生成一对新密钥,返回 (私钥种子base64, 公钥base64)
  static Future<(String, String)> generateKeyPair() async {
    final kp = await Ed25519().newKeyPair();
    final seed = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    return (base64.encode(seed), base64.encode(pub.bytes));
  }

  Future<String> publicKeyBase64() async {
    final pub = await _kp.extractPublicKey();
    return base64.encode(pub.bytes);
  }

  /// 发码
  Future<String> issue(String machineCode, {String expiryYyMm = ''}) async {
    final msg = regMessage(machineCode, expiryYyMm);
    final sig = await Ed25519().sign(utf8.encode(msg), keyPair: _kp);
    final b64 = base64.encode(sig.bytes);
    return expiryYyMm.isEmpty ? 'REG-$b64' : 'REG-$b64-$expiryYyMm';
  }
}

/// 公钥验签器(客户端内置公钥用它)
class RegVerifier {
  final String publicKeyBase64;

  const RegVerifier([this.publicKeyBase64 = kRegPublicKeyB64]);

  bool get isConfigured =>
      publicKeyBase64.isNotEmpty && publicKeyBase64 != 'FILL_ME_WITH_PUBLIC_KEY';

  /// 校验激活码是否与这台机器的机器码匹配
  Future<RegCheck> verify(String code, String machineCode) async {
    if (!isConfigured) {
      return const RegCheck(false, '本版未内置公钥,无法校验');
    }
    final c = code.trim();
    if (!c.startsWith('REG-')) {
      return const RegCheck(false, '激活码格式不对');
    }
    final parts = c.split('-');
    String sigB64;
    String expiry = '';
    if (parts.length == 2) {
      sigB64 = parts[1];
    } else if (parts.length == 3 &&
        parts[2].length == 4 &&
        int.tryParse(parts[2]) != null) {
      sigB64 = parts[1];
      expiry = parts[2];
    } else {
      return const RegCheck(false, '激活码格式不对');
    }

    final msg = regMessage(machineCode, expiry);
    bool ok;
    try {
      final pub = SimplePublicKey(_decodeB64(publicKeyBase64),
          type: KeyPairType.ed25519);
      ok = await Ed25519().verify(
        utf8.encode(msg),
        signature: Signature(_decodeB64(sigB64), publicKey: pub),
      );
    } catch (_) {
      return const RegCheck(false, '激活码无法解析');
    }
    if (!ok) {
      return const RegCheck(false, '这个激活码不是本机的(机器码不匹配)');
    }
    if (expiry.isNotEmpty) {
      final yy = int.parse(expiry.substring(0, 2));
      final mm = int.parse(expiry.substring(2, 4));
      if (mm < 1 || mm > 12) return const RegCheck(false, '激活码过期信息不对');
      final expireAt = DateTime(2000 + yy, mm, 1);
      if (!DateTime.now().isBefore(expireAt)) {
        return RegCheck(false, '激活码已于 ${2000 + yy}-$mm 到期', expiry);
      }
    }
    return RegCheck(true, '激活成功', expiry);
  }
}
