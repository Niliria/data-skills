# 第二步：DIM 维度设计

根据统一建模上下文生成 DIM 维度表设计。DIM 设计必须优先消费上游 ODS 元数据解析文档，不允许回退到硬编码属性。

执行本步骤时同时参考：
- `references/mandatory-modeling-rules.md`
- `references/field-classification-rules.md`
- `references/scd-lifecycle-rules.md`
- `references/anti-patterns.md`

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `dimensions` | 第一步统一上下文 | 维度清单、业务键、属性、源表 |
| `ods_tables` | 第一步统一上下文 | 字段类型、字段说明、时间字段 |
| `modeling.default_scd_type` | 配置 | 无显式策略时的默认 SCD |

## 2. 实施步骤

1. 为每个一致性维度生成 `dim_{entity}` 表名。
2. 确认业务键：优先使用上游字段，缺失时使用 `{entity}_id` 并记录告警。
3. 收集维度属性：只使用 `dimension_attribute` 或同义分类字段。
4. 判定 SCD 策略：
   - 日期/时间维度使用 SCD Type I。
   - 源表存在 `update_time`、`modified_time`、`version` 时优先 SCD Type II。
   - 上游显式指定策略时覆盖自动推断。
5. 组织 DDL/ETL 模板上下文。

## 3. 产出物

### DIM 设计字典

| 字段 | 说明 |
|------|------|
| `table_name` | 维度表名，如 `dim_customer` |
| `entity` | 英文实体名，如 `customer` |
| `business_key` | 业务键，如 `customer_id` |
| `attributes` | 维度属性字段列表 |
| `scd_type` | `1` / `2` / `3` |
| `source_tables` | 来源表列表 |

### DDL 输出

路径：`output/cdm-modeling/ddl/dim/`

文件名：`dim_{entity}_scd{scd_type}.sql`

## 4. 验收标准

1. 每个 DIM 必须有业务键。
2. 非日期维度至少应有一个维度属性；缺失时写入校验告警。
3. 代理键命名必须为 `{entity}_sk`。
4. SCD Type II 必须包含 `begin_date`、`end_date`、`is_active`。
5. DDL 渲染后不得残留 Jinja 占位符。
