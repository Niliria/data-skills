---
name: dwm-matrix
description: >-
  Use when the user asks to "构建总线矩阵", "数仓建模", "总线矩阵",
  "矩阵验证", "bus matrix",
  or discusses data warehouse bus matrix construction, matrix assembly, validation, or delivery.
  This is the orchestrator that coordinates dwm-business-process, dwm-dimension.
version: 3.0.0
---

# 构建总线矩阵

## 定位

编排 dwm-business-process / dwm-dimension 两个 Skill，基于上游元数据产出完成总线矩阵的组装与验证。

基于《数据仓库工具箱》(Kimball) 四步法与《阿里巴巴大数据之路》分层实践。

## 前置输入（上游产出）

| 文件 | 路径 | 提供信息 |
|------|------|----------|
| 源表元数据 | `output/metadata_parse/all_tables_metadata.xlsx` | 字段名、数据类型、主键、外键、外键引用、字段空值率、字段角色 |
| ODS 表清单 | `output/ods_generator/all_tables_metadata_ods.xlsx` | 原表名、新表名（ODS）、主键、外键、DDL |

## 编排流程

```
上游产出（metadata_parse + ods_generator）
        ↓
dwm-business-process     选择业务过程 + 声明粒度 + 确认事实 + DWD spec
        ↓
dwm-dimension            确认维度 + DIM spec
        ↓
dwm-matrix               验证 + 生成总线矩阵（本 Skill）
```

## 本 Skill 自身职责

### 验证（交互过程，不持久化）
- 粒度唯一性验证（每个业务过程）
- JOIN 验证（核心维度 JOIN 缺失率 ≤ 1%）
- 口径验证（一致性维度跨事实表口径一致）
- 应连未连检查

### 产出
- 总线矩阵 Excel（事实 × 维度交叉表）

## 输入依赖

| 输入项 | 来源 |
|--------|------|
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 |
| `output/dwm-bus-matrix/dwm_bp_business_process.csv` | dwm-business-process |
| `output/dwm-bus-matrix/dwm_bp_subject_area.csv` | dwm-business-process |
| `output/dwm-bus-matrix/dwm_dim_spec.csv` | dwm-dimension |

## 产出物

| 产出物 | 说明 | 输出路径 |
|--------|------|----------|
| `dwm_bus_matrix.xlsx` | 总线矩阵（事实 × 维度交叉表） | `output/dwm-bus-matrix/` |

## 回退规则

| 当前步骤 | 回退目标 | 触发条件 |
|---------|---------|---------|
| dwm-business-process | 上游 metadata_parse | 字段画像有误导致表角色判断错误 |
| dwm-dimension | 上游 metadata_parse | 外键画像有误导致维度关联错误 |
| dwm-matrix | dwm-dimension | 应连未连或维度口径不一致 |
| dwm-matrix | dwm-business-process | 聚合结果违反业务常识或度量归属有误 |

回退原则：最小回退、影响评估、防循环（同一问题不超过 2 次）。

## 术语统一

| 用语 | 含义 |
|-----|------|
| 主题域 | 业务过程按相似性归组后的分类 |
| 主题域编码 | 2~3 个大写字母（如 `TRD`），用于表命名 |

禁用"业务域""数据域"，统一收敛为"主题域"。

## CSV 工具与矩阵生成

```python
import sys
sys.path.insert(0, ".claude/sub-skills/dwm-shared/scripts")
from read_csv import read_csv
from write_csv import write_csv
```

```bash
python .claude/skills/dwm-matrix/scripts/write_bus_matrix.py \
  --business-process output/dwm-bus-matrix/dwm_bp_business_process.csv \
  --subject-area  output/dwm-bus-matrix/dwm_bp_subject_area.csv \
  --dim-registry  output/dwm-bus-matrix/dwm_dim_spec.csv \
  --field-metadata output/metadata_parse/all_tables_metadata.xlsx \
  --output        output/dwm-bus-matrix/dwm_bus_matrix.xlsx \
  --version v1.0
```

## 代码编写规范

涉及以下场景时，通过 `use context7` 获取最新文档再编写代码：
- 编写矩阵验证 SQL（JOIN 缺失率、粒度唯一性）
- 安装或调用 openpyxl 生成 Excel 文件

## 详细规格

Read `references/matrix-assembly.md` for validation procedures, bus matrix Excel schema, and rollback rules.
