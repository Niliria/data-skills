# SQL 代码风格规范（完整版）

## 一、DDL 规范

### 0. 命名大小写

**表名、列名**：全部**小写**，单词间用下划线 `_` 分隔。  
**SQL 关键字、内置函数**：全部**大写**。

```sql
-- ✅ 正确
CREATE TABLE IF NOT EXISTS dwd_order_detail(
    order_id     STRING COMMENT '订单ID'
    ,order_status STRING COMMENT '订单状态'
)

-- ❌ 错误：表名/列名含大写 / 关键字小写
CREATE Table IF NOT EXISTS DWD_Order_Detail(
    OrderId   string comment '订单ID'
)
select count(order_id) as order_cnt
```

### 1. 文件头：注释 DROP

```sql
-- ✅ 正确：CREATE 前保留注释掉的 DROP
-- DROP TABLE IF EXISTS dwd_order_detail;
CREATE TABLE IF NOT EXISTS dwd_order_detail(

-- ❌ 错误：直接写 CREATE，无 DROP 注释
CREATE TABLE IF NOT EXISTS dwd_order_detail(
```

### 2. 左括号紧跟表名

```sql
-- ✅ 正确
CREATE TABLE IF NOT EXISTS table_name(

-- ❌ 错误：括号换行
CREATE TABLE IF NOT EXISTS table_name
(
```

### 3. 列定义：前导逗号 + 三列对齐

首列无前导逗号；后续列前导逗号 `,` **紧贴**列名（无空格）。  
列名、类型、`COMMENT` 三列**各自对齐**，以最长类型为基准右补空格。

```sql
-- ✅ 正确
CREATE TABLE IF NOT EXISTS table_name(
    a  STRING        COMMENT '主键'
    ,b STRING        COMMENT '名称'
    ,c BIGINT        COMMENT '数量'
    ,d DECIMAL(20,6) COMMENT '金额'
)COMMENT '示例表'

-- ❌ 错误：逗号行尾 / 逗号与列名间有空格 / COMMENT 未对齐
CREATE TABLE IF NOT EXISTS table_name(
    a  STRING COMMENT '主键',
    b STRING COMMENT '名称',
    , c DECIMAL(20,6) COMMENT '金额'
)
```

### 4. 右括号紧跟表注释

```sql
-- ✅ 正确
)COMMENT '订单明细表'

-- ❌ 错误：括号与注释间有空格 / 分行
) COMMENT '订单明细表'
)
COMMENT '订单明细表'
```

### 5. 建表完整模板

```sql
-- DROP TABLE IF EXISTS dwd_order_detail;
CREATE TABLE IF NOT EXISTS dwd_order_detail(
    order_id      STRING        COMMENT '订单ID'
    ,user_id      STRING        COMMENT '用户ID'
    ,order_amount DECIMAL(20,6) COMMENT '订单金额'
    ,order_status STRING        COMMENT '订单状态'
    -- ......
)COMMENT '订单明细表'
PARTITIONED BY (dt STRING COMMENT '业务日期分区')
STORED AS ORC
;
```

---

## 二、DML 规范

### 1. WITH CTE

- `WITH` 前用 `-- 处理xxxx` 注释说明该 CTE 的用途
- 后续每个 CTE 前同样加注释
- CTE 内部遵循与普通 SELECT 相同的格式规范
- 非最后一个 CTE 的 `)` 后紧跟 `,`

```sql
-- ✅ 正确
-- 处理xxxx
WITH v_base AS (
    SELECT id
        , name
    FROM ods_table_a
    WHERE dt = '${bizdate}'
    AND name = 'xxx'
    GROUP BY id
        , name
),
-- 处理xxxx
v_detail AS (
    SELECT id
        , name
    FROM ods_table_b
    WHERE dt = '${bizdate}'
)

-- ❌ 错误：无注释 / CTE 内不换行 / 括号格式乱
WITH v_base AS (SELECT id FROM ods_table_a WHERE dt='xx'),
v_detail AS (
SELECT id FROM ods_table_b
)
```

### 2. INSERT 语句

```sql
-- ✅ 正确
INSERT OVERWRITE TABLE dwd_order_detail PARTITION (dt = '${bizdate}')

-- ❌ 错误：缺少 OVERWRITE / 分区格式不对
INSERT INTO TABLE dwd_order_detail
INSERT OVERWRITE TABLE dwd_order_detail PARTITION(dt='${bizdate}')
```

### 3. SELECT 列：禁止 SELECT \* + 表别名前缀规则 + AS 右对齐

**硬性规则：**

| 规则 | 说明 |
|------|------|
| 禁止 `SELECT *` | 必须显式列出所有需要的字段 |
| **表别名前缀（分层规则）** | 见下方说明 |
| `AS` 右对齐 | 同一 SELECT 块内对齐到统一列位置 |

**字段表别名前缀分层规则：**

| 层级 | 场景 | 规则 |
|------|------|------|
| **最内层** | 直接从**单个真实表** SELECT（无 JOIN） | 不需要给表加别名，字段直接写列名，无前缀 |
| **外层** | 从**子查询** `(…) t1` 或有 **JOIN** 的 SELECT | 子查询必须有别名 t1/t2，字段必须带 `t1.` / `t2.` 前缀 |

```sql
-- ✅ 正确：外层从子查询 SELECT → 需要 t1. 前缀
SELECT t1.org_code        AS sup_code
    , t1.in_amount_total
    , t1.date_ym
FROM
(
    -- ✅ 正确：最内层从真实表 SELECT → 不需要表别名，不需要字段前缀
    SELECT org_code
        , in_amount_total
        , date_ym
    FROM dwd_fin_fund_data
    WHERE dt = '${bizdate}'
    AND COALESCE(in_amount_total, 0) <> 0
) t1

-- ✅ 正确：有 JOIN 的内层 → 必须给所有表加别名并加字段前缀
SELECT t1.order_id                                               AS order_id    -- 订单ID
    , t1.user_id                                                 AS user_id     -- 用户ID
    , COUNT(t2.item_id)                                          AS item_cnt    -- 商品数量
    , SUM(t2.item_amount)                                        AS total_amount -- 总金额
    , IF(t1.next_date IS NULL, '0', t1.next_date)                AS next_date   -- 下次日期
    , COALESCE(t1.id, t2.id)                                     AS id          -- ID
FROM ods_order t1
LEFT JOIN ods_order_item t2
ON t1.order_id = t2.order_id

-- ❌ 错误：SELECT * / 从子查询选字段却无前缀 / 逗号行尾
SELECT *
SELECT org_code, in_amount_total FROM (...) t1   -- 外层无 t1. 前缀
SELECT t1.order_id AS order_id,
    user_id AS user_id
```

其余格式：
- 首列紧跟 SELECT 同行，无前导逗号
- 后续列：4 空格缩进 + `, `（逗号+空格）前导
- 别名后可加行内注释 `-- 注释`（`--` 后有一个空格）

### 4. 函数参数格式

多参数函数，**逗号后加一个空格**。

```sql
-- ✅ 正确
IF(t1.next_date_ym IS NULL, '${bdp.system.bizdate2}', t1.next_date_ym)
COALESCE(t1.id, t2.id)
COUNT(DISTINCT t1.age)

-- ❌ 错误：逗号后无空格
IF(t1.next_date_ym IS NULL,'${bdp.system.bizdate2}',t1.next_date_ym)
COALESCE(t1.id,t2.id)
```

### 5. CASE WHEN

- `CASE WHEN` 与首个条件同行
- 后续 `WHEN` / `ELSE` 与首个 `WHEN` 对齐
- `END` 在最后一个分支同行，后跟 `AS alias`

```sql
-- ✅ 正确
    , CASE WHEN t1.status = '1' THEN '已支付'
           WHEN t1.status = '2' THEN '已发货'
           ELSE '未知' END                                        AS status_name -- 状态

-- ❌ 错误：WHEN 不对齐 / END 单独成行
    , CASE
        WHEN t1.status = '1' THEN '已支付'
        ELSE '未知'
      END AS status_name
```

### 6. 窗口函数

整体写在一行，`OVER(` 紧跟聚合函数。

```sql
-- ✅ 正确
    , SUM(t1.amount) OVER(PARTITION BY t1.user_id ORDER BY t1.dt DESC) AS cum_amount

-- ❌ 错误：OVER 换行
    , SUM(t1.amount)
      OVER(PARTITION BY t1.user_id ORDER BY t1.dt DESC) AS cum_amount
```

### 7. FROM / 子查询 / JOIN

- `FROM` / `LEFT JOIN` / `INNER JOIN` 各自独占一行
- `(` 另起一行与 FROM/JOIN 同缩进，内容缩进 4 空格
- `)` 与 `(` 同缩进，紧跟别名 `) t1`
- 子查询内部可用 `-- 查询xxxx` 说明用途（`--` 后有空格）

```sql
-- ✅ 正确
FROM
(
    -- 查询主订单
    SELECT t1.order_id    AS order_id
        , t1.user_id      AS user_id
    FROM
    (
        SELECT DISTINCT order_id
            , user_id
        FROM ods_order
        WHERE dt = '${bizdate}'
        AND status = '1'
    ) t1
    INNER JOIN
    (
        -- 查询商品明细
        SELECT order_id
            , item_id
        FROM ods_order_item
        WHERE dt = '${bizdate}'
    ) t2
    ON t1.order_id = t2.order_id
    AND t1.user_id = t2.user_id
) t1
LEFT JOIN
(
    -- 查询用户信息
    SELECT user_id
        , user_name
    FROM ods_user
    WHERE dt = '${bizdate}'
) t2
ON t1.user_id = t2.user_id
WHERE t2.user_name IS NOT NULL

-- ❌ 错误：( 不单独成行 / JOIN 不换行
FROM (SELECT order_id FROM ods_order) t1
LEFT JOIN ods_user t2 ON t1.user_id = t2.user_id
```

### 8. WHERE / AND 条件

首个条件与 `WHERE` 同行；`AND` 与 `WHERE` 对齐（无额外缩进）。

```sql
-- ✅ 正确
WHERE dt = '${bizdate}'
AND user_id = '1001'
AND COALESCE(amount, 0) <> 0

-- ❌ 错误
WHERE dt = '${bizdate}' AND user_id = '1001'
WHERE dt = '${bizdate}'
    AND user_id = '1001'
```

### 9. ON 条件

`ON` 与 `AND` 对齐（无额外缩进）。

```sql
-- ✅ 正确
ON t1.order_id = t2.order_id
AND t1.user_id = t2.user_id

-- ❌ 错误
ON t1.order_id = t2.order_id
    AND t1.user_id = t2.user_id
```

### 10. GROUP BY

单列跟在 `GROUP BY` 同行；多列使用前导逗号换行，缩进 4 空格。

```sql
-- ✅ 正确（单列）
GROUP BY id

-- ✅ 正确（多列）
GROUP BY id
    , name
    , age

-- ❌ 错误
GROUP BY id, name, age
GROUP BY
    id,
    name
```

### 11. HAVING / ORDER BY

各自独占一行，跟在 GROUP BY 之后。

```sql
-- ✅ 正确
GROUP BY id
    , name
HAVING COUNT(age) > 1
ORDER BY id ASC

-- ❌ 错误：与 GROUP BY 同行
GROUP BY id HAVING COUNT(age) > 1 ORDER BY id
```

### 12. UNION ALL

`UNION ALL` 独占一行；前后各留一空行分隔两段 SELECT。

```sql
-- ✅ 正确
SELECT id
    , name
FROM ods_table_a
WHERE dt = '${bizdate}'

UNION ALL

-- 查询备用数据
SELECT id
    , name
FROM ods_table_b
WHERE dt = '${bizdate}'

-- ❌ 错误：无空行 / 与 SELECT 同行
SELECT id FROM ods_table_a UNION ALL SELECT id FROM ods_table_b
```

### 13. 脚本头部注释

每个 SQL 文件**顶部**必须有元数据注释块，包含脚本名称、功能描述、输入/输出表、作者和修改记录。

```sql
-- =============================================================================
-- 脚本名称: dwd_order_detail.sql
-- 功能描述: 订单明细事实表，粒度为每笔订单
-- 输入表:   ods.ods_order, ods.ods_order_item
-- 输出表:   dw.dwd_order_detail
-- 作者:     xxx
-- 创建日期: 2026-04-16
-- 修改记录:
--   2026-04-16  xxx  初始创建
--   2026-04-20  xxx  新增 order_status 字段
-- =============================================================================
```

> 修改记录按时间**升序**追加，不删除历史记录。

### 14. EXISTS / IN 子查询格式

**EXISTS**：`WHERE EXISTS` 后换行，`(` 另起一行，内部遵循标准子查询格式。  
**IN 子查询**：同 EXISTS；**IN 字面量列表**可单行。

```sql
-- ✅ 正确：EXISTS
WHERE EXISTS
(
    SELECT 1
    FROM ods_table_b t2
    WHERE t2.id = t1.id
    AND t2.status = '1'
)

-- ✅ 正确：IN 子查询
WHERE t1.id IN
(
    SELECT t2.id
    FROM ods_table_b t2
    WHERE t2.dt = '${bizdate}'
)

-- ✅ 正确：IN 字面量（短列表可单行）
WHERE t1.status IN ('1', '2', '3')

-- ❌ 错误：( 不换行 / EXISTS 后不换行
WHERE EXISTS (SELECT 1 FROM ods_table_b t2 WHERE t2.id = t1.id)
WHERE t1.id IN (SELECT t2.id FROM ods_table_b)
```

### 15. LATERAL VIEW / EXPLODE

- `LATERAL VIEW` 独占一行，紧跟 FROM 子句或主表之后
- `EXPLODE(字段)` 紧跟 `LATERAL VIEW`，无换行
- 展开后的虚拟表别名和列别名跟在 `AS` 后
- 多个 `LATERAL VIEW` 纵向对齐（虚拟表别名、列别名各自对齐）

```sql
-- ✅ 正确
FROM ods_table_a t1
LATERAL VIEW EXPLODE(t1.items) t_item AS item_id
LATERAL VIEW EXPLODE(t1.tags)  t_tag  AS tag_name

-- ✅ 正确：与子查询结合
FROM
(
    SELECT t1.id
        , t1.items
        , t1.tags
    FROM ods_table_a t1
    WHERE t1.dt = '${bizdate}'
) t1
LATERAL VIEW EXPLODE(t1.items) t_item AS item_id
LATERAL VIEW EXPLODE(t1.tags)  t_tag  AS tag_name

-- ❌ 错误：EXPLODE 换行 / 多个 LATERAL VIEW 不对齐
FROM ods_table_a t1
LATERAL VIEW
EXPLODE(t1.items) t_item AS item_id
LATERAL VIEW EXPLODE(t1.tags) t_tag AS tag_name
```

---

---

## 三、完整参考模板

```sql
-- DROP TABLE IF EXISTS table_name;
CREATE TABLE IF NOT EXISTS table_name(
    a  STRING        COMMENT '测试'
    ,b STRING        COMMENT '测试B'
    ,c DECIMAL(20,6) COMMENT '测试c'
    -- ......
)COMMENT '测试用表'
PARTITIONED BY (dt STRING COMMENT '分区字段')
STORED AS ORC
;

-- 处理xxxx
WITH v_xxx AS (
    SELECT id
    FROM table_name
    WHERE dt = '${bizdate}'
    AND name = 'xxx'
    GROUP BY id
),
-- 处理xxxx
v_yyy AS (
    SELECT id
    FROM table_name
    WHERE dt = '${bizdate}'
    AND name = 'yyy'
    GROUP BY id
)

INSERT OVERWRITE TABLE table_name PARTITION (dt = '${bizdate}')
SELECT t1.id                                                      AS a   -- id
    , COUNT(t2.name)                                              AS b   -- name
    , SUM(t2.name)                                                AS c   -- 测试
    , MIN(t2.name)                                                AS d   -- 测试A
    , CASE WHEN t1.id IS NOT NULL THEN 'a'
           WHEN t1.id <> 'a'      THEN 'b'
           ELSE 'c' END                                           AS e   -- 测试e
    , SUM(t1.name) OVER(PARTITION BY t1.id ORDER BY t1.name DESC) AS f  -- 测试f
    , IF(t1.next_date_ym IS NULL, '1', t1.next_date_ym)           AS xx  -- 文本
    , COALESCE(t1.id, t2.id)                                      AS idd -- xx
    , (t1.name + t2.id)                                           AS cc
FROM
(
    SELECT t1.id    AS id
        , t1.name   AS name
    FROM
    (
        -- 查询 xxxx
        SELECT DISTINCT id
            , name
            , IF(next_date_ym IS NULL, '${bdp.system.bizdate2}', next_date_ym) AS next_date_ym
        FROM ods_table_a
        WHERE dt = '${bizdate}'
        AND id = ''
        AND name = ''
        AND COALESCE(in_amount_total, 0) <> 0

        UNION ALL

        -- 查询 xxxx
        SELECT id
            , name
        FROM ods_table_a
        WHERE dt = '${bizdate}'
        AND id = 'xxx'
    ) t1
    INNER JOIN
    (
        -- 查询 xxxx
        SELECT id
            , name
            , age
            , COUNT(DISTINCT age) AS xx
        FROM ods_table_c
        WHERE dt = '${bizdate}'
        AND id = 'C'
        GROUP BY id
            , name
            , age
        HAVING COUNT(age) > 1
        ORDER BY id ASC
    ) t2
    ON t1.id = t2.id
    AND t1.name = t2.name
) t1
LEFT JOIN
(
    -- 查询xxxx
    SELECT id
        , name
    FROM ods_table_b
    WHERE dt = '${bizdate}'
) t2
ON t1.id = t2.id
AND t1.name = t2.name
WHERE t2.sup_code IS NULL
;
```

---

## 四、规范速查表

| 分类 | 规则要点 |
|------|---------|
| **命名** | 表名、列名全部**小写**，下划线分隔 |
| **关键字/函数** | SQL 关键字、内置函数全部**大写** |
| 缩进 | 4 空格，禁用 Tab |
| 表别名 | 使用 t1, t2, t3 顺序命名 |
| 逗号（DDL） | 前导逗号，紧贴列名，无空格 |
| 逗号（DML） | 前导逗号 + 空格（`, `），4 空格缩进 |
| DDL 列对齐 | 列名、类型、COMMENT 三列各自对齐；以最长类型为基准 |
| AS 对齐 | 同一 SELECT 块内右对齐到统一列 |
| 行内注释 | `-- ` 后跟空格再写注释内容 |
| 语句结尾 | 独立一行的 `;` |
| 分区 | `PARTITION (dt = '${bizdate}')` 等号两侧有空格 |
| WITH CTE | 每个 CTE 前加 `-- 处理xxxx` 注释；内部同 SELECT 规范 |
| GROUP BY 多列 | 前导逗号换行，缩进 4 空格 |
| HAVING / ORDER BY | 各占独立一行，跟在 GROUP BY 后 |
| UNION ALL | 独占一行，前后各留一空行 |
| **禁止 SELECT \*** | 必须显式列出所有字段 |
| **字段表别名前缀** | 最内层从真实表 SELECT：无前缀；外层从子查询/JOIN SELECT：必须带 `t1.`/`t2.` 前缀 |
| **函数参数逗号** | 多参数函数逗号后加空格：`IF(a, b, c)` |
| 子查询注释 | `-- 查询xxxx` 写在子查询 `(` 内首行 |
| 脚本头部注释 | 每个文件顶部含名称、功能、输入/输出表、作者、修改记录 |
| EXISTS/IN 子查询 | `WHERE EXISTS` 后换行，`(` 另起一行；IN 字面量可单行 |
| LATERAL VIEW | 独占一行紧跟 FROM，多个时纵向对齐 |
