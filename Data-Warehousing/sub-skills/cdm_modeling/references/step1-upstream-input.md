# 第一步：上游输入读取与契约校验

读取 DWM DIM/DWD 建设规格 CSV/XLSX，形成后续 DIM/DWD 生成所需的统一建模上下文。

执行本步骤时同时参考：
- `references/mandatory-modeling-rules.md`
- `references/field-classification-rules.md`
- `references/anti-patterns.md`

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `dim_spec_file` | DWM 总线矩阵 skill | 提供 DIM 表、业务键、属性、SCD、来源字段 |
| `dwd_fact_spec_file` | DWM 总线矩阵 skill | 提供 DWD 表、主题域、业务过程、粒度、维度外键、度量、来源字段 |
| `skill_config.yaml` | 本 skill 配置 | 提供输入路径、输出目录、默认建模策略 |

## 2. 支持格式

仅支持 CSV 和 XLSX。

| 文档 | 必要列 |
|------|--------|
| DIM spec | `DIM表名`、`维度中文名`、`DIM字段名`、`字段角色`、`SCD类型`、`来源ODS表`、`来源ODS字段`、`ODS字段数据类型` |
| DWD spec | `DWD表名`、`主题域编码`、`业务过程标准名`、`事实表类型`、`粒度声明`、`DWD字段名`、`来源ODS表`、`来源ODS字段`、`ODS字段数据类型` |

## 3. 统一上下文结构

解析后形成：

```text
processes: DWD 业务过程、粒度、维度引用、度量、来源字段
dimensions: DIM 表、业务键、属性、SCD 策略、来源字段
ods_tables: 从 DIM/DWD spec 溯源字段汇总得到的源表字段索引
warnings: 输入告警
```

## 4. 解析规则

1. DIM 按 `DIM表名` 分组，`字段角色=bk` 作为业务键，`attribute` 作为维度属性。
2. DWD 按 `DWD表名` 分组，`关联DIM表` 非空的字段作为维度引用，不强依赖 `字段角色=fk`。
3. `关联DIM业务键` 为可选列；缺失时默认使用 `DWD字段名`，再缺失时使用 `来源ODS字段`。
4. DWD 中 `字段角色=measure` 的字段作为事实度量，使用 `聚合建议` 作为聚合函数。
5. 输入中的 `来源ODS表` 作为源表标识使用，不强制匹配 ODS 实际落表名。
6. MySQL 风格类型会转换为 Hive/CDM 类型，例如 `varchar(50)` 转 `STRING`、`bigint(20)` 转 `BIGINT`。

## 5. 验收标准

1. 至少解析到一个 DWD 业务过程。
2. 每个 DWD 业务过程有 `主题域编码`、`业务过程标准名`、`粒度声明`。
3. 每个非 `factless` DWD 至少有一个度量。
4. 每个 DIM 能解析或推断出业务键。
5. 解析告警必须写入 `validation_report.md`。
