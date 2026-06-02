# CDM 建模 Skill 使用指南

版本: 1.3.0  
定位: 读取上游 DWM DIM/DWD 建设规格，生成 CDM 层 DIM/DWD 模型产物。

## 输入

本 skill 只解析 CSV 和 XLSX 格式的 DWM 建设规格：

- `dim_spec_file`: DIM 建设清单，通常为 `output/dwm-bus-matrix/dwm_dim_table_spec.csv`。
- `dwd_fact_spec_file`: DWD 事实表建设清单，通常为 `output/dwm-bus-matrix/dwm_dwd_fact_spec.csv`。

## OneData 建模口径

- DIM 独立维护一致性维度，包含代理键、业务键、维度属性和 SCD 字段。
- DWD 只生成原子明细事实表，包含粒度键、维度代理键、事实描述字段、度量和审计字段。
- DWD ETL 可以关联 DIM，但默认只落 `{entity}_sk`，不把 DIM 属性打宽进 DWD。
- 事实 + 维度属性宽表、汇总指标和面向应用的服务表应进入 DWS/ADS，不进入 DWD。

配置示例：

```yaml
input:
  dim_spec_file: "../../../output/dwm-bus-matrix/dwm_dim_table_spec.csv"
  dwd_fact_spec_file: "../../../output/dwm-bus-matrix/dwm_dwd_fact_spec.csv"

output:
  target_dir: "../../../output/cdm-modeling"

modeling:
  default_scd_type: 1
  default_fact_type: "transaction"
  generate_ddl: true
  generate_etl: true
```

## 必要列

DIM spec:

| 列名 | 说明 |
|------|------|
| `DIM表名` | 目标 DIM 表名 |
| `维度中文名` | 维度中文名称 |
| `DIM字段名` | DIM 字段名 |
| `字段中文说明` | 字段注释 |
| `字段角色` | `bk` / `attribute` |
| `SCD类型` | `SCD1` / `SCD2` / `SCD3` / `-` |
| `来源ODS表` | 源表标识 |
| `来源ODS字段` | 源字段 |
| `ODS字段数据类型` | 源字段类型 |

DWD spec:

| 列名 | 说明 |
|------|------|
| `DWD表名` | 目标 DWD 表名 |
| `主题域编码` | 主题域编码 |
| `业务过程标准名` | 业务过程英文名 |
| `事实表类型` | `transaction` / `periodic_snapshot` / `accumulating_snapshot` / `factless` |
| `粒度声明` | 事实粒度 |
| `DWD字段名` | DWD 字段名 |
| `字段角色` | `grain_key` / `measure` / 其他描述字段；维度关联不强依赖此列 |
| `关联DIM表` | 非空时表示该字段需要关联 DIM 表 |
| `关联DIM业务键` | 可选；缺失时默认使用 `DWD字段名`，再缺失时使用 `来源ODS字段` |
| `聚合建议` | 度量聚合函数 |
| `来源ODS表` | 源表标识 |
| `来源ODS字段` | 源字段 |
| `ODS字段数据类型` | 源字段类型 |

## 执行

DWD 维度 join 规则：

```sql
source.来源ODS字段 = 关联DIM表.关联DIM业务键
```

如果没有 `关联DIM业务键` 列，默认使用当前行的 `DWD字段名`；如果 `DWD字段名` 为空，则使用 `来源ODS字段`。

在 skill 根目录执行：

```bash
python3 scripts/main.py
```

使用自定义配置：

```bash
python3 scripts/main.py --config path/to/skill_config.yaml
```

独立校验生成产物：

```bash
python3 scripts/validate_model.py output/cdm-modeling --write-report
```

## 输出

默认输出目录为 `output/cdm-modeling/`：

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

## 校验重点

执行后先查看 `docs/validation_report.md`。报告状态分为：

- `PASS`: 无错误，无告警
- `WARN`: 有告警，可审查但需要说明
- `FAIL`: 有错误，不应进入下游建设

常见问题：

- 业务过程缺少粒度
- 业务过程缺少维度
- 非 `factless` 业务过程缺少度量
- 维度缺少业务键
- 维度缺少属性字段
- DWD 引用了不存在的 DIM
- SQL 文件残留未渲染模板占位符
