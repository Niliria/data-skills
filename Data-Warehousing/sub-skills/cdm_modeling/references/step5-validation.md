# 第五步：模型门禁校验

对生成后的 CDM 产物执行结构、引用、模板渲染和输入告警校验。校验结果写入 `validation_report.md`。

校验时必须以 `references/mandatory-modeling-rules.md` 为最高优先级，并参考 `references/anti-patterns.md` 识别常见问题。

## 1. 输入

| 输入项 | 来源 | 用途 |
|--------|------|------|
| `upstream_model.warnings` | 第一步 | 输入解析告警 |
| `dim_designs` | 第二步 | DIM 结构校验 |
| `dwd_designs` | 第三步 | DWD 结构和引用校验 |
| `output/cdm-modeling` | 第四步 | 文件与模板渲染校验 |

## 2. 校验项

### 输入校验

1. 是否解析到业务过程。
2. 业务过程是否缺少粒度。
3. 业务过程是否缺少维度。
4. 非 `factless` 业务过程是否缺少度量。

### DIM 校验

1. DIM 是否有业务键。
2. 非日期维度是否有属性。
3. SCD Type II 字段是否完整。

### DWD 校验

1. DWD 是否有粒度。
2. 非 `factless` DWD 是否有度量。
3. DWD 引用的维度是否存在 DIM。
4. DWD 维度业务键是否能映射到 DIM 业务键。

### 文件校验

1. 必要 docs 文件是否存在。
2. DDL/ETL 文件是否存在。
3. SQL 文件中是否残留 `{{` 或 `}}`。

## 3. 校验结果等级

| 等级 | 含义 |
|------|------|
| `PASS` | 无错误，无告警 |
| `WARN` | 有告警但可继续审查 |
| `FAIL` | 有错误，产物不应进入下游建设 |

## 4. 执行方式

```bash
python scripts/validate_model.py output/cdm-modeling
```

主流程 `scripts/main.py` 会自动生成 `validation_report.md`。独立脚本用于二次检查或 CI 集成。

## 5. 验收标准

1. `validation_report.md` 必须存在。
2. `FAIL` 项必须修复后再发布。
3. `WARN` 项必须有业务说明或后续处理计划。
4. 校验脚本返回码：`0` 表示通过或仅告警，`1` 表示失败。
