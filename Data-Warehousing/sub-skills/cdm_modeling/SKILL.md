---
name: cdm-modeling
description: >-
  This skill should be used when the user asks to "CDM建模", "DIM设计", "DWD设计",
  "读取总线矩阵文档生成模型", "读取ODS元数据解析文档", "维度表生成", "事实表生成",
  "SCD策略", "拉链表", "星形模型", "代理键生成", "ETL脚本生成", "建表语句生成",
  or discusses CDM layer modeling from upstream DWM DIM/DWD specs.
version: 1.3.0
---

# CDM 建模 Skill

读取上游 skill 已经产出的 DWM DIM/DWD 建设规格，生成 CDM 层 DIM/DWD 数据模型、DDL 建表语句、ETL SQL、字段映射清单和校验报告。

## 使用边界

将本 skill 用于“上游解析已经完成”的建模场景。不要让本 skill 直接重新解析原始 ODS DDL 或手工推导总线矩阵；上游文档才是事实来源。

OneData 口径：
- DIM 独立维护一致性维度。
- DWD 维护原子明细事实，关联 DIM 只获取代理键，不展开维度描述属性。
- 事实 + 维度属性打宽、汇总指标和应用服务表属于 DWS/ADS，不由本 skill 的 DWD 默认生成。

必需输入：
- **DWM DIM 建设清单**：`dwm_dim_table_spec.csv/.xlsx`，包含 DIM 表、字段、业务键、属性、SCD、来源字段。
- **DWM DWD 事实表建设清单**：`dwm_dwd_fact_spec.csv/.xlsx`，包含 DWD 表、主题域、业务过程、粒度、维度外键、度量、来源字段。

可选输入：
- **建模配置**：指定默认 SCD、默认事实类型、输出目录、是否生成 DDL/ETL。

## 五步流程总览

| 步骤 | 核心目标 | 关键产出 | Reference |
|-----|---------|---------|-----------|
| 第一步 | 读取并校验上游文档 | 统一建模上下文、输入告警 | `references/step1-upstream-input.md` |
| 第二步 | 生成 DIM 维度设计 | DIM 设计、业务键、属性、SCD 策略 | `references/step2-dim-design.md` |
| 第三步 | 生成 DWD 事实设计 | DWD 设计、粒度、维度外键、度量 | `references/step3-dwd-design.md` |
| 第四步 | 渲染 DDL/ETL 与清单 | SQL、模型清单、字段映射、依赖清单 | `references/step4-generation.md` |
| 第五步 | 执行模型门禁校验 | `validation_report.md`、校验状态 | `references/step5-validation.md` |

流程主线：上游文档 → 统一建模上下文 → DIM → DWD → DDL/ETL/docs → 校验报告。

## 输入格式

仅解析 CSV 和 XLSX。两个输入文件应使用 DWM 总线矩阵 skill 的字段级交付规格：

| 文档 | 必要列 |
|------|--------|
| DIM spec | `DIM表名`、`维度中文名`、`DIM字段名`、`字段角色`、`SCD类型`、`来源ODS表`、`来源ODS字段`、`ODS字段数据类型` |
| DWD spec | `DWD表名`、`主题域编码`、`业务过程标准名`、`事实表类型`、`粒度声明`、`DWD字段名`、`来源ODS表`、`来源ODS字段`、`ODS字段数据类型` |

DWD 维度关联规则：
- `关联DIM表` 非空即视为维度关联，不强依赖 `字段角色=fk`。
- `关联DIM业务键` 为可选列；缺失时默认使用 `DWD字段名`，再缺失时使用 `来源ODS字段`。
- ETL join 形态为 `source.来源ODS字段 = 关联DIM表.关联DIM业务键`。

## 输出约定

默认输出写入 `output/cdm-modeling/`：

```text
output/cdm-modeling/
├── ddl/
│   ├── dim/
│   └── dwd/
├── etl/
│   ├── dim/
│   └── dwd/
└── docs/
    ├── dim_list.csv
    ├── dwd_list.csv
    ├── field_mapping.csv
    ├── dependency.csv
    ├── model_design.md
    └── validation_report.md
```

## 建模流程

1. 读取 `skill_config.yaml` 或命令行传入的 `--config`。
2. 解析 DWM DIM/DWD spec CSV/XLSX，提取维度、业务过程、粒度、维度外键、度量、源表字段。
3. 合并两个上游来源，形成统一建模上下文。
5. 生成 DIM 维度表设计，优先使用上游文档中的维度属性和业务键。
6. 生成 DWD 事实表设计，优先使用总线矩阵文档中的度量和粒度。
7. 渲染 DDL、ETL、模型清单、字段映射、依赖清单和校验报告。

## 关键规则

- 维度属性不得再硬编码为 `{entity}_name` 和 `{entity}_code`；必须来自 DIM spec。
- 事实表度量不得再硬编码为 `quantity` 和 `amount`；必须来自 DWD spec。
- SCD 策略优先级：DIM spec 显式字段 > 默认策略。
- DWD 表粒度必须来自 DWD spec；缺失时写入 `validation_report.md`。
- 每个 DWD 事实表必须至少有一个度量；缺失时仍可生成结构草案，但必须在校验报告中标记。
- 每个维度必须有业务键；无法从上游文档或 ODS 元数据推断时使用 `{entity}_id` 并记录告警。

## 详细资料

Reference files:
- **`references/skill_usage.md`** - 完整使用指南和输入格式说明
- **`references/mandatory-modeling-rules.md`** - 必须遵守的 CDM 建模规则
- **`references/field-classification-rules.md`** - 字段分类、类型映射和质量规则
- **`references/scd-lifecycle-rules.md`** - SCD 生命周期和增量类型规则
- **`references/anti-patterns.md`** - 建模反模式和禁止项
- **`references/step1-upstream-input.md`** - 上游输入契约与解析规则
- **`references/step2-dim-design.md`** - DIM 设计步骤、产物和验收标准
- **`references/step3-dwd-design.md`** - DWD 设计步骤、产物和验收标准
- **`references/step4-generation.md`** - DDL/ETL/docs 生成规则
- **`references/step5-validation.md`** - 模型门禁和校验报告规则
- **`references/dim_design_guide.md`** - DIM 维度表设计指南
- **`references/dwd_design_guide.md`** - DWD 事实表设计指南

Legacy rule files:
Scripts:
- **`scripts/main.py`** - 主入口
- **`scripts/parse_upstream_outputs.py`** - 上游 DWM DIM/DWD spec CSV/XLSX 解析
- **`scripts/generate_dim.py`** - DIM 设计和 DDL 生成
- **`scripts/generate_dwd.py`** - DWD 设计和 DDL 生成
- **`scripts/generate_etl.py`** - ETL 脚本生成
- **`scripts/validate_model.py`** - 生成产物门禁校验
