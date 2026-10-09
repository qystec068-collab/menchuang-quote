/// 试用期:本地记录,7 天。
///
/// 只防"不小心一直用",不追求绝对防破解(那需要联网校验)。
/// 但有一条必须防:**把手机日期往回拨**。
/// 做法:每次启动都把"见过的最大时间"记下来;
///       判断剩余天数时用 max(当前时间, 已见最大时间),
///       回拨只会让试用更快结束,不会变多。
library;

import 'license_config.dart';

/// 允许的时间误差(NTP 校时/时区切换),超过才判定为回拨
const Duration kClockTolerance = Duration(minutes: 5);

class TrialState {
  /// 首次启动时间
  final DateTime firstRun;

  /// 见过的最大时间(每次启动/退出都会刷新)
  final DateTime lastSeen;

  /// 是否已激活(激活后不看试用期)
  final bool licensed;

  const TrialState({
    required this.firstRun,
    required this.lastSeen,
    this.licensed = false,
  });

  /// 全新安装:第一次启动
  factory TrialState.fresh(DateTime now) =>
      TrialState(firstRun: now, lastSeen: now);

  /// 计时参考点:取当前时间和"已见最大时间"里较晚的那个 → 回拨无效
  DateTime reference(DateTime now) => now.isAfter(lastSeen) ? now : lastSeen;

  /// 已经用了几天(向下取整)
  int daysUsed(DateTime now) =>
      reference(now).difference(firstRun).inDays;

  /// 剩余天数(已激活返回一个大值,调用方自己判断 licensed)
  int daysLeft(DateTime now) {
    if (licensed) return 9999;
    final left = kTrialDays - daysUsed(now);
    return left < 0 ? 0 : left;
  }

  bool isExpired(DateTime now) => !licensed && daysUsed(now) >= kTrialDays;

  /// 检测到用户把时间往回调了吗(容差 5 分钟)
  bool clockRollback(DateTime now) =>
      now.isBefore(lastSeen.subtract(kClockTolerance));

  /// 启动时刷新:推进 lastSeen
  TrialState sawNow(DateTime now) => TrialState(
        firstRun: firstRun,
        lastSeen: now.isAfter(lastSeen) ? now : lastSeen,
        licensed: licensed,
      );

  /// 激活
  TrialState activate() =>
      TrialState(firstRun: firstRun, lastSeen: lastSeen, licensed: true);

  Map<String, dynamic> toJson() => {
        'firstRun': firstRun.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
        'licensed': licensed,
      };

  factory TrialState.fromJson(Map<String, dynamic> j) => TrialState(
        firstRun:
            DateTime.tryParse((j['firstRun'] ?? '').toString()) ?? DateTime.now(),
        lastSeen:
            DateTime.tryParse((j['lastSeen'] ?? '').toString()) ?? DateTime.now(),
        licensed: j['licensed'] == true,
      );

  /// 给界面用的一句话状态
  String describe(DateTime now) {
    if (licensed) return '已激活 · 终身使用';
    if (isExpired(now)) return '试用已结束';
    if (clockRollback(now)) return '检测到手机时间被改过,请调回自动时间';
    return '试用期剩 ${daysLeft(now)} 天';
  }
}
