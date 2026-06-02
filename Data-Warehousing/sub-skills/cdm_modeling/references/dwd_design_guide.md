# CDM DWD设计指南

**版本**: 1.0  
**作者**: Data Platform Team

---

## 📚 目录

1. [事实表设计原则](#事实表设计原则)
2. [事实表粒度](#事实表粒度)
3. [度量值设计](#度量值设计)
4. [维度外键设计](#维度外键设计)
5. [星形模式](#星形模式)
6. [完整设计示例](#完整设计示例)

---

## 📐 事实表设计原则

### 1. 粒度是核心

- ✅ **粒度必须明确** - 每行代表什么业务事件
- ✅ **粒度必须一致** - 同一事实表的所有行粒度相同
- ✅ **优先原子粒度** - 最细粒度支持所有分析需求

### 2. 度量值可加总

- ✅ **包含可加总数值** - 用于聚合分析
- ✅ **明确聚合规则** - SUM/AVG/MIN/MAX
- ✅ **度量与粒度匹配** - 在正确粒度级别定义

### 3. 维度外键精简

- ✅ **只包含直接相关的维度**
- ✅ **使用代理键（SK）而非业务键**
- ✅ **避免过度冗余属性**

---

## 📏 事实表粒度

### 什么是事实表粒度？

**粒度 = 一行事实表代表什么业务事件**

### 粒度设计示例

#### 示例1：订单级别（粗粒度）

```sql
-- dwd_sales_order_di
-- 一行 = 一个订单（可能包含多个订单行）
CREATE TABLE dwd_sales_order_di (
    order_id STRING COMMENT '订单业务键',
    order_sk BIGINT COMMENT '订单代理键',
    
    -- 维度外键
    customer_sk BIGINT,
    shop_sk BIGINT,
    date_sk BIGINT,
    
    -- 度量值（订单级）
    order_amount DECIMAL(18,2),  -- 订单总金额
    order_quantity BIGINT,       -- 订单总数量
    
    -- ❌ 错误：不应该包含订单行级的字段
    -- product_id (每个订单可能有多个产品)
    -- line_amount (订单行金额)
);
```

#### 示例2：订单行级别（细粒度）

```sql
-- dwd_sales_order_line_di
-- 一行 = 一条订单行
CREATE TABLE dwd_sales_order_line_di (
    order_line_id STRING COMMENT '订单行业务键',
    order_line_sk BIGINT COMMENT '订单行代理键',
    
    -- 维度外键
    order_sk BIGINT,        -- 关联订单
    customer_sk BIGINT,
    product_sk BIGINT,
    shop_sk BIGINT,
    date_sk BIGINT,
    
    -- 度量值（订单行级）
    line_amount DECIMAL(18,2),  -- 订单行金额
    line_quantity BIGINT,       -- 订单行数量
    unit_price DECIMAL(18,2)    -- 单价
);
```

### 粒度选择原则

#### ✅ 优先选择原子粒度

```sql
-- 原子粒度：订单行级别
-- 优点：支持所有分析需求
-- 可以向上聚合到订单级、客户级、产品级等

-- 从订单行聚合到订单级
SELECT 
    order_sk,
    SUM(line_amount) AS order_amount,
    SUM(line_quantity) AS order_quantity
FROM dwd_sales_order_line_di
GROUP BY order_sk;
```

#### ❌ 避免重复计算问题

```sql
-- 错误示例：混合粒度
CREATE TABLE dwd_sales_mixed_di (
    order_id STRING,
    
    -- ❌ 混合了订单级和订单行级度量
    order_amount DECIMAL(18,2),  -- 订单总金额
    line_amount DECIMAL(18,2),   -- 订单行金额
    
    product_id BIGINT  -- ❌ 一个订单可能有多个产品
);
-- 问题：按order_id聚合时，line_amount会产生重复计算
```

---

## 📊 度量值设计

### 度量值类型

#### 1. 可加性度量 (Additive Measures)

**可在所有维度上求和**

```sql
-- 示例：数量、金额
quantity BIGINT COMMENT '数量(聚合函数:SUM)',
amount DECIMAL(18,2) COMMENT '金额(聚合函数:SUM)',
count BIGINT COMMENT '计数(聚合函数:SUM)'
```

#### 2. 半可加性度量 (Semi-Additive Measures)

**只在某些维度上可求和**

```sql
-- 示例：余额、库存数量
balance DECIMAL(18,2) COMMENT '余额(聚合函数:LAST_VALUE)',
inventory_qty BIGINT COMMENT '库存数量(聚合函数:LAST_VALUE)'

-- ❌ 不能按时间维度求和（余额不能跨时间累加）
-- ✅ 可以按客户、产品等维度求和（同一时间点的余额）
```

#### 3. 不可加性度量 (Non-Additive Measures)

**不能直接求和**

```sql
-- 示例：单价、百分比、汇率
unit_price DECIMAL(18,2) COMMENT '单价(聚合函数:AVG)',
discount_rate DECIMAL(5,2) COMMENT '折扣率(聚合函数:AVG)',
exchange_rate DECIMAL(10,4) COMMENT '汇率(聚合函数:AVG)'

-- ❌ 不能求和
-- ✅ 需要重新计算（如：总价/总数量 = 平均单价）
```

### 度量值命名规范

| 度量类型 | 后缀 | 示例 |
|---------|------|------|
| 金额 | `_amount` | `order_amount` |
| 价格 | `_price` | `unit_price` |
| 费用 | `_fee` | `shipping_fee` |
| 折扣 | `_discount` | `discount_amount` |
| 营收 | `_revenue` | `sales_revenue` |
| 成本 | `_cost` | `product_cost` |
| 数量 | `_qty` | `order_qty` |
| 计数 | `_count` | `item_count` |

### 度量值设计示例

```sql
-- dwd_sales_order_di
CREATE TABLE dwd_sales_order_di (
    -- 事实键
    order_id STRING,
    order_sk BIGINT,
    
    -- 维度外键
    customer_sk BIGINT,
    product_sk BIGINT,
    shop_sk BIGINT,
    date_sk BIGINT,
    
    -- 可加性度量
    order_amount DECIMAL(18,2) COMMENT '订单金额(聚合函数:SUM)',
    order_qty BIGINT COMMENT '订单数量(聚合函数:SUM)',
    item_count BIGINT COMMENT '商品件数(聚合函数:SUM)',
    
    -- 半可加性度量
    shipping_fee DECIMAL(18,2) COMMENT '运费(聚合函数:SUM)',  -- 按订单可加
    
    -- 不可加性度量（谨慎使用）
    discount_rate DECIMAL(5,2) COMMENT '折扣率(聚合函数:AVG)'  -- 需要重新计算
    
    -- ❌ 避免：平均单价（应该用SUM(amount)/SUM(qty)计算）
    -- avg_unit_price DECIMAL(18,2)
);
```

---

## 🔗 维度外键设计

### 外键命名规范

```sql
-- 格式：{dimension}_sk
customer_sk BIGINT COMMENT '→ dim_customer(外键)',
product_sk BIGINT COMMENT '→ dim_product(外键)',
shop_sk BIGINT COMMENT '→ dim_shop(外键)',
date_sk BIGINT COMMENT '→ dim_date(外键)'
```

### 外键设计原则

#### ✅ 1. 使用代理键（SK）而非业务键

```sql
-- 正确：使用代理键
customer_sk BIGINT COMMENT '→ dim_customer(外键)',

-- 错误：直接使用业务键（无法处理SCD）
customer_id BIGINT  -- ❌ 无法追踪维度历史变化
```

#### ✅ 2. 只包含直接相关的维度

```sql
-- dwd_sales_order_di
-- 只包含与销售直接相关的维度
customer_sk BIGINT,     -- 直接相关
product_sk BIGINT,      -- 直接相关
shop_sk BIGINT,         -- 直接相关
date_sk BIGINT,         -- 直接相关
employee_sk BIGINT      -- ✅ 如果需要追踪销售员

-- ❌ 避免：过度包含维度
-- supplier_sk          -- ❌ 产品供应商（间接关系）
-- region_sk            -- ❌ 地区（可通过shop_sk关联）
-- category_sk          -- ❌ 分类（可通过product_sk关联）
```

#### ✅ 3. 处理缺失值

```sql
-- 使用COALESCE处理缺失的维度
COALESCE(dim_customer.customer_sk, -1) AS customer_sk

-- -1 表示未知/缺失
-- 分析时可以过滤：WHERE customer_sk != -1
```

### 外键关联示例

```sql
-- ETL加载：关联维度获取SK
INSERT OVERWRITE TABLE dwd_sales_order_di
SELECT
    source.order_id,
    ROW_NUMBER() OVER (ORDER BY source.order_id) AS order_sk,
    
    -- 维度外键
    COALESCE(dim_customer.customer_sk, -1) AS customer_sk,
    COALESCE(dim_product.product_sk, -1) AS product_sk,
    COALESCE(dim_shop.shop_sk, -1) AS shop_sk,
    COALESCE(dim_date.date_sk, -1) AS date_sk,
    
    -- 度量值
    source.order_amount,
    source.order_qty
FROM dws_sales_order_di source
LEFT JOIN dim_customer ON source.customer_id = dim_customer.customer_id
    AND dim_customer.is_active = 1
LEFT JOIN dim_product ON source.product_id = dim_product.product_id
    AND dim_product.is_active = 1
LEFT JOIN dim_shop ON source.shop_id = dim_shop.shop_id
    AND dim_shop.is_active = 1
LEFT JOIN dim_date ON source.order_date = dim_date.calendar_date
WHERE source.pt = '${bizdate}';
```

---

## ⭐ 星形模式

### 什么是星形模式？

**星形模式 = 一个事实表 + 多个维度表**

```
         dim_date
             │
             │
dim_customer ─┼─ dwd_sales_order_di ─┼─ dim_product
             │                       │
         dim_shop                dim_shop
```

### 星形模式的优势

- ✅ **查询性能高** - 直接JOIN，无需多层关联
- ✅ **易于理解** - 业务人员易懂
- ✅ **分析灵活** - 支持任意维度组合分析

### 星形模式示例

```sql
-- 示例：按地区、客户等级、商品品类统计销售额
SELECT
    dr.region_name,           -- 来自dim_region
    dc.customer_level,        -- 来自dim_customer
    dp.category_level_1,      -- 来自dim_product
    dd.year_month,            -- 来自dim_date
    SUM(dwd.order_amount) AS total_sales,
    COUNT(DISTINCT dwd.customer_sk) AS unique_customers,
    SUM(dwd.order_qty) AS total_qty
FROM dwd_sales_order_di dwd
INNER JOIN dim_date dd ON dwd.date_sk = dd.date_sk
INNER JOIN dim_customer dc ON dwd.customer_sk = dc.customer_sk
INNER JOIN dim_product dp ON dwd.product_sk = dp.product_sk
INNER JOIN dim_region dr ON dc.region_sk = dr.region_sk
WHERE dd.year_month >= '202501'
GROUP BY dr.region_name, dc.customer_level, dp.category_level_1, dd.year_month
ORDER BY total_sales DESC;
```

### 避免雪花模式（除非必要）

```sql
-- ❌ 雪花模式（过度规范化）
dwd_sales_order_di
    └── customer_sk → dim_customer
        └── region_id → dim_region  -- ❌ 多层关联，性能差

-- ✅ 星形模式（反范式化）
dwd_sales_order_di
    ├── customer_sk → dim_customer (包含region_name)
    └── region_sk → dim_region      -- ✅ 直接关联，性能高
```

---

## 📊 完整设计示例

### 示例1：销售订单事实表

```sql
-- ========================================
-- 销售订单事实表
-- 粒度：订单行级别
-- ========================================
CREATE TABLE IF NOT EXISTS dwd_sales_order_line_di (
    -- 事实键
    order_line_id STRING COMMENT '订单行业务键(来自ODS)',
    order_line_sk BIGINT COMMENT '订单行代理键(事实主键)',
    
    -- 维度外键
    order_sk BIGINT COMMENT '→ dim_sales_order(订单代理键)',
    customer_sk BIGINT COMMENT '→ dim_customer(客户代理键)',
    product_sk BIGINT COMMENT '→ dim_product(产品代理键)',
    shop_sk BIGINT COMMENT '→ dim_shop(店铺代理键)',
    date_sk BIGINT COMMENT '→ dim_date(日期代理键)',
    employee_sk BIGINT COMMENT '→ dim_employee(销售员代理键)',
    
    -- 可加性度量
    line_amount DECIMAL(18,2) COMMENT '订单行金额(聚合函数:SUM)',
    line_qty BIGINT COMMENT '订单行数量(聚合函数:SUM)',
    item_count BIGINT COMMENT '商品件数(聚合函数:SUM)',
    
    -- 半可加性度量
    shipping_fee DECIMAL(18,2) COMMENT '运费(聚合函数:SUM)',
    discount_amount DECIMAL(18,2) COMMENT '折扣金额(聚合函数:SUM)',
    
    -- 不可加性度量（谨慎）
    unit_price DECIMAL(18,2) COMMENT '单价(聚合函数:AVG)',
    discount_rate DECIMAL(5,2) COMMENT '折扣率(聚合函数:AVG)',
    
    -- 业务标志
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',
    is_returned INT COMMENT '是否退货(1=是,0=否)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '销售订单事实表 - 记录每条订单行的销售信息'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
```

### 示例2：库存变动事实表

```sql
-- ========================================
-- 库存变动事实表
-- 粒度：库存变动事件级别
-- ========================================
CREATE TABLE IF NOT EXISTS dwd_inventory_transaction_di (
    -- 事实键
    transaction_id STRING COMMENT '库存变动业务键(来自ODS)',
    transaction_sk BIGINT COMMENT '库存变动代理键(事实主键)',
    
    -- 维度外键
    product_sk BIGINT COMMENT '→ dim_product(产品代理键)',
    shop_sk BIGINT COMMENT '→ dim_shop(店铺代理键)',
    date_sk BIGINT COMMENT '→ dim_date(日期代理键)',
    supplier_sk BIGINT COMMENT '→ dim_supplier(供应商代理键)',
    employee_sk BIGINT COMMENT '→ dim_employee(操作员代理键)',
    
    -- 可加性度量
    change_qty BIGINT COMMENT '变动数量(聚合函数:SUM)',
    change_amount DECIMAL(18,2) COMMENT '变动金额(聚合函数:SUM)',
    
    -- 库存快照（半可加性）
    before_qty BIGINT COMMENT '变动前库存数量(聚合函数:LAST_VALUE)',
    after_qty BIGINT COMMENT '变动后库存数量(聚合函数:LAST_VALUE)',
    
    -- 不可加性度量
    unit_cost DECIMAL(18,2) COMMENT '单位成本(聚合函数:AVG)',
    
    -- 业务标志
    transaction_type STRING COMMENT '变动类型(入库/出库/调拨/盘点)',
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '库存变动事实表 - 记录每次库存变动的详细信息'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
```

### 示例3：客户行为事实表

```sql
-- ========================================
-- 客户行为事实表
-- 粒度：单次行为事件级别
-- ========================================
CREATE TABLE IF NOT EXISTS dwd_customer_behavior_di (
    -- 事实键
    behavior_id STRING COMMENT '行为业务键(来自ODS)',
    behavior_sk BIGINT COMMENT '行为代理键(事实主键)',
    
    -- 维度外键
    customer_sk BIGINT COMMENT '→ dim_customer(客户代理键)',
    product_sk BIGINT COMMENT '→ dim_product(产品代理键)',
    date_sk BIGINT COMMENT '→ dim_date(日期代理键)',
    channel_sk BIGINT COMMENT '→ dim_channel(渠道代理键)',
    
    -- 可加性度量
    view_count BIGINT COMMENT '浏览次数(聚合函数:SUM)',
    click_count BIGINT COMMENT '点击次数(聚合函数:SUM)',
    add_cart_count BIGINT COMMENT '加购次数(聚合函数:SUM)',
    
    -- 时间度量
    dwell_time INT COMMENT '停留时长(秒,聚合函数:SUM)',
    scroll_depth INT COMMENT '滚动深度(百分比,聚合函数:AVG)',
    
    -- 业务标志
    behavior_type STRING COMMENT '行为类型(浏览/点击/收藏/购买)',
    is_converted INT COMMENT '是否转化(1=是,0=否)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统',
    
    -- 分区字段
    pt STRING COMMENT '分区日期(业务日期)'
)
COMMENT '客户行为事实表 - 记录客户的每一次行为事件'
PARTITIONED BY (pt STRING)
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
```

---

## 📝 事实表设计检查清单

### ✅ 必须检查项

- [ ] 粒度是否明确？
- [ ] 所有行的粒度是否一致？
- [ ] 是否有可加总度量值？
- [ ] 维度外键是否使用SK？
- [ ] 是否有日期维度？

### ✅ 推荐检查项

- [ ] 度量值类型是否明确（可加性/半可加性/不可加性）？
- [ ] 维度外键是否只包含直接相关的维度？
- [ ] 是否有业务标志字段？
- [ ] 是否有数据质量检查？

### ✅ 高级检查项

- [ ] 是否需要累积快照事实表？
- [ ] 是否需要周期快照事实表？
- [ ] 是否需要处理多币种？
- [ ] 是否需要处理多时区？

---

## 🎓 常见问题

### Q1: 事实表和维度表的比例应该是多少？

**答**: 
- **事实表**：通常占80-90%的数据量
- **维度表**：通常占10-20%的数据量
- **行数对比**：事实表可能是亿级，维度表是百万级

### Q2: 事实表是否需要主键？

**答**: 
- **建议**：使用代理键（SK）作为主键
- **作用**：
  - 唯一标识每行事实
  - 支持后续的ETL更新
  - 便于数据质量检查

### Q3: 如何处理度量值的精度？

**答**: 
- **金额**：`DECIMAL(18,2)` 或 `DECIMAL(20,4)`（高精度）
- **数量**：`BIGINT`（整数）
- **百分比**：`DECIMAL(5,2)`（两位小数）
- **比率**：`DECIMAL(10,4)`（四位小数）

### Q4: 事实表是否需要分区？

**答**: 
- **必须分区**：按业务日期（pt）分区
- **分区字段**：`pt STRING`（格式：YYYYMMDD）
- **优势**：
  - 查询性能：只扫描相关分区
  - 数据管理：按天清理过期数据
  - 增量加载：按天增量更新

---

## 📞 下一步

- 📖 参考 `docs/dim_design_guide.md` 了解维度表设计
- ⚙️ 查看 `references/mandatory-modeling-rules.md`、`references/field-classification-rules.md` 和 `references/anti-patterns.md` 了解当前强制规则
- 🚀 运行 `python scripts/main.py` 生成你的事实表

---

**祝你设计出优秀的事实模型！✨**
