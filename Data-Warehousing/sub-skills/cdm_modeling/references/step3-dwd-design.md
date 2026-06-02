# 第三步：DWD 明细事实设计

根据 DWM DWD spec 中的业务过程生成 DWD 明细事实表设计。DWD 的粒度、维度引用和度量以 DWD spec 为权威来源。

OneData 口径下，DWD 是明细数据层：保持业务过程原子粒度，承接事实明细清洗、标准化和维度键关联；不把维度描述属性打宽进 DWD。

执行本步骤时同时参考：
- `references/mandatory-modeling-rules.md`
- `references/field-classification-rules.md`
- `references/scd-lifecycle-rules.md`
- `references/anti-patterns.md`

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `processes` | 第一步统一上下文 | 业务过程、粒度、维度引用、度量、源表 |
| `dim_designs` | 第二步输出 | 维度业务键、代理键、SCD 类型、维度表名 |
| `modeling.default_fact_type` | 配置 | 无显式事实类型时默认值 |

## 2. 实施步骤

1. 为每个业务过程生成一张 DWD 明细事实表。
2. 优先保留 DWD spec 中的 `DWD表名`；缺失时才按 `dwd_{domain}_{business_process}_{di|df}` 生成。
3. 粒度键来自 DWD spec 中的 `grain_key` 字段和 `粒度声明`。
4. `关联DIM表` 非空的字段作为维度引用，不强依赖 `字段角色=fk`。
5. `关联DIM业务键` 可选；缺失时默认使用 `DWD字段名`，再缺失时使用 `来源ODS字段`。
6. DWD ETL join DIM 只取维度代理键 `{entity}_sk`，不展开 DIM 属性。
7. 度量字段来自 DWD spec 中 `字段角色=measure` 的字段，保留 `source_field`、`type`、`aggregation`。
8. 日期维度不自动补充；需要日期维度时由上游 DWD spec 显式给出。

## 3. 事实类型

| 类型 | 适用场景 | 说明 |
|------|----------|------|
| `transaction` | 一行一笔业务事件 | 订单、支付、退款 |
| `periodic_snapshot` | 固定周期状态截面 | 日库存、月余额 |
| `accumulating_snapshot` | 一行跟踪生命周期 | 订单履约、审批流程 |
| `factless` | 无数值度量的行为事实 | 登录、曝光、签到 |

## 4. 产出物

### DWD 设计字典

| 字段 | 说明 |
|------|------|
| `table_name` | 事实表名 |
| `domain` | 数据域英文名 |
| `business_process` | 业务过程英文名 |
| `grain` | 事实表粒度 |
| `fact_type` | 事实类型 |
| `dimensions` | 维度实体列表 |
| `dimension_refs` | 维度实体与业务键映射 |
| `measures` | 度量列表 |
| `source_tables` | 来源表列表 |

### DWD 表字段口径

DWD 默认保留：

- 粒度键：标识事实行的业务主键或联合键。
- 维度代理键：如 `user_sk`、`shop_sk`、`sku_sk`。
- 事实描述字段：退化维度、状态、低基数字段等可直接服务明细追踪的字段。
- 度量字段：金额、数量、库存等事实数值。
- 审计字段：`etl_insert_time`、`etl_update_time`、`source_system`、`pt`。

DWD 默认不保留：

- 用户名、手机号、门店名、商品名、品类名等 DIM 描述属性。
- 面向查询便利的大宽表字段。
- 汇总指标、派生主题指标和应用层口径字段。

## 5. 验收标准

1. 每个 DWD 必须有明确粒度。
2. 每个非 `factless` DWD 至少有一个度量。
3. 每个非空 `关联DIM表` 必须能映射到已生成的 DIM；无法映射时写入校验错误。
4. 度量必须包含字段名、来源字段、类型和聚合建议。
5. DDL/ETL 渲染后不得残留 Jinja 占位符。
