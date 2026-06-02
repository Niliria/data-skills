# CDM 强制建模规则

本文件定义 CDM 生成和人工审查时必须遵守的规则。若本文件与设计指南冲突，以本文件为准。

本 skill 采用 OneData 分层口径：DIM 维护一致性维度，DWD 维护原子明细事实，DWS/ADS 才承接汇总、宽表和应用服务。

## 1. 命名规则

1. 表名和字段名必须使用小写英文、数字和下划线。
2. 禁止空格、中文、特殊字符和 SQL 保留字作为物理表字段名。
3. DIM 表名必须使用 `dim_{entity}`。
4. DWD 表名必须使用 `dwd_{domain}_{business_process}_{di|df}`。
5. 临时表名前缀使用 `tmp_`。
6. 代理键必须使用 `{entity}_sk`。
7. 业务键优先使用上游 ODS 元数据解析文档中的明确字段；无法识别时才使用 `{entity}_id` 并写入校验告警。
8. 分区字段统一使用 `pt STRING`。

## 2. 建表规则

1. 默认存储格式为 ORC。
2. 默认压缩格式为 SNAPPY。
3. DWD 事实表必须按 `pt` 分区。
4. 审计字段至少包含 `etl_insert_time` 和 `etl_update_time`。
5. DWD 必须保留 `source_system`，用于追溯来源。
6. SQL 模板渲染后不得残留 `{{` 或 `}}`。

## 3. DIM 规则

1. 每个 DIM 必须有代理键和业务键。
2. 非日期维度必须至少有一个维度属性；缺失时必须写入 `validation_report.md`。
3. 日期和时间维度默认使用 SCD Type I。
4. SCD Type II 必须包含 `begin_date`、`end_date`、`is_active`。
5. DIM 属性必须优先来自 ODS 元数据解析文档中的 `dimension_attribute` 字段。
6. 技术字段、临时字段、废弃字段不得进入 DIM 业务属性。

## 4. DWD 规则

1. DWD 是业务过程原子明细层，一张 DWD 对应一个明确业务过程和一个稳定粒度。
2. DWD 保留事实粒度键、退化维度、低基数字段、维度代理键、度量、业务时间、审计字段。
3. DWD 可以在 ETL 中关联 DIM，但只落维度代理键或必要业务键，不展开 DIM 的描述属性。
4. 事实 + 维度属性打宽属于 DWS/ADS，不进入 DWD 默认生成逻辑。
5. 非 `factless` DWD 必须至少有一个度量。
6. DWD 维度引用以 DWD spec 中 `关联DIM表` 非空为准；`关联DIM业务键` 可选，缺失时用 `DWD字段名` 或 `来源ODS字段`。
7. DWD 度量必须来自 DWD spec，包含字段名、来源字段、字段类型和聚合建议。
8. DWD 不自动补充日期维度；是否关联日期维度以上游 DWD spec 为准。

## 5. 输入优先级

1. DWM DWD spec 是业务过程、粒度、维度引用、度量和源表的权威来源。
2. DWM DIM spec 是维度业务键、属性、SCD 和源字段的权威来源。
3. `skill_config.yaml` 仅提供默认策略，不应覆盖上游显式业务定义。
4. 模板不得自行推断业务语义；业务语义必须在设计字典中完成。

## 6. 校验门禁

1. `validation_report.md` 状态为 `FAIL` 时，产物不得进入下游建设。
2. `WARN` 项必须有业务说明或后续处理计划。
3. 独立校验脚本 `scripts/validate_model.py` 必须能读取生成产物。
4. 每次生成后必须至少检查 docs 文件、SQL 占位符、DIM/DWD 引用关系。
