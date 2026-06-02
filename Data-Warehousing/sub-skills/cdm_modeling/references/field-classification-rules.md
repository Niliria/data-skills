# 字段分类与类型映射规则

本文件从旧 `rules/type_mapping.yaml` 和 `rules/naming_rules.yaml` 提炼，用于指导 AI 读取上游 ODS 元数据解析文档时如何理解字段语义。

## 1. 字段分类优先级

字段分类优先使用上游文档中的显式 `classification`。缺失时按以下优先级辅助判断：

1. 技术字段和技术时间
2. 业务键、代理键、外键
3. 业务时间
4. 度量字段
5. 分区字段
6. 维度属性
7. 忽略字段

不得仅凭字段后缀把字段直接纳入最终模型；命名推断只能产生告警或候选。

## 2. 业务键

识别依据：
- 字段说明包含 `主键`、`业务键`、`primary key`、`唯一标识`
- 字段名为 `{entity}_id` 或 `{entity}_code`
- 上游文档明确标记 `business_key`

使用规则：
- DIM 中作为 SCD JOIN 键。
- DWD 中作为源系统对账键或粒度键。
- 缺失时使用 `{entity}_id` 兜底并写入校验告警。

## 3. 外键

识别依据：
- 上游文档明确标记 `foreign_key`
- 字段说明包含 `外键`、`关联`、`references`
- 字段带有 `dimension` 归属

使用规则：
- DWD 中转换为 `{dimension}_sk`。
- DIM 中通常不保留外键关系，除非是层级维度属性。
- 外键缺失容忍策略应在上游总线矩阵或校验报告中说明。

## 4. 度量

识别依据：
- 上游总线矩阵文档的 `measures`
- 上游 ODS 元数据解析文档明确标记 `measure`
- 字段说明包含 `度量`、`可加总`、`metric`

常见命名：
- 金额类：`*_amount`、`*_price`、`*_cost`、`*_fee`、`*_revenue`
- 数量类：`*_qty`、`*_quantity`、`*_count`、`*_num`
- 比率类：`*_rate`、`*_ratio`、`*_percent`

聚合建议：
- 金额、数量、次数默认 `SUM`
- 比率、单价默认 `AVG`
- 余额、库存默认半可加，不应跨时间直接求和

## 5. 维度属性

识别依据：
- 上游文档明确标记 `dimension_attribute`
- 字段说明表明描述实体属性
- 字段名包含 `_name`、`_desc`、`_type`、`_status`、`_level`、`_grade`

使用规则：
- DIM 属性用于筛选、分组、钻取。
- 技术字段、废弃字段、临时字段不得作为维度属性。
- 低基数字段可作为 junk dimension 候选，但不应自动生成独立 DIM。

## 6. 时间字段

分类：
- 业务时间：`event_time`、`trade_time`、`order_time`、`pay_time`
- 创建时间：`create_time`、`created_at`、`gmt_create`
- 更新时间：`update_time`、`updated_at`、`modify_time`、`gmt_modified`
- 生效失效：`effective_date`、`expiry_date`、`begin_time`、`end_time`

使用规则：
- 业务时间用于 DWD 事件时间和日期维度关联。
- 更新时间可作为 SCD Type II 的辅助判断证据。
- 技术处理时间只用于审计，不进入业务分析字段。

## 7. 分区字段

统一使用：

```text
pt STRING COMMENT '分区日期 (YYYY-MM-DD)'
```

识别依据：
- 字段名为 `pt`
- 字段名包含 `partition_date`、`yyyymmdd`

## 8. 忽略字段

以下字段不得进入 DIM/DWD 业务字段：

- `_etl_*`、`etl_*`
- `_sys_*`
- `tmp_*`、`temp_*`
- 注释包含 `废弃`、`deprecated`、`不使用`

## 9. 类型标准化

| 来源类型 | 目标类型 |
|----------|----------|
| `TINYINT` / `SMALLINT` / `INT` / `INTEGER` | `INT` |
| `BIGINT` / `LONG` | `BIGINT` |
| `DECIMAL` / `NUMERIC` | `DECIMAL(18,2)` |
| `FLOAT` | `FLOAT` |
| `DOUBLE` | `DOUBLE` |
| `CHAR` / `VARCHAR` / `TEXT` / `STRING` | `STRING` |
| `DATE` / `DATETIME` / `TIME` | `STRING` |
| `TIMESTAMP` | `TIMESTAMP` |
| `BOOLEAN` | `INT` |

## 10. 数据质量检查

建议检查：

- 业务键非空且在维度粒度内唯一。
- 外键 JOIN 缺失率可解释。
- 金额字段范围合理。
- 比例字段范围在 `[0, 100]` 或 `[0, 1]`，按业务口径确认。
- 标志字段取值限定为 `0/1` 或明确枚举。
