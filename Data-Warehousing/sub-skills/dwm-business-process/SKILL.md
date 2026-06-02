---
name: dwm-business-process
description: >-
  Use when the user asks to "识别业务过程", "业务过程识别",
  "选择业务过程", "声明粒度", "粒度声明", "定义主题域", "主题域划分",
  "确认事实", "事实确定", "度量归属", "度量确认", "事实表类型", "派生度量",
  "select business process", "declare grain", "identify facts", "determine measures",
  or needs to identify business processes, define subject areas, declare grain,
  classify fact table types, and attribute measures to business processes.
version: 2.0.0
---

# 选择业务过程 + 声明粒度 + 确认事实

## 定位

对应 Kimball 四步法的**第一、二、四步**：选择业务过程 → 声明粒度 → 确认事实（事实表类型 + 度量归属）。

粒度确定后，事实表类型和度量归属是自然推导，不需要拆成独立步骤。

## 职责边界

**做什么**：
- 从表关系图中识别事实表（承载业务事件的表）
- 识别业务过程并标准命名
- 定义主题域（先自底向上聚类，再自顶向下校验）
- 声明粒度（一句话 + 粒度键 + 唯一性校验）
- 确定事实表类型（transaction / periodic_snapshot / accumulating_snapshot / factless）
- 将度量归属到对应事实表，校验可加性
- 识别派生度量（如 利润 = 收入 - 成本）
- 接口数据无主键时通过画像降级发现业务键和外键

**不做什么**：
- 不做字段画像（由上游 metadata_parse 提供）
- 不提取/注册维度（→ dwm-dimension，维度识别是 Kimball 第三步）
- 不做维度表粒度声明（→ dwm-dimension）

## 输入依赖

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | 字段角色画像（字段角色列）、约束信息（主键/外键/外键引用列）、字段类型，用于画表关系图 + 度量候选 |
| `output/ods_generator/all_tables_metadata_ods.xlsx` | 上游 ODS 生成器 | ODS 表清单（原表名→新表名映射） |

## 产出物

| 产出物 | 说明 | 输出路径 |
|--------|------|----------|
| `dwm_bp_business_process` | 业务过程清单（含粒度、事实表类型） | `output/dwm-bus-matrix/` |
| `dwm_bp_subject_area` | 主题域注册表 | `output/dwm-bus-matrix/` |
| `dwm_dwd_fact_spec` | DWD 事实表建设清单（字段级，含度量归属） | `output/dwm-bus-matrix/` |
| `dwm_dwd_join_spec` | DWD 事实表 ODS 关联关系 | `output/dwm-bus-matrix/` |

## CSV 工具

```python
import sys
sys.path.insert(0, ".claude/sub-skills/dwm-shared/scripts")
from read_csv import read_csv
from write_csv import write_csv
```

## 代码编写规范

涉及以下场景时，通过 `use context7` 获取最新文档再编写代码：
- 编写唯一率分析 SQL（发现天然业务键）
- 编写 JOIN 命中率分析 SQL（发现外键关系）
- 编写粒度唯一性校验 SQL
- 编写度量可加性校验 SQL

## 详细规格

Read `references/business-process.md` for business process identification, subject area design, grain declaration, fact type classification, measure attribution, and acceptance criteria.
