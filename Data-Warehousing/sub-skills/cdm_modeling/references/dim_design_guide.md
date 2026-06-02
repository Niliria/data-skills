# CDM DIM设计指南

**版本**: 1.0  
**作者**: Data Platform Team

---

## 📚 目录

1. [维度表设计原则](#维度表设计原则)
2. [一致性维度](#一致性维度)
3. [维度粒度](#维度粒度)
4. [维度属性设计](#维度属性设计)
5. [反范式化策略](#反范式化策略)
6. [完整设计示例](#完整设计示例)

---

## 📐 维度表设计原则

### 1. 业务键是核心

- ✅ **必须包含业务键** - 来自上游系统的唯一标识
- ✅ **业务键不变化** - 永远不变，用于与源系统对账
- ✅ **业务键非空** - 不允许NULL值

```sql
-- 正确示例
customer_id BIGINT NOT NULL COMMENT '客户业务键'
```

### 2. 代理键用于JOIN

- ✅ **生成代理键** - 用于事实表外键关联
- ✅ **代理键自增** - 使用ROW_NUMBER()生成
- ✅ **代理键不变** - 生成后永不改变

```sql
-- 正确示例
customer_sk BIGINT COMMENT '客户代理键（维度主键）'
```

### 3. 维度属性要丰富

- ✅ **包含所有用于分析的属性**
- ✅ **属性描述性要强**
- ✅ **属性来源清晰**

```sql
-- 客户维度属性示例
customer_name STRING COMMENT '客户名称',
customer_level STRING COMMENT '客户等级',
city STRING COMMENT '城市',
state STRING COMMENT '省份',
country STRING COMMENT '国家',
customer_type STRING COMMENT '客户类型'
```

---

## 🤝 一致性维度

### 什么是**一致性维度**？

一致性维度是**跨业务过程共享的维度**，确保不同事实表可以关联分析。

### 设计要点

#### ✅ 正确：统一的维度设计

```sql
-- dim_customer (销售域和库存域共享)
CREATE TABLE dim_customer (
    customer_sk BIGINT,
    customer_id BIGINT,
    customer_name STRING,
    customer_level STRING,
    city STRING,
    state STRING
);

-- dwd_sales_order (使用dim_customer)
CREATE TABLE dwd_sales_order (
    customer_sk BIGINT COMMENT '→ dim_customer',
    ...
);

-- dwd_inventory_transaction (也使用dim_customer)
CREATE TABLE dwd_inventory_transaction (
    customer_sk BIGINT COMMENT '→ dim_customer',
    ...
);
```

#### ❌ 错误：不一致的维度设计

```sql
-- dim_customer_sales (销售域)
CREATE TABLE dim_customer_sales (
    customer_id BIGINT,
    customer_name STRING,
    vip_level STRING  -- ❌ 名称不一致
);

-- dim_customer_inventory (库存域)
CREATE TABLE dim_customer_inventory (
    cust_id BIGINT,  -- ❌ 字段名不一致
    cust_name STRING,
    customer_grade STRING  -- ❌ 名称不一致
);
```

### 优势

- ✅ **跨业务分析** - 可以按客户分析销售+库存
- ✅ **数据一致性** - 同一个客户在不同事实表中属性一致
- ✅ **维护成本低** - 只需维护一个维度表

---

## 📏 维度粒度

### 什么是维度粒度？

**维度粒度 = 一行代表什么业务实体**

### 粒度设计原则

#### ✅ 正确：明确的粒度

```sql
-- dim_customer: 一行 = 一个客户
customer_id BIGINT,  -- 唯一标识一个客户
customer_name STRING,
customer_level STRING
```

#### ❌ 错误：混合粒度

```sql
-- 错误示例：混合了客户+订单信息
CREATE TABLE dim_customer (
    customer_id BIGINT,
    customer_name STRING,
    
    -- ❌ 不应该在维度表中
    order_id BIGINT,
    order_amount DECIMAL(18,2)
);
```

### 常见粒度

| 维度 | 粒度 | 业务键 |
|-----|------|-------|
| 客户 | 一个客户 | customer_id |
| 产品 | 一个SKU | product_id |
| 店铺 | 一个门店 | shop_id |
| 日期 | 一天 | date_id |

---

## 🎨 维度属性设计

### 属性类型

#### 1. 文本属性 (Text Attributes)

```sql
customer_name STRING COMMENT '客户名称',
city STRING COMMENT '城市',
state STRING COMMENT '省份'
```

#### 2. 分类属性 (Categorical Attributes)

```sql
customer_level STRING COMMENT '客户等级',
customer_type STRING COMMENT '客户类型',
status STRING COMMENT '状态'
```

#### 3. 层级属性 (Hierarchical Attributes)

```sql
-- 反范式化存储层级
country STRING COMMENT '国家',
state STRING COMMENT '省份',
city STRING COMMENT '城市',
district STRING COMMENT '区县'
```

#### 4. 日期属性 (Date Attributes)

```sql
registration_date STRING COMMENT '注册日期',
effective_date STRING COMMENT '生效日期'
```

### 属性设计最佳实践

#### ✅ 1. 反范式化存储

```sql
-- 正确：在维度表中冗余存储层级信息
CREATE TABLE dim_product (
    product_id BIGINT,
    product_name STRING,
    
    -- 冗余存储分类层级
    category_level_1 STRING COMMENT '一级分类',
    category_level_2 STRING COMMENT '二级分类',
    category_level_3 STRING COMMENT '三级分类'
);
```

#### ✅ 2. 避免过深的层级

```sql
-- 建议：最多4级层级
country > state > city > district
```

#### ✅ 3. 使用标准编码

```sql
-- 使用标准编码，便于多语言支持
customer_level STRING COMMENT '客户等级(A/B/C/VIP)',
region_code STRING COMMENT '地区编码(国家/省/市标准编码)'
```

---

## 🔄 反范式化策略

### 为什么要反范式化？

- ✅ **查询性能高** - 减少JOIN
- ✅ **分析灵活** - 直接使用属性
- ✅ **易于理解** - 业务人员易懂

### 反范式化示例

#### 示例1：产品维度

```sql
-- 正确：反范式化存储分类信息
CREATE TABLE dim_product (
    product_sk BIGINT,
    product_id BIGINT,
    product_name STRING,
    
    -- 反范式化：包含分类名称
    category_level_1 STRING COMMENT '一级分类',
    category_level_2 STRING COMMENT '二级分类',
    category_level_3 STRING COMMENT '三级分类',
    brand STRING COMMENT '品牌',
    color STRING COMMENT '颜色',
    size STRING COMMENT '尺码'
);
```

#### 示例2：店铺维度

```sql
-- 正确：反范式化存储区域信息
CREATE TABLE dim_shop (
    shop_sk BIGINT,
    shop_id BIGINT,
    shop_name STRING,
    
    -- 反范式化：包含区域层级
    region_level_1 STRING COMMENT '一级区域',
    region_level_2 STRING COMMENT '二级区域',
    city STRING COMMENT '城市',
    manager_name STRING COMMENT '店长姓名',
    manager_id BIGINT COMMENT '店长工号'
);
```

### 反范式化的权衡

| 优点 | 缺点 |
|-----|------|
| 查询性能高 | 存储空间增加 |
| 分析灵活 | 数据冗余 |
| 易于理解 | 维护成本略高 |

**建议**: 维度表反范式化是值得的，因为维度表相对较小。

---

## 📊 完整设计示例

### 示例1：客户维度

```sql
-- ========================================
-- 客户维度表 (SCD Type II)
-- ========================================
CREATE TABLE IF NOT EXISTS dim_customer (
    -- 维度键
    customer_sk BIGINT COMMENT '客户代理键(维度主键)',
    customer_id BIGINT COMMENT '客户业务键(来自ODS)',
    
    -- 基本信息
    customer_name STRING COMMENT '客户名称',
    customer_code STRING COMMENT '客户编码',
    customer_level STRING COMMENT '客户等级(A/B/C/VIP)',
    customer_type STRING COMMENT '客户类型(个人/企业)',
    
    -- 地理信息 (反范式化)
    country STRING COMMENT '国家',
    state STRING COMMENT '省份',
    city STRING COMMENT '城市',
    district STRING COMMENT '区县',
    address STRING COMMENT '详细地址',
    
    -- 联系方式
    mobile STRING COMMENT '手机号',
    email STRING COMMENT '邮箱',
    contact_person STRING COMMENT '联系人',
    
    -- 业务信息
    industry STRING COMMENT '所属行业',
    company_size STRING COMMENT '公司规模',
    business_scope STRING COMMENT '经营范围',
    
    -- 时间属性
    registration_date STRING COMMENT '注册日期(业务日期)',
    first_order_date STRING COMMENT '首次下单日期',
    
    -- 业务标志
    is_active_customer INT COMMENT '是否活跃客户(1=是,0=否)',
    is_vip INT COMMENT '是否VIP客户(1=是,0=否)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '客户维度表 - 记录客户的基本信息、等级、地理信息等'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');
```

### 示例2：产品维度

```sql
-- ========================================
-- 产品维度表 (SCD Type II)
-- ========================================
CREATE TABLE IF NOT EXISTS dim_product (
    -- 维度键
    product_sk BIGINT COMMENT '产品代理键(维度主键)',
    product_id BIGINT COMMENT '产品业务键(来自ODS)',
    
    -- 基本信息
    product_name STRING COMMENT '产品名称',
    product_code STRING COMMENT '产品编码',
    product_sku STRING COMMENT 'SKU编码',
    
    -- 分类层级 (反范式化)
    category_level_1 STRING COMMENT '一级分类',
    category_level_2 STRING COMMENT '二级分类',
    category_level_3 STRING COMMENT '三级分类',
    
    -- 产品属性
    brand STRING COMMENT '品牌',
    model STRING COMMENT '型号',
    color STRING COMMENT '颜色',
    size STRING COMMENT '尺码',
    material STRING COMMENT '材质',
    
    -- 业务信息
    unit_price DECIMAL(18,2) COMMENT '单价(当前售价)',
    cost_price DECIMAL(18,2) COMMENT '成本价',
    supplier_id BIGINT COMMENT '供应商业务键',
    supplier_name STRING COMMENT '供应商名称(反范式化)',
    
    -- 生命周期
    production_date STRING COMMENT '生产日期',
    shelf_life INT COMMENT '保质期(天)',
    warranty_period INT COMMENT '保修期(月)',
    
    -- 业务标志
    is_active_product INT COMMENT '是否在售(1=是,0=否)',
    is_new_product INT COMMENT '是否新品(1=是,0=否)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '产品维度表 - 记录产品的基本信息、分类、属性、供应商等'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');
```

### 示例3：店铺维度

```sql
-- ========================================
-- 店铺维度表 (SCD Type I)
-- ========================================
CREATE TABLE IF NOT EXISTS dim_shop (
    -- 维度键
    shop_sk BIGINT COMMENT '店铺代理键(维度主键)',
    shop_id BIGINT COMMENT '店铺业务键(来自ODS)',
    
    -- 基本信息
    shop_name STRING COMMENT '店铺名称',
    shop_code STRING COMMENT '店铺编码',
    shop_type STRING COMMENT '店铺类型(直营/加盟/代理)',
    
    -- 地理信息 (反范式化)
    region_level_1 STRING COMMENT '一级区域',
    region_level_2 STRING COMMENT '二级区域',
    city STRING COMMENT '城市',
    district STRING COMMENT '区县',
    address STRING COMMENT '详细地址',
    
    -- 联系方式
    phone STRING COMMENT '联系电话',
    manager_name STRING COMMENT '店长姓名',
    manager_id BIGINT COMMENT '店长工号',
    
    -- 业务信息
    business_area DECIMAL(10,2) COMMENT '营业面积(平方米)',
    employee_count INT COMMENT '员工人数',
    opening_date STRING COMMENT '开业日期',
    
    -- 业务标志
    is_active INT COMMENT '是否营业中(1=是,0=否)',
    is_flagship INT COMMENT '是否旗舰店(1=是,0=否)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '店铺维度表 - 记录店铺的基本信息、位置、联系方式等'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');
```

---

## 📝 设计检查清单

### ✅ 必须检查项

- [ ] 是否包含业务键？
- [ ] 是否包含代理键？
- [ ] 业务键是否唯一？
- [ ] 维度粒度是否明确？
- [ ] 是否有冗余的度量值？

### ✅ 推荐检查项

- [ ] 维度属性是否丰富？
- [ ] 是否反范式化存储层级？
- [ ] 是否有一致性维度？
- [ ] 属性命名是否清晰？
- [ ] 是否有业务标志字段？

### ✅ 高级检查项

- [ ] 是否需要SCD Type II？
- [ ] 是否需要垃圾维度？
- [ ] 是否需要桥接表（多值维度）？
- [ ] 属性是否有标准编码？
- [ ] 是否考虑未来扩展？

---

## 🎓 常见问题

### Q1: 什么时候应该使用反范式化？

**答**: 维度表建议反范式化，特别是：
- 分类层级（一级/二级/三级）
- 地理层级（国家/省份/城市）
- 供应商名称（避免每次JOIN）

### Q2: 维度表应该包含多少字段？

**答**: 
- **小型维度** (<20字段): 简单实体，如日期、时间
- **中型维度** (20-50字段): 常见业务实体，如客户、产品
- **大型维度** (>50字段): 复杂实体，如员工（包含人事、薪酬、绩效等）

### Q3: 如何处理多值维度？

**答**: 使用**桥接表**（Bridge Table）处理一对多关系。

示例：一个客户有多个标签
```sql
-- 客户维度 (单值)
CREATE TABLE dim_customer (...);

-- 标签维度
CREATE TABLE dim_tag (...);

-- 桥接表 (客户-标签关联)
CREATE TABLE bridge_customer_tag (
    customer_sk BIGINT,
    tag_sk BIGINT,
    effective_date STRING,
    end_date STRING
);
```

### Q4: 维度表是否需要分区？

**答**: 
- **SCD Type I**: 建议分区，每天快照
- **SCD Type II**: 可选分区，按业务日期或加载日期
- **日期维度**: 不需要分区（数据量小）

---

## 📞 下一步

- 📖 参考 `docs/dwd_design_guide.md` 了解事实表设计
- ⚙️ 查看 `references/mandatory-modeling-rules.md`、`references/field-classification-rules.md` 和 `references/scd-lifecycle-rules.md` 了解当前强制规则
- 🚀 运行 `python scripts/main.py` 生成你的维度表

---

**祝你设计出优秀的维度模型！✨**
