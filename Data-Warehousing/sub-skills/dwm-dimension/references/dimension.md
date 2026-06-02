# 确认维度

从每个业务过程中提取维度引用，收敛一致性维度，确认退化维度与低基数离散属性，确定 SCD 策略。

---

## 1. 输入

| 输入项 | 来源 | 过滤条件 | 用途 |
|--------|------|---------|------|
| `dwm_bp_business_process` | dwm-business-process | 全量 | 业务过程清单与粒度声明 |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `字段角色='foreign_key'` | 维度外键引用（含 `外键引用`） |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `字段角色='low_cardinality'` | 低基数离散属性候选（Junk Dimension 候选） |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `字段角色='primary_key'` | 维度表粒度键候选 |
| `dwm_bp_subject_area` | dwm-business-process | 全量 | 主题域定义 |

---

## 2. 实施步骤

### 2.1 硬门禁：技术字段排除

在所有维度提取操作前先执行技术字段剔除：

**`field_role IN ('tech_meta')` 的字段全部排除**，不得进入维度候选池。

这包括：ETL 时间戳、同步标记、分区字段（`dt`）、操作类型、批次 ID 等。排除后保留技术相关画像属性供审计，但不建模。

### 2.2 退化维度判定

退化维度是位于事实表中的交易凭证/业务单号，不单独建维表，保留在事实表供追踪。

判定规则（需满足全部条件）：
1. 字段所在表为 `dwm_bp_business_process` 中的业务过程表
2. `field_role` 为 `primary_key` 且 `is_surrogate='N'`（天然业务键），或字段命名含有业务单号语义（`*_no`、`*_order_id`、`invoice_*`）
3. 无需以此字段为主键单独建维表分析其属性

判定为退化维度的字段不进入 `dwm_dim_spec`，在事实表中保留为 `degenerate_dim` 角色。

### 2.3 提取维度外键引用

对每个业务过程（`dwm_bp_business_process` 中的每一行）：

1. 从 `all_tables_metadata.xlsx WHERE 字段角色='foreign_key'` 提取该事实表的外键字段
2. 通过 `外键引用` 关联到维度候选表（从 `all_tables_metadata.xlsx` FK 被引用关系识别）
3. 补充"是否必选维度"与"缺失容忍策略"（如匿名用户→ UNKNOWN 填充）
4. 提取退化维度字段（按 §2.2 规则）
5. 提取低基数离散属性（`field_role='low_cardinality'`），判断是独立 Junk Dimension 还是内联属性
6. 汇总分析结果，仅将需建 DIM 表的维度注册到 `dwm_dim_spec`

### 2.4 收敛一致性维度

1. 汇总所有业务过程外键，去重得到一致性维度候选列表
2. 为每个维度键确定唯一维表来源（从 `all_tables_metadata.xlsx` FK 被引用关系识别维度候选表）
3. 执行一致性检查：命名、口径、编码、值域、JOIN 命中率
4. 退化维度与低基数离散属性由 dwm-business-process 从 `all_tables_metadata.xlsx` 推导，**不纳入** `dwm_dim_spec`
5. 仅注册需建 DIM 表的一致性维度

### 2.5 确认 SCD 策略

对 `dwm_dim_spec` 中的每个一致性维度，检查其属性字段中是否有可能随时间变化的属性（用户级别、组织名称等）：

| SCD 类型 | 策略 | 适用场景 |
|---------|------|---------|
| `SCD1` | 覆盖写入 | 无需保留历史，直接更新 |
| `SCD2` | 追加行 | 需保留完整历史变化轨迹（`dw_start_date`/`dw_end_date`/`dw_is_current` 由 ETL 生成） |
| `SCD3` | 追加列 | 仅保留前一个值（`prev_xxx` 字段） |

规则：
- 同一维度内不同属性可有不同 SCD 类型（如 `user_name` 用 SCD1，`user_level` 用 SCD2）
- `scd_strategy` 取该维度中最严格的类型
- `scd_columns` 按 `类型:字段` 格式分组记录，如 `SCD2:user_level,org_name;SCD1:phone`
- 无变化属性的维度 `scd_strategy='-'`，`scd_columns` 留空

> 如需编写一致性校验 SQL 或 SCD 维度加工脚本，use context7 获取对应 SparkSQL/HiveQL 的最新文档。

---

## 3. 产出物

### 3.1 `dwm_dim_spec`（维度表建设清单）

一行一个字段（合并原 registry + table_spec）。产出格式：CSV，路径 `output/dwm-bus-matrix/`。

| 字段名 | 中文说明 | 是否必填 | 取值/规则 |
|--------|----------|:--:|---------|
| 维度表名 | DIM 表名 | 是 | 命名格式：`dim_xxx` |
| 维度中文名称 | 中文名 | 是 | 如"用户维度" |
| 维度描述 | 一句话业务含义 | 是 | 描述维度用途 |
| 来源ODS表 | 源维表名 | 是 | 从 `all_tables_metadata.xlsx` FK 被引用关系识别 |
| SCD策略 | 表级 SCD 类型 | 是 | 取最严格类型：`SCD1` / `SCD2` / `SCD3` / `-` |
| 是否一致性维度 | 跨事实表共享 | 是 | `Y` / `N` |
| 跨事实表共享范围 | 共享说明 | 条件 | `是否一致性维度='Y'` 时必填，列出关联的业务过程英文名称 |
| 字段名 | DIM 层字段命名 | 是 | 来自 ODS 字段名 |
| 字段中文说明 | 字段注释 | 是 | 来自 `all_tables_metadata.xlsx` 的 `字段注释填充` |
| 字段角色 | 字段在维度表中的角色 | 是 | `pk`（业务键）/ `bk`（备选键）/ `attribute` |
| SCD类型 | 字段级 SCD 类型 | 条件 | `字段角色='attribute'` 时必填：`SCD1` / `SCD2` / `SCD3` / `-` |
| 来源ODS字段 | ODS 字段名 | 是 | 来自 `all_tables_metadata.xlsx` 的 `字段名` |
| ODS数据类型 | 字段数据类型 | 是 | 来自 `all_tables_metadata.xlsx` 的 `数据类型` |
| 字段排序 | 整数 | 是 | 按 `pk→bk→attribute` |
| 备注 | 额外说明 | 否 | |
| 更新时间 | 最近修改时间 | 是 | ISO 日期 |

> 主键：`维度表名 + 字段名`
>
> SCD 管理字段（`dw_start_date`/`dw_end_date`/`dw_is_current`）**不纳入本表**，由 DIM 建设阶段 ETL 自动生成。
>
> **说明**：维度引用关系（哪个事实表引用哪个维度）由总线矩阵表达，不在本表中体现。

---

## 4. 验收标准

1. `dwm_dim_spec` 中每个维度有唯一口径定义，跨事实无冲突
2. 维度候选池已剔除技术属性字段（`field_role='tech_meta'` 占比 = 0）
3. 每个一致性维度中的 SCD 属性字段已确认 SCD 类型
4. 每个业务过程至少有一个核心分析维度（可从 `all_tables_metadata.xlsx` FK 关系验证）

---

## 5. 与下游衔接

| 下游 Skill | 消费数据 | 用途 |
|-----------|---------|------|
| dwm-matrix | `dwm_dim_spec` | 总线矩阵列头（去重提取唯一维度） |
| cdm_modeling | `dwm_dim_spec` | 生成 DIM DDL + ETL SQL |

---

## 6. 代码规范

### CSV 工具

```python
import sys
sys.path.insert(0, ".claude/sub-skills/dwm-shared/scripts")
from read_csv import read_csv
from write_csv import write_csv
```

### 读取上游产出示例

```python
# 读取业务过程清单
business_processes = read_csv("output/dwm-bus-matrix/dwm_bp_business_process.csv")

# 读取字段元数据（外键画像）
from read_xlsx import read_xlsx
field_metadata = read_xlsx("output/metadata_parse/all_tables_metadata.xlsx")
fk_fields = [f for f in field_metadata if f["字段角色"] == "foreign_key"]

# 读取低基数候选
lc_fields = [f for f in field_metadata if f["字段角色"] == "low_cardinality"]
```

### 一致性检查 SQL

> 如需编写跨事实表维度一致性校验脚本，use context7 获取 SQL 方言文档。

```sql
-- 同一维度键在不同事实表中 JOIN 命中率对比
SELECT
  a.fact_table,
  a.dimension_column,
  a.ref_table,
  COUNT(1) AS ref_cnt,
  SUM(CASE WHEN b.ref_col IS NULL THEN 1 ELSE 0 END) AS miss_cnt,
  ROUND(SUM(CASE WHEN b.ref_col IS NULL THEN 1 ELSE 0 END) / COUNT(1), 4) AS miss_rate
FROM fact_ods_table a
LEFT JOIN dim_ods_table b ON a.fk_col = b.ref_col
WHERE a.fk_col IS NOT NULL
  AND a.dt = '${check_dt}'
GROUP BY a.fact_table, a.dimension_column, a.ref_table;
```
