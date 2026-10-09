# 门窗计价(安卓)

给焊接 / 铝合金门窗师傅用的手机计价工具。**简略而不简单**:界面只留大按钮、大数字,
底下是一套可配置的计价引擎 —— 每个师傅的型材单价、附加项、抹零规矩都自己改,不用改代码。

## 已确认的口径(2026-10-08 与鹏二)

- 面积按**洞口尺寸**宽×高 计算(mm 输入,㎡ 计价)
- **不足平方不设死规则**:师傅可手动输入计价面积覆盖(`areaOverridePerPiece`),
  想按 1.00㎡ 算就按 1.00㎡ 算
- **型材可选**(价格表里的 `series`,下拉选)
- 界面走 **Flutter**

## 目录

```
lib/pricing/money.dart         取整/抹零(四舍五入到分;向下抹到角/元/十元)
lib/pricing/models.dart        数据模型:Series / ExtraDef / QuoteInput / QuoteResult
lib/pricing/price_table.dart   价格表(JSON 读写,零依赖)
lib/pricing/engine.dart        计价引擎(纯逻辑,无 IO / 无 UI)
config/price_table.sample.json 示例价格表(单价是占位值,要换成真实的)
bin/selfcheck.dart             自检:跑几组真实尺寸,跟手算比对
```

## 跑自检

```
cd menchuang-quote
dart bin/selfcheck.dart
```

## 计价顺序

型材 → 非比例附加项 → 比例附加项(按小计) → 手动调整 → 整单抹零

附加项支持 6 种计费方式:`元/㎡`、`元/扇`、`元/樘`、`元/层`、`元/单`(整单固定)、`%`(按比例)。

## 待办

- [ ] 拿真实型材单价、附加项名目替掉示例值
- [ ] Flutter 界面:①快速计价 ②订单历史/统计 ③价格表设置
- [ ] 订单本地存储(SQLite 或 JSON 文件,离线优先)
- [ ] 蓝牙激光测距仪接入(先支持"蓝牙键盘模式"型号,APP 侧零改动)
- [ ] 报价单导出:文字(发微信)/ 图片 / Excel
