# 选择业务过程 + 声明粒度 + 确认事实

通过表关系网识别业务过程（总线矩阵的行），同步完成主题域定义、粒度声明、事实表类型判定与度量归属。

---

## 1. 输入

| 输入项 | 来源 | 过滤条件 | 用途 |
|--------|------|---------|------|
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `字段角色 IN ('primary_key','foreign_key','business_time','numeric_measure')` | 画表关系图的核心证据 |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `字段角色='foreign_key'` | 外键关系连线（含 `外键引用`） |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | `主键='Y'` 或 `外键='Y'` | 源系统约束，最高优先级证据 |
| `output/ods_generator/all_tables_metadata_ods.xlsx` | 上游 ODS 生成器 | 全量 | ODS 表清单 |

---

## 2. 接口数据无主键降级策略

接口数据（API/文件/消息队列）通常无 PK/FK 约束，元数据完整度等级为"缺失/部分"时，在本步骤通过数据画像补充证据。

| 场景 | 降级处理 | 操作方法 |
|------|---------|---------|
| 无主键 | 画像发现天然业务键 | 候选列 `distinct_rate ≥ 99.9%` + `null_rate ≤ 1%` → 业务键候选 |
| 无外键约束 | JOIN 命中率发现关系 | 候选字段 LEFT JOIN 目标表，`miss_rate ≤ 1%` → 外键候选 |
| 联合键才唯一 | 逐步增加组合字段 | 找满足唯一性的最小字段集 → 粒度键 |
| 同名字段无约束 | 值域匹配作弱证据 | 类型一致 + 值域重叠度 > 95% → 候选关系，需人工确认 |

> 如需编写画像 SQL（唯一率分析、JOIN 命中率分析），use context7 获取对应 SQL 方言的最新文档。

**降级分析 SQL 模板**：

```sql
-- 唯一率分析（发现天然业务键）
SELECT
  COUNT(*) AS total,
  COUNT(DISTINCT candidate_col) AS distinct_cnt,
  ROUND(COUNT(DISTINCT candidate_col) / COUNT(*), 6) AS distinct_rate,
  SUM(CASE WHEN candidate_col IS NULL THEN 1 ELSE 0 END) AS null_cnt
FROM ods_xxx
WHERE dt BETWEEN '${start_dt}' AND '${end_dt}';

-- JOIN 命中率分析（发现外键关系）
SELECT
  COUNT(1) AS ref_cnt,
  SUM(CASE WHEN b.target_col IS NULL THEN 1 ELSE 0 END) AS miss_cnt,
  ROUND(SUM(CASE WHEN b.target_col IS NULL THEN 1 ELSE 0 END) / COUNT(1), 4) AS miss_rate
FROM ods_source a
LEFT JOIN ods_target b ON a.source_col = b.target_col
WHERE a.source_col IS NOT NULL
  AND a.dt BETWEEN '${start_dt}' AND '${end_dt}';
```

---

## 3. 实施步骤

### 3.1 画表关系图（手段，非独立交付）

1. 以 `all_tables_metadata.xlsx WHERE 字段角色='foreign_key'` 为主线画连线（不是仅靠同名字段）
2. 以 `all_tables_metadata.xlsx WHERE 主键='Y' OR 外键='Y'` 补充强证据
3. 对同名 ID 做补充候选，再做语义核验（实体含义、值域、JOIN 命中率）
4. 区分角色：
   - **被引用为主、实体属性稳定**：维度候选（本步不做维度注册，交由 dwm-dimension）
   - **引用多个实体且承载行为**：事实候选 → 进入业务过程识别
5. 接口数据补充：对元数据标记为"缺失/部分"的数据源，通过 §2 降级策略补充外键关系

### 3.2 识别事实表（业务过程候选）

按四类证据综合评估，判定一张表是否承载业务过程：

| 证据类型 | 说明 | 判定方式 |
|---------|------|---------|
| **时间证据** | 表中存在 `字段角色=business_time` 的字段 | 事实候选 |
| **度量证据** | 表中存在 `字段角色=numeric_measure` 且有多个 | 事实候选 |
| **关联证据** | 表中存在 ≥ 2 个 `字段角色=foreign_key` | 事实候选 |
| **增长证据** | `sync_mode=INCR` + 行数远大于其他表 | 事实候选 |

判定规则：
- 满足 ≥ 2 条事实证据 → 代表一个业务过程，进入业务过程清单
- **无数值但有行为轨迹的表** → factless 事实表（领券、浏览、签到等），同样进入业务过程清单
- 不满足事实条件的表不纳入本步产出（维度/配置/排除由 dwm-dimension 或其他步骤处理）

### 3.3 识别业务过程并归组主题域

1. 对每张事实表，形成标准业务过程命名（如：下单、支付、退款、浏览）
2. **主题域定义**（先底向上，再顶向下）：
   - 自底向上：按业务过程的实体关系自然聚类
   - 自顶向下：对照企业价值链校验，每个主题域必须有：中文名、英文名、编码（2~3 大写字母）、描述
   - 产出 `dwm_bp_subject_area`
3. **归组**：将每个业务过程归入已定义的主题域（通过 `主题域编码`）
4. 约束：一个业务过程只能归属一个主题域

### 3.4 声明粒度

1. 按业务过程写一句话粒度声明（例：一行一笔支付交易）
2. 识别承载粒度的键：主键或联合键
3. 做唯一性校验：`COUNT(*)` 对比 `COUNT(DISTINCT 粒度键)`
   - 单列粒度键：直接从 `all_tables_metadata.xlsx` 的 `字段空值率` 验证，无需查数据库
   - 联合粒度键：需查数据库执行联合唯一性校验
4. 若不唯一 → 回退修正：补联合键或下钻到更细明细层
5. 接口数据无主键时：通过 §2 唯一率分析发现天然键或联合键作为粒度键

> 如需编写粒度唯一性批量校验脚本，use context7 获取 SQL 方言文档。

**粒度唯一性校验 SQL**（仅联合键需要）：

```sql
SELECT
  COUNT(*) AS total_row_cnt,
  COUNT(DISTINCT CONCAT(${grain_key_col1}, '-', ${grain_key_col2})) AS grain_distinct_cnt
FROM ${ods_table_name}
WHERE dt = '${check_dt}';
-- total_row_cnt = grain_distinct_cnt → 通过
```

### 3.5 确定事实表类型

对每个业务过程确认事实表类型：

| 类型 | fact_type 编码 | 判定依据 | 典型场景 |
|------|---------------|---------|---------|
| 事务事实表 | `transaction` | 一行一笔业务事件，不可变 | 下单、支付、退款 |
| 周期快照事实表 | `periodic_snapshot` | 按固定周期截面记录状态 | 日库存、月账户余额 |
| 累积快照事实表 | `accumulating_snapshot` | 一行跟踪业务全生命周期，多个里程碑时间 | 订单履约 |
| 无事实事实表 | `factless` | 无度量但有业务行为记录 | 用户浏览、签到 |

判定规则：
1. 有明确业务事件时间 + 事件后行不变 → 事务事实表
2. 无明确事件、按周期截面 + 半可加度量 → 周期快照事实表
3. 一行有多个里程碑时间、行随流程推进更新 → 累积快照事实表
4. 无度量但有业务行为记录 → 无事实事实表

### 3.6 确定度量

1. 从 `all_tables_metadata.xlsx WHERE 字段角色='numeric_measure'` 获取度量候选
2. 逐个归属到对应事实表
3. 判定度量可加性类型：

| 度量类型 | metric_type | 判定依据 |
|---------|------------|---------|
| 可加度量 | `可加度量` | 可沿所有维度安全求和（如 amount, qty） |
| 半可加度量 | `半可加度量` | 仅在部分维度可加，通常不可跨时间累加（如 balance, inventory） |
| 不可加度量 | `不可加度量` | 不可求和，宜均值/比率/去重（如 rate, unit_price） |

4. 确认每个度量的 `agg_suggest` 与事实表类型匹配：

| 事实表类型 | 度量特征 |
|-----------|---------|
| `transaction` | 度量通常可加（sum） |
| `periodic_snapshot` | 度量通常半可加（不可跨时间 sum） |
| `accumulating_snapshot` | 里程碑间时间差、状态标志为典型度量 |
| `factless` | 无度量，仅有隐含计数 |

5. 识别派生事实（如 `利润 = 收入 - 成本`），标注计算逻辑，决定存储还是运行时计算
6. 产出 `dwm_dwd_fact_spec`（度量信息合并在字段角色='measure' 的行中）

### 3.7 度量可加性校验

| 校验项 | 规则 | 失败处理 |
|--------|-----|---------|
| 可加度量在事务表中 | 可跨所有维度 sum | 通过 |
| 可加度量在快照表中 | 需确认是否为增量而非余额 | 修正为半可加 |
| 半可加度量在事务表中 | 通常不应出现 | 重新检查是否为余额类 |
| 不可加度量的 agg_suggest | 不应为 sum | 修正 agg_suggest |

---

## 4. 产出物

### 4.1 `dwm_bp_business_process`（业务过程清单）

一行一个业务过程（仅事实表）。产出格式：CSV，路径 `output/dwm-bus-matrix/`。

| 字段名 | 中文说明 | 是否必填 | 取值/规则 |
|--------|----------|:--:|---------|
| 业务过程中文名称 | 业务过程中文名 | 是 | 如"下单"、"支付"、"退款" |
| 业务过程英文名称 | 业务过程标准命名 | 是 | 如 `place_order`、`payment`、`refund` |
| 业务过程描述 | 一句话描述 | 是 | 描述该业务过程的业务含义 |
| 主题域编码 | 所属主题域 | 是 | 关联 `dwm_bp_subject_area`，如 `TRD` |
| 主题域中文名称 | 主题域中文名 | 是 | 冗余字段，方便阅读，如"交易域" |
| 涉及ODS表 | 对应的源 ODS 表名 | 是 | ODS 表名 |
| 粒度声明 | 一句话粒度 | 是 | 如"一行一笔支付交易" |
| 粒度键 | 粒度键字段 | 是 | 逗号分隔 |
| 事实表类型 | Kimball 事实表类型 | 是 | `transaction` / `periodic_snapshot` / `accumulating_snapshot` / `factless` |
| 类型判定依据 | 判定逻辑 | 是 | 简述判定逻辑 |
| 更新时间 | 最近修改时间 | 是 | ISO 日期 |

> 主键：`涉及ODS表`

### 4.2 `dwm_bp_subject_area`（主题域注册表）

一行一个主题域。产出格式：CSV，路径 `output/dwm-bus-matrix/`。

| 字段名 | 中文说明 | 是否必填 | 取值/规则 |
|--------|----------|:--:|---------|
| 主题域编码 | 编码 | 是 | 主键，2~3 大写字母，如 `TRD` |
| 中文名称 | 中文名 | 是 | 如"交易域" |
| 英文名称 | 英文名 | 是 | 如"Trade" |
| 描述 | 业务范围 | 是 | 一句话业务范围 |
| 业务范围 | 核心活动 | 是 | 核心业务活动，逗号分隔 |
| 更新时间 | 修改时间 | 是 | ISO 日期 |

> 主键：`主题域编码`
>
> **命名约束**：`主题域编码` 全局唯一，一经定义不可随意变更（下游 DWD/DWS/ADS 表名依赖此缩写，统一转小写使用）。
>
> **设计原则**：主题域数量控制在 5~10 个。

### 4.3 `dwm_dwd_fact_spec`（DWD 事实表建设清单）

一行一个字段。产出格式：CSV，路径 `output/dwm-bus-matrix/`。

对每个业务过程（= 一张 DWD 事实表），汇总字段级建设规格：
1. **DWD 表名**：`dwd_{主题域编码小写}_{业务过程英文名称}_{df/di}`
2. **字段汇总顺序**：粒度键 → 维度外键 → 退化维度 → 低基数属性 → 度量 → 业务时间

| 字段名 | 中文说明 | 是否必填 | 取值/规则 |
|--------|----------|:--:|---------|
| DWD表名 | DWD 表名 | 是 | `dwd_{主题域编码}_{业务过程标准名}_{df/di}` |
| 事实表中文名称 | 事实表中文名 | 是 | 来自 `dwm_bp_business_process.业务过程中文名称` |
| 主题域编码 | 所属主题域 | 是 | 关联 `dwm_bp_subject_area` |
| 业务过程标准名 | 英文标识 | 是 | 来自 `dwm_bp_business_process.业务过程英文名称` |
| 事实表类型 | Kimball 事实表类型 | 是 | `transaction` / `periodic_snapshot` / `accumulating_snapshot` / `factless` |
| 粒度声明 | 自然语言描述 | 是 | 来自 `dwm_bp_business_process.粒度声明` |
| 字段名 | DWD 层字段命名 | 是 | 来自 ODS 字段名 |
| 字段中文说明 | 字段注释 | 是 | 来自 `all_tables_metadata.xlsx` 的 `字段注释填充` |
| 字段角色 | 字段在事实表中的角色 | 是 | `grain_key` / `fk` / `degenerate_dim` / `low_card_attr` / `measure` / `business_time` |
| 来源ODS表 | ODS 表名 | 是 | 来自 `all_tables_metadata.xlsx` 的 `表名` |
| 来源ODS字段 | ODS 字段名 | 是 | 来自 `all_tables_metadata.xlsx` 的 `字段名` |
| ODS数据类型 | 字段数据类型 | 是 | 来自 `all_tables_metadata.xlsx` 的 `数据类型` |
| 度量类型 | 可加性分类 | 条件 | `字段角色='measure'` 时必填：`可加度量` / `半可加度量` / `不可加度量` |
| 聚合建议 | 推荐聚合函数 | 条件 | `字段角色='measure'` 时必填 |
| 度量单位 | 单位 | 条件 | `字段角色='measure'` 时必填 |
| 是否派生 | Y/N | 条件 | `字段角色='measure'` 时必填 |
| 派生逻辑 | 计算表达式 | 条件 | `是否派生='Y'` 时必填 |
| 字段排序 | 整数 | 是 | 按 `grain_key→fk→degenerate_dim→low_card_attr→measure→business_time` |
| 备注 | 额外说明 | 否 | |
| 更新时间 | ISO 日期 | 是 | 最近修改时间 |

> 主键：`DWD表名 + 字段名`
>
> 字段来源：
> - 粒度键：来自 `dwm_bp_business_process.粒度键`
> - FK 字段：来自 `all_tables_metadata.xlsx WHERE 字段角色='foreign_key'`（或命名语义推导）
> - 退化维度：来自 `all_tables_metadata.xlsx WHERE 字段角色='primary_key'`（事实表中的天然业务键）
> - 低基数属性：来自 `all_tables_metadata.xlsx WHERE 字段角色='low_cardinality'`
> - 度量：来自 `all_tables_metadata.xlsx WHERE 字段角色='numeric_measure'`
> - 业务时间：来自 `all_tables_metadata.xlsx WHERE 字段角色='business_time'`

---

## 5. 验收标准

1. 所有事实表均有完整的 `业务过程中文名称`、`业务过程英文名称`、`主题域编码`、`主题域中文名称`、`粒度声明`、`粒度键`、`事实表类型`
2. 粒度键唯一性校验通过
3. 每个业务过程只归属一个主题域（1:1）
4. `dwm_bp_subject_area` 已定义且引用有效
5. 高风险歧义关系（接口数据/无约束外键）已人工确认
6. `dwm_dwd_fact_spec` 中每个度量字段已填写 `度量类型`、`聚合建议`、`度量单位`，聚合语义与事实表类型匹配
7. 派生度量已标注计算逻辑

---

## 6. 与下游衔接

| 下游 Skill | 消费数据 | 用途 |
|-----------|---------|------|
| dwm-dimension | `dwm_bp_business_process` | 业务过程清单，从中提取维度引用 |
| dwm-dimension | `dwm_bp_subject_area` | 主题域主数据 |
| dwm-matrix | `dwm_bp_business_process` | 矩阵行、粒度、事实表类型 |
| dwm-matrix | `dwm_bp_subject_area` | 主题域清单 |
| cdm_modeling | `dwm_dwd_fact_spec` | 生成 DWD DDL + ETL SQL |

---

## 7. 代码规范

### CSV 工具

```python
import sys
sys.path.insert(0, ".claude/sub-skills/dwm-shared/scripts")
from read_csv import read_csv
from write_csv import write_csv
```

### 读取上游产出

```python
# 读取字段元数据（外键连线依据）
from read_xlsx import read_xlsx
field_metadata = read_xlsx("output/metadata_parse/all_tables_metadata.xlsx")
fk_fields = [f for f in field_metadata if f["字段角色"] == "foreign_key"]

# 读取 ODS 表清单
ods_tables = read_xlsx("output/ods_generator/all_tables_metadata_ods.xlsx")
```
