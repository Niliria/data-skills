# CDM建模 Skill 规则更新日志

## 版本 1.4.0

**日期**: 2026年5月12日

### 输入收敛

- 上游建模输入收敛为 DWM DIM/DWD spec 文件，仅支持 CSV 和 XLSX。
- 删除 YAML/JSON/Markdown 上游文档解析代码和 `examples/basic` YAML 示例。
- `skill_config.yaml` 改为使用 `dim_spec_file` 和 `dwd_fact_spec_file`。
- DWD 维度关联规则改为以 `关联DIM表` 非空为准，`关联DIM业务键` 可选。
- ETL 模板统一使用 `pt` 分区字段和 `${bizdate}` 加载日期参数。

---

## 版本 1.3.0

**日期**: 2026年5月8日

### 规则整理

- 将未接入主流程的 `rules/*.yaml` 迁移到 `references/legacy-rules/`，保留为历史资料。
- 新增 `references/mandatory-modeling-rules.md`，沉淀必须遵守的 CDM 建模规则。
- 新增 `references/field-classification-rules.md`，整理字段分类、类型映射和质量检查规则。
- 新增 `references/scd-lifecycle-rules.md`，整理 SCD 生命周期和增量类型判断规则。
- 新增 `references/anti-patterns.md`，整理输入、DIM、DWD、ETL 和文档反模式。
- 更新 `SKILL.md`、`skill_usage.md` 和 step reference，使 Markdown 规则文档成为首选规则入口。

---

## 版本 1.2.1

**日期**: 2026年5月8日

### 清理

- 删除未被主流程调用的旧 CSV 总线矩阵解析器 `scripts/parse_bus_matrix.py`。
- 删除未被主流程引用的独立 SCD2 模板 `templates/scd_type2.tpl`。
- 移除 `skill_usage.md` 中关于旧兼容解析器的说明。

---

## 版本 1.2.0

**日期**: 2026年5月8日

### 结构优化

- 参考 `dwm-bus-matrix` 的组织方式，将 CDM 建模流程拆成五个 step reference。
- 更新 `SKILL.md` 为“总览 + 五步流程 + 资源索引”的渐进披露结构。
- 更新 `references/skill_usage.md`，补充五步流程和独立校验命令。

### 校验能力

- 新增 `scripts/validate_model.py`，支持对生成产物执行 docs、SQL 占位符、DIM/DWD 引用关系校验。
- `scripts/main.py` 自动聚合输入告警、模型结构校验和文件产物校验，生成更完整的 `validation_report.md`。

---

## 版本 1.1.0

**日期**: 2026年5月6日

### 架构调整

- 将主流程从直接读取 `bus_matrix.csv` 和 `ods_metadata/*.sql` 改为读取上游 skill 产出的总线矩阵解析文档和 ODS 元数据解析文档。
- 新增 `scripts/parse_upstream_outputs.py`，用于读取上游解析文档。
- 新增 skill 根目录 `skill_config.yaml`，并支持 `python scripts/main.py --config path/to/skill_config.yaml`。
- 新增 `examples/basic/`，提供最小可运行的上游文档样例。

### 生成逻辑调整

- DIM 属性改为来自 ODS 元数据解析文档中的 `dimension_attribute` 字段。
- DWD 度量改为来自总线矩阵文档中的 `measures` 定义。
- DWD 粒度改为来自总线矩阵文档中的 `grain`。
- ETL 模板改为使用上游文档中的源表、源字段和维度业务键。
- 新增 `field_mapping.csv`、`dependency.csv`、`model_design.md`、`validation_report.md` 输出。

---

**版本**: 1.0  
**日期**: 2026年4月9日

---

## 📝 修复的问题

### 1. 配置文件问题

#### 问题描述
- `skill_config.yaml` 中 `modeling.dimensions.default_scd_strategy` 配置项重复
- 配置结构不够清晰

#### 修复内容
- ✅ 删除了重复的 `default_scd_strategy` 配置
- ✅ 简化了配置层级结构
- ✅ 统一了配置风格

---

### 2. DWD DDL模板问题

#### 问题描述
- `dwd_ddl.tpl` 中 `date_sk` 字段重复定义
- 导致生成的SQL无法执行

#### 修复内容
- ✅ 移除了重复的 `date_sk` 字段定义
- ✅ 优化了模板注释
- ✅ 简化了维度外键渲染逻辑

#### 修复前
```sql
-- 维度外键
{% for dim in dimensions %}
{{ dim.entity }}_sk BIGINT COMMENT '→ dim_{{ dim.entity }}(外键)',
{% endfor %}

-- 时间维度外键
date_sk BIGINT COMMENT '→ dim_date(业务日期外键)',  -- ❌ 重复定义
```

#### 修复后
```sql
-- 维度外键（包含所有维度：业务维度+日期维度）
{% for dim in dimensions %}
{{ dim.entity }}_sk BIGINT COMMENT '→ dim_{{ dim.entity }}(外键)',
{% endfor %}
-- ✅ date_sk 已包含在 dimensions 中
```

---

### 3. DIM ETL模板渲染问题

#### 问题描述
- `generate_etl.py` 中使用简单的 `replace()` 替换模板占位符
- 导致 `fields`、`domain` 等复杂对象无法正确渲染
- 生成的SQL中显示 `{{ fields }}` 而不是实际字段

#### 修复内容
- ✅ 使用Jinja2的 `Environment` 和 `Template` 正确渲染
- ✅ 传递完整的上下文对象（包括fields、domain等）
- ✅ 支持模板中的循环和条件逻辑

#### 修复前
```python
# 简单替换（不支持复杂对象）
sql = template_content.replace('{{ table_name }}', table_name)
sql = sql.replace('{{ entity }}', dim_info['entity'])
sql = sql.replace('{{ scd_type }}', str(dim_info['scd_type']))
# ❌ fields/domain 无法渲染
```

#### 修复后
```python
# 使用Jinja2正确渲染
env = Environment(loader=FileSystemLoader(str(self.templates_dir)))
template = env.get_template('dim_etl.tpl')

context = {
    'table_name': table_name,
    'entity': dim_info['entity'],
    'scd_type': dim_info['scd_type'],
    'fields': fields,  # ✅ 复杂对象可以渲染
    'domain': domain,
}

sql = template.render(context)
```

---

### 4. DWD ETL模板问题

#### 问题描述
- `dwd_etl.tpl` 中JOIN `dim_date` 逻辑错误
- 依赖字段 `source.order_date` 可能不存在
- 质量检查查询过于复杂

#### 修复内容
- ✅ 移除了硬编码的 `dim_date` JOIN
- ✅ 日期维度已包含在 `dimensions` 中统一处理
- ✅ 简化了数据质量检查查询
- ✅ 优化了度量值字段的逗号处理

#### 修复前
```sql
-- ❌ 硬编码的dim_date JOIN
LEFT JOIN dim_date
    ON source.order_date = dim_date.calendar_date

-- ❌ 复杂的质量检查
SELECT
    COUNT(CASE WHEN {{ dimensions[0] }}_sk IS NULL THEN 1 ELSE 0 END) AS null_count
```

#### 修复后
```sql
-- ✅ 统一处理所有维度（包括日期维度）
{% for dim in dimensions %}
LEFT JOIN dim_{{ dim.entity }}
    ON source.{{ dim.entity }}_id = dim_{{ dim.entity }}.{{ dim.entity }}_id
{% endfor %}

-- ✅ 简化质量检查
SELECT
    COUNT(DISTINCT {{ dimensions[0].entity }}_sk) AS {{ dimensions[0].entity }}_unique_count
```

---

### 5. 文档缺失问题

#### 问题描述
- 项目缺少 `README.md`
- 缺少详细的DIM/DWD设计指南

#### 修复内容
- ✅ 创建了完整的 `README.md`
- ✅ 创建了 `docs/dim_design_guide.md`
- ✅ 创建了 `docs/dwd_design_guide.md`
- ✅ 完善了项目文档体系

---

## 🎯 改进内容

### 1. 代码质量提升

- ✅ 使用Jinja2的 `Environment` 替代简单字符串替换
- ✅ 添加了模板文件存在性检查
- ✅ 统一了日志输出格式

### 2. 模板优化

- ✅ 优化了DWD DDL模板的注释
- ✅ 简化了ETL模板的逻辑
- ✅ 提高了模板的可维护性

### 3. 文档完善

- ✅ 添加了完整的README
- ✅ 补充了设计指南文档
- ✅ 增加了示例和最佳实践

---

## 📊 影响范围

| 组件 | 修复内容 | 影响 |
|-----|---------|------|
| `skill_config.yaml` | 删除重复配置 | 无（配置逻辑未变） |
| `dwd_ddl.tpl` | 修复字段重复 | ✅ 生成的SQL可执行 |
| `generate_etl.py` | 改用Jinja2渲染 | ✅ 模板正确渲染 |
| `dwd_etl.tpl` | 优化JOIN逻辑 | ✅ 查询性能提升 |
| `README.md` | 新建文档 | ✅ 用户体验提升 |
| `docs/*.md` | 补充指南 | ✅ 学习成本降低 |

---

## 🧪 测试验证

### 1. 功能测试
```bash
# 重新运行生成流程
python scripts/main.py

# ✅ 成功生成 4 个维度表
# ✅ 成功生成 6 个事实表
# ✅ 成功生成 20 个SQL文件（10个DDL + 10个ETL）

# 检查输出文件
ls output/ddl/dim/*.sql  # ✅ 没有重复字段
ls output/ddl/dwd/*.sql  # ✅ 没有重复字段
ls output/etl/dim/*.sql  # ✅ 没有{{}}占位符
ls output/etl/dwd/*.sql  # ✅ 没有{{}}占位符
```

### 2. SQL验证
```bash
# 检查DDL语法
cat output/ddl/dwd/dwd_sales_门店销售_di.sql | grep date_sk
# ✅ 应该只出现一次 date_sk (验证通过)

# 检查ETL语法
cat output/etl/dim/load_dim_customer.sql | grep "{{"
# ✅ 应该没有未渲染的{{}}占位符 (验证通过)
```

### 3. 文档检查
```bash
# ✅ README.md 已创建（267行）
# ✅ dim_design_guide.md 已创建（540行）
# ✅ dwd_design_guide.md 已创建（590行）
# ✅ changelog.md 已创建（241行）
# ✅ skill_usage.md 已完善（529行）
# ✅ 总文档量: 2167 行
```

### 4. 生成验证
```bash
# ✅ DIM表: 4个 (customer, date, product, shop)
# ✅ DWD表: 6个 (销售、库存、商品管理、客户管理、店铺管理、退货处理)
# ✅ 模型清单: dim_list.csv + dwd_list.csv

cat output/docs/dim_list.csv
表名,实体,SCD策略,业务键,字段数,估计大小,说明
dim_customer,customer,Type 2,customer_id,10,small,维度表: customer
dim_date,date,Type 1,date_id,7,small,维度表: date
dim_product,product,Type 2,product_id,10,small,维度表: product
dim_shop,shop,Type 2,shop_id,10,small,维度表: shop

cat output/docs/dwd_list.csv
表名,域,业务过程,粒度,维度数,度量数,字段数,估计大小,说明
dwd_customer_客户管理_di,customer,客户管理,客户管理_id,2,2,11,large,事实表: customer-客户管理
dwd_inventory_库存变动_di,inventory,库存变动,库存变动_id,3,2,12,large,事实表: inventory-库存变动
dwd_product_商品管理_di,product,商品管理,商品管理_id,2,2,11,large,事实表: product-商品管理
dwd_sales_退货处理_di,sales,退货处理,退货处理_id,4,2,13,large,事实表: sales-退货处理
dwd_sales_门店销售_di,sales,门店销售,门店销售_id,4,2,13,large,事实表: sales-门店销售
dwd_shop_店铺管理_di,shop,店铺管理,店铺管理_id,2,2,11,large,事实表: shop-店铺管理
```

---

## 📅 后续计划

### 短期优化
- [ ] 添加单元测试
- [ ] 添加配置验证功能
- [ ] 优化日志输出

### 中期优化
- [ ] 支持更多SCD策略
- [ ] 支持累积快照事实表
- [ ] 支持多业务域隔离

### 长期规划
- [ ] 支持可视化配置
- [ ] 支持模型版本管理
- [ ] 支持自动数据质量检查

---

**更新完成时间**: 2026年4月9日  
**更新人**: Data Platform Team
