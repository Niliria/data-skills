---
name: dwm-dimension
description: >-
  Use when the user asks to "确认维度", "维度确定", "维度提取", "一致性维度",
  "SCD策略", "退化维度判定", "维度注册", "identify dimensions", "conformed dimensions",
  or needs to extract dimension references from fact tables and register conformed dimensions.
version: 1.0.0
---

# 确认维度

## 定位

从每个业务过程中提取维度引用，收敛一致性维度，确认 SCD 策略。

## 职责边界

**做什么**：
- 提取维度外键引用（每个业务过程 → 关联哪些维度）
- 识别退化维度（事实表中的交易凭证/业务单号）
- 识别低基数离散属性候选
- 收敛一致性维度（跨事实表共享的维度 → 建 DIM 表）
- 确认 SCD 策略（SCD1/SCD2/SCD3）

**不做什么**：
- 不判事实表类型（→ dwm-business-process）
- 不判度量归属（→ dwm-business-process）
- 不做字段画像（由上游 metadata_parse 提供）

## 输入依赖

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `dwm_bp_business_process` | dwm-business-process | 业务过程清单与粒度声明 |
| `output/metadata_parse/all_tables_metadata.xlsx` | 上游元数据解析 | 字段角色画像（外键、业务键等），用于自行识别维度候选表 |
| `output/ods_generator/all_tables_metadata_ods.xlsx` | 上游 ODS 生成器 | ODS 表清单 |
| `dwm_bp_subject_area` | dwm-business-process | 主题域定义 |

> **维度候选识别**：从 `all_tables_metadata.xlsx` 的字段角色和外键引用列分析 FK 被引用关系，被多张事实表引用且自身 FK ≤ 1 的表为维度候选。

## 产出物

| 产出物 | 说明 | 输出路径 |
|--------|------|----------|
| `dwm_dim_spec` | 维度表建设清单（字段级，合并原 registry + table_spec） | `output/dwm-bus-matrix/` |
| `dwm_dim_join_spec` | DIM 维度表 ODS 关联关系 | `output/dwm-bus-matrix/` |

## CSV 工具

```python
import sys
sys.path.insert(0, ".claude/sub-skills/dwm-shared/scripts")
from read_csv import read_csv
from write_csv import write_csv
```

## 代码编写规范

涉及以下场景时，通过 `use context7` 获取最新文档再编写代码：
- 编写一致性维度校验 SQL（命名、口径、值域、JOIN 命中率）
- 编写 SCD 维度加工脚本（追踪历史变化）
- 编写批量维度引用提取脚本

## 详细规格

Read `references/dimension.md` for dimension extraction rules, conformed dimension criteria, SCD strategy, degenerate dimension rules, and acceptance criteria.
