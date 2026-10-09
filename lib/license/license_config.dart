/// 授权相关的固定配置(由老板在打包前改)
library;

/// 终身版售价(元)。激活页和收款页都用它。
const double kAppPriceYuan = 380;

/// 试用天数
const int kTrialDays = 7;

/// 付款后联系谁(激活页提示用)
const String kContactHint = '付款备注里写上机器码,付完把截图发我';

/// 公钥占位提醒(BUILD 前必须替换)
const String kPublicKeyPlaceholder = 'FILL_ME_WITH_PUBLIC_KEY';
