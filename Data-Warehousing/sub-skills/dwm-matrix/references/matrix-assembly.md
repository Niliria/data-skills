# 构建总线矩阵

**核心原则**：一个业务过程 = 一张 DWD 事实表。

---

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `dwm_bp_business_process.csv` | dwm-business-process | 业务过程、粒度声明、事实表类型 |
| `dwm_bp_subject_area.csv` | dwm-business-process | 主题域主数据 |
| `dwm_dim_spec.csv` | dwm-dimension | 一致性维度 → 总线矩阵列头 |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | 字段元数据（FK 关系推导维度引用） |

所有 CSV 输入路径：`output/dwm-bus-matrix/`

---

## 2. 实施步骤

### 2.1 矩阵验证（交互过程，不持久化）

> 如需编写批量验证 SQL 脚本，use context7 获取对应 SQL 方言（HiveQL / SparkSQL）的最新文档。

**逐行验证（业务过程）**：
- 每个业务过程能否按关联维度稳定聚合
- 粒度唯一性验证（ODS 层直接执行）

**粒度唯一性验证 SQL**：
```sql
SELECT
  COUNT(*) AS total_row_cnt,
  COUNT(DISTINCT ${grain_key_cols}) AS grain_distinct_cnt
FROM ${ods_table_name}
WHERE dt = '${check_dt}';
-- total_row_cnt = grain_distinct_cnt → 通过
-- 不一致 → 回退 dwm-business-process 修正粒度声明
```

**逐列验证（一致性维度）**：
- 每个一致性维度能否在关联事实中稳定 JOIN
- JOIN 缺失率 ≤ 1%

**JOIN 缺失率验证 SQL**：
```sql
SELECT
  COUNT(1) AS ref_cnt,
  SUM(CASE WHEN b.${ref_col} IS NULL THEN 1 ELSE 0 END) AS miss_cnt,
  ROUND(SUM(CASE WHEN b.${ref_col} IS NULL THEN 1 ELSE 0 END) / COUNT(1), 4) AS miss_rate
FROM ${fact_ods_table} a
LEFT JOIN ${dim_ods_table} b ON a.${fk_col} = b.${ref_col}
WHERE a.${fk_col} IS NOT NULL
  AND a.dt = '${check_dt}';
-- miss_rate ≤ 0.01 → 通过
```

**业务语义验证**：聚合结果是否符合常识与业务口径。

验证通过后生成总线矩阵 Excel。

### 2.2 生成总线矩阵 Excel

```bash
python .claude/skills/dwm-matrix/scripts/write_bus_matrix.py \
  --business-process output/dwm-bus-matrix/dwm_bp_business_process.csv \
  --subject-area  output/dwm-bus-matrix/dwm_bp_subject_area.csv \
  --dim-registry  output/dwm-bus-matrix/dwm_dim_spec.csv \
  --field-metadata output/metadata_parse/all_tables_metadata.xlsx \
  --output        output/dwm-bus-matrix/dwm_bus_matrix.xlsx \
  --version v1.0
```

> 如需安装依赖或修改脚本，use context7 获取 openpyxl 最新文档（`pip install openpyxl`）。

---

## 3. 产出物

### `dwm_bus_matrix.xlsx`（总线矩阵）

Excel 格式，路径 `output/dwm-bus-matrix/`。

Excel 结构：
- Sheet 名：`总线矩阵 v{version}`
- A 列：主题域（`主题域名称(编码)`，每行填充，不合并）
- B 列：业务过程（中文名）
- C 列：业务过程代码（英文）
- D 列：粒度声明
- E 列：事实表名称（`dwd_{主题域编码}_{业务过程代码}_df`）
- F 列：事实表类型
- G 列起：每列一个一致性维度（列头 = 维度中文名称）
- 单元格：`✓` / `-`

---

## 4. 验收标准

1. **JOIN 验证**：核心维度与事实的 JOIN 缺失率 ≤ 1%
2. **粒度唯一性**：每个业务过程粒度键在 ODS 层 100% 通过
3. **口径验证**：一致性维度在不同事实中口径一致

---

## 5. 与建设阶段衔接

| 交付物 | 消费方 | 用途 |
|--------|--------|------|
| `dwm_dwd_fact_spec.csv` | cdm_modeling Skill | 生成 DWD DDL + INSERT OVERWRITE SQL |
| `dwm_dim_spec.csv` | cdm_modeling Skill | 生成 DIM DDL + INSERT OVERWRITE SQL |
| `dwm_bus_matrix.xlsx` | 业务方 + 技术负责人 | 企业级建模权威蓝图，事实与维度关联关系 |

---

## 6. 附录：建设阶段反馈机制

> 以下内容在建设阶段执行，非本 Skill 范围。

### A.1 建设阶段验证（DWD 建成后执行）

| 验证项 | 验证时机 | 检查规则 | 失败处理 |
|--------|---------|---------|---------|
| 粒度可聚合性 | DWD 建成后 | 聚合值与源系统差异率 ≤ 0.1% | 回退 dwm-business-process |
| 维度 JOIN 一致性 | DIM + DWD 联调时 | 生产 JOIN miss_rate ≤ 1% | 回退 dwm-dimension |

### A.2 反馈触发与回退路径

| 触发条件 | 回退目标 | 处理方式 |
|---------|---------|---------|
| DWD 聚合差异 > 0.1% | dwm-business-process | 检查度量归属或事实表类型 |
| 生产 JOIN miss_rate 远高于采样 | 上游 `all_tables_metadata.xlsx` | 数据质量问题或 FK 关系误判 |
| 新业务上线产生新业务过程 | dwm-business-process | 走增量流程 |
| 口径争议升级 | dwm-dimension | 重新做一致性校验 |

### A.3 变更管理

1. 矩阵版本化：每次修正后更新 `dwm_bus_matrix.xlsx` 的 `version`
2. 修正后的产出物须重新通过对应步骤的验收标准

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
from read_xlsx import read_xlsx

table_profile = read_csv("output/dwm-bus-matrix/dwm_bp_business_process.csv")
subject_area  = read_csv("output/dwm-bus-matrix/dwm_bp_subject_area.csv")
dim_spec      = read_csv("output/dwm-bus-matrix/dwm_dim_spec.csv")
field_metadata = read_xlsx("output/metadata_parse/all_tables_metadata.xlsx")
```
