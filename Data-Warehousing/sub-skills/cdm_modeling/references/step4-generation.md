# 第四步：DDL/ETL 与文档产物生成

将 DIM/DWD 设计字典渲染为 SQL 和结构化清单，形成可审查、可追溯的 CDM 建模产物。

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `dim_designs` | 第二步 | DIM DDL、DIM ETL、DIM 清单 |
| `dwd_designs` | 第三步 | DWD DDL、DWD ETL、DWD 清单 |
| `templates/*.tpl` | 本 skill | SQL 模板 |

## 2. 输出目录

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

## 3. 文档产物

### `dim_list.csv`

记录 DIM 表名、实体、业务键、SCD 类型、源表、属性数量。

### `dwd_list.csv`

记录 DWD 表名、数据域、业务过程、粒度、事实类型、维度、度量、源表。

### `field_mapping.csv`

一行一条字段映射，覆盖业务键、维度属性、维度外键和度量。

### `dependency.csv`

记录 DIM/DWD 的加载依赖和加载顺序。

### `model_design.md`

生成面向人工审查的模型概要。

## 4. 生成规则

1. 模板只消费设计字典，不在模板中推断业务语义。
2. 源表和源字段必须来自上游文档或设计字典。
3. 文档清单以 CSV 为主，便于后续 SQL/脚本处理。
4. 同次执行覆盖旧产物。
5. 生成后必须执行第五步校验。

## 5. 验收标准

1. 所有启用的输出目录存在。
2. 所有 SQL 文件无未渲染占位符。
3. `field_mapping.csv` 能覆盖主要目标字段。
4. `dependency.csv` 能体现 DIM 先于 DWD 加载。
5. 文档产物可被 `scripts/validate_model.py` 读取。
