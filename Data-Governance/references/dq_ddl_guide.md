# DDL 编写规范 · 数据质量检查参考指南

数据质量检查（SKILL-dq）的规则匹配高度依赖 DDL 中的信息。**DDL 写得越规范，检查覆盖越完整；DDL 信息缺失，对应规则会被跳过且标注原因。**

> **建议**：在执行数据质量检查前，先运行表级 DDL 规范检查（SKILL-table）和字段级 DDL 规范检查（SKILL-field），确保 DDL 质量。

---

## 1. 表名：必须包含业务关键词

skill 通过表名中的关键词自动判断表的业务类型（交易类/客户类/账户类/汇总类/映射类），不同类型的表执行不同的规则子集。

| 业务类型      | 表名应包含的关键词                                             | 匹配到的规则                                      |
| ------------- | -------------------------------------------------------------- | ------------------------------------------------- |
| 交易类        | `txn`、`ord`、`trade`、`flow`、`pay`                 | DQ-C-01/02, DQ-A-01/02, DQ-S-01, DQ-U-01, DQ-R-01 |
| 客户/主数据类 | `client`、`customer`、`dim_`                             | DQ-C-03, DQ-A-03/04, DQ-S-02/04, DQ-U-02          |
| 账户/余额类   | `account`、`balance`、`acct`                             | DQ-C-04, DQ-A-05, DQ-U-03                         |
| 汇总/指标类   | 分层前缀 `dws_`/`ads_`，或含 `sum`、`agg`、`profile` | DQ-C-05, DQ-R-02/03                               |
| 映射/字典类   | `dict`、`mapping`、`rel`、`enum`                       | DQ-C-06, DQ-S-03, DQ-U-04                         |
| 通用类        | 以上都不匹配                                                   | 最多匹配 DQ-C-01, DQ-U-01, DQ-U-05（实际数量取决于 DDL 可检查性评估，如主键不可识别则 DQ-C-01/DQ-U-01 也会跳过）|

**✅ 正向案例**：

```sql
-- 表名含 txn → 自动识别为交易类，匹配 7 条规则
CREATE TABLE dwd_crdt_txn (...)

-- 表名含 client + dim_ → 自动识别为客户/主数据类，匹配 6 条规则
CREATE TABLE dim_erp_client (...)

-- 分层前缀 dws_ → 自动识别为汇总/指标类，匹配 3 条规则
CREATE TABLE dws_crdt_daily_summary (...)
```

**❌ 反向案例**：

```sql
-- 表名无任何关键词 → 归为通用类，仅匹配 3 条基础规则，大量规则漏检
CREATE TABLE dwd_crdt_data_detail (...)

-- 表名用拼音 → 无法识别业务类型
CREATE TABLE dwd_crdt_jiaoyi (...)

-- 表名过于笼统 → 无法识别
CREATE TABLE dwd_crdt_info (...)
```

---

## 2. 表注释（COMMENT）：必须描述业务含义

表注释是业务类型识别的辅助依据，也是部分规则的豁免判断依据（如余额表注释含"透支"则豁免 DQ-A-05 负值检查）。

**✅ 正向案例**：

```sql
-- 注释清晰：业务对象 + 记录内容 + 数据粒度
CREATE TABLE dwd_crdt_txn (...)
COMMENT '信贷业务-交易流水明细增量表';

-- 注释含"透支"关键词 → DQ-A-05 自动豁免余额负值检查
CREATE TABLE dwd_crdt_overdraft (...)
COMMENT '信贷业务-账户透支余额日快照表，允许负值';
```

**❌ 反向案例**：

```sql
-- 注释缺失 → 无法辅助识别类型，无法判断豁免
CREATE TABLE dwd_crdt_txn (...)
-- 没有 COMMENT

-- 注释是表名转写，无实际含义
CREATE TABLE dwd_crdt_txn (...)
COMMENT 'dwd crdt txn';

-- 注释过于简单，看不出业务含义
CREATE TABLE dwd_crdt_txn (...)
COMMENT '交易表';
```

---

## 3. 字段命名：使用标准后缀模式

skill 通过字段名的后缀模式自动识别字段类别：

| 字段类别             | 识别模式                                                        | 影响规则                  |
| -------------------- | --------------------------------------------------------------- | ------------------------- |
| 金额字段             | `_amt`、`_amount`、`_price`、`_fee`                     | DQ-A-01（金额负值检查）   |
| 日期字段             | `_dt`、`_date`（排除审计字段）                              | DQ-A-02（日期超未来检查） |
| ID 字段              | `_id`、`_no`（非审计字段）                                  | DQ-C-02（核心字段空值）   |
| 手机号字段           | `phone`、`mobile`                                           | DQ-A-03（格式校验）       |
| 身份证字段           | `id_card`、`cert_no`                                        | DQ-A-03（格式校验）       |
| 年龄字段             | `age`                                                         | DQ-A-04（范围检查）       |
| 余额字段             | `balance`、`bal`                                            | DQ-A-05（余额负值检查）   |
| 审计字段（自动排除） | `create_time`、`insert_time`、`update_time`、`etl_time` | 不参与 DQ-A-02 日期检查   |

**✅ 正向案例**：

```sql
CREATE TABLE dwd_crdt_txn (
  trade_amt     DECIMAL(18,2)  COMMENT '交易金额，单位：元',     -- _amt → DQ-A-01
  fee_amt       DECIMAL(18,2)  COMMENT '手续费，单位：元',       -- _amt → DQ-A-01
  trade_dt      DATE           COMMENT '交易日期',              -- _dt → DQ-A-02
  client_id     STRING         COMMENT '客户ID',               -- _id → DQ-C-02
  ...
)
```

**❌ 反向案例**：

```sql
CREATE TABLE dwd_crdt_txn (
  jine          DECIMAL(18,2)  COMMENT '金额',                  -- 拼音，无法识别为金额字段，DQ-A-01 漏检
  money         DECIMAL(18,2)  COMMENT '钱',                    -- 非标模式，DQ-A-01 漏检
  riqi          DATE           COMMENT '日期',                  -- 拼音，DQ-A-02 漏检
  trade_date_str STRING        COMMENT '交易日期',              -- STRING 存日期，且命名无 _dt 后缀
  uid           STRING         COMMENT '用户',                  -- 非标命名，DQ-C-02 漏检
  ...
)
```

---

## 4. 字段注释 — 主键标识：必须标注"主键"

skill 通过字段 COMMENT 中的关键词（"主键"、"流水号"、"唯一"）识别主键字段，用于 DQ-C-01（主键空值检查）和 DQ-U-01（主键重复检查）。

**✅ 正向案例**：

```sql
  txn_id        STRING         COMMENT '流水号，主键',           -- ✅ 含"主键"
  client_id     STRING         COMMENT '客户唯一标识',           -- ✅ 含"唯一"
  order_no      STRING         COMMENT '订单流水号',             -- ✅ 含"流水号"
```

**❌ 反向案例**：

```sql
  txn_id        STRING         COMMENT '交易ID',                -- ❌ 未标注主键，DQ-C-01/DQ-U-01 跳过
  client_id     STRING         COMMENT '客户编号',              -- ❌ 未标注主键/唯一
  id            BIGINT         COMMENT 'ID',                   -- ❌ 过于笼统
```

---

## 5. 字段注释 — 枚举值域：必须列出所有合法值

对于状态/类型/标志类字段，COMMENT 中必须以 `值-含义` 格式列出所有合法枚举值，skill 据此执行 DQ-S-01（枚举越界检查）。

**✅ 正向案例**：

```sql
  trade_status  STRING  COMMENT '交易状态：S-成功 F-失败 P-处理中',     -- ✅ 值域清晰
  gender        STRING  COMMENT '性别：M-男 F-女',                     -- ✅ 值域清晰
  is_deleted    STRING  COMMENT '是否注销：Y-是 N-否',                  -- ✅ 值域清晰
  loan_type     STRING  COMMENT '贷款类型：01-信用贷 02-抵押贷 03-担保贷', -- ✅ 值域清晰
```

**❌ 反向案例**：

```sql
  trade_status  STRING  COMMENT '交易状态',                            -- ❌ 未定义值域，DQ-S-01 跳过
  status        STRING  COMMENT '状态：成功/失败/处理中',               -- ❌ 有值域但格式不对（不是"值-含义"）
  gender        STRING  COMMENT '性别',                                -- ❌ 完全无值域
  type_code     INT     COMMENT '类型码',                              -- ❌ 枚举字段无值域说明
```

---

## 6. 字段注释 — 必填标识：标注"必填""不能为空"

skill 通过 COMMENT 中的"必填"、"不能为空"、"不可为空"等关键词识别必填字段，用于 DQ-C-03（必填字段空值检查）。

**✅ 正向案例**：

```sql
  client_name   STRING  COMMENT '客户姓名，必填',              -- ✅ 标注"必填"
  cert_no       STRING  COMMENT '证件号码，不能为空',           -- ✅ 标注"不能为空"
  client_id     STRING  COMMENT '客户ID，主键，不可为空',       -- ✅ 标注"不可为空"
```

**❌ 反向案例**：

```sql
  client_name   STRING  COMMENT '客户姓名',                    -- ❌ 未标注必填，DQ-C-03 无法识别
  cert_no       STRING  COMMENT '证件号码',                    -- ❌ 未标注必填
```

---

## 7. 字段注释 — 外键关联：用"关联 表名.字段名"格式

对于映射/字典类表的外键字段，COMMENT 中应以 `关联 表名.字段名` 或 `引用 表名.字段名` 格式声明关联目标，skill 据此执行 DQ-S-03（映射缺失检查）。

**✅ 正向案例**：

```sql
  biz_line      STRING  COMMENT '所属业务线，关联 dim_crdt_biz_line.biz_line_id',    -- ✅ 关联清晰
  product_code  STRING  COMMENT '产品编码，引用 dim_pub_product.product_code',       -- ✅ 引用清晰
  area_code     STRING  COMMENT '区域编码，关联 dim_pub_area.code',                  -- ✅ 关联清晰
```

**❌ 反向案例**：

```sql
  biz_line      STRING  COMMENT '所属业务线',                                        -- ❌ 未声明关联目标，DQ-S-03 跳过
  product_code  STRING  COMMENT '产品编码（来自产品表）',                              -- ❌ 格式不对，无法解析
  area_code     STRING  COMMENT '区域编码，参考区域维表',                              -- ❌ 没有表名.字段名，无法解析
```

---

## 8. 字段注释 — 金额单位：必须注明单位

金额/数量类字段的 COMMENT 应注明单位，虽不直接触发 DQ 规则，但影响检查结果的可读性和人工研判。

**✅ 正向案例**：

```sql
  trade_amt     DECIMAL(18,2)  COMMENT '交易金额，单位：元',         -- ✅ 单位明确
  loan_amt      DECIMAL(18,4)  COMMENT '贷款金额，单位：万元',       -- ✅ 单位明确
  txn_count     INT            COMMENT '交易笔数，单位：笔',         -- ✅ 单位明确
```

**❌ 反向案例**：

```sql
  trade_amt     DECIMAL(18,2)  COMMENT '交易金额',                   -- ❌ 不知是元还是万元
  rate          DECIMAL(10,6)  COMMENT '利率',                       -- ❌ 不知是百分比还是小数
```

---

## 9. 完整正向示例

以下是一张信息完备的 DDL，所有 23 条规则都能正常匹配：

```sql
CREATE TABLE dwd_crdt_txn (
  txn_id        STRING         NOT NULL  COMMENT '流水号，主键',
  client_id     STRING         NOT NULL  COMMENT '客户ID',
  trade_amt     DECIMAL(18,2)            COMMENT '交易金额，单位：元',
  fee_amt       DECIMAL(18,2)            COMMENT '手续费，单位：元',
  trade_status  STRING                   COMMENT '交易状态：S-成功 F-失败 P-处理中',
  trade_dt      DATE                     COMMENT '交易日期',
  biz_line      STRING                   COMMENT '所属业务线，关联 dim_crdt_biz_line.biz_line_id',
  create_time   TIMESTAMP                COMMENT '记录创建时间'
)
COMMENT '信贷业务-交易流水明细增量表'
PARTITIONED BY (dt STRING);
```

**该 DDL 的信息覆盖**：

| 信息项            | DDL 中的体现                                               | 支撑的规则       |
| ----------------- | ---------------------------------------------------------- | ---------------- |
| 业务类型 = 交易类 | 表名含 `txn`                                             | 全部交易类规则   |
| 主键 = txn_id     | COMMENT "主键"                                             | DQ-C-01, DQ-U-01 |
| 核心字段          | `client_id`(_id)、`trade_amt`(_amt)、`trade_dt`(_dt) | DQ-C-02          |
| 金额字段          | `trade_amt`、`fee_amt`(_amt)                           | DQ-A-01          |
| 日期字段          | `trade_dt`(_dt，非审计)                                  | DQ-A-02          |
| 枚举值域          | trade_status 的 `S-成功 F-失败 P-处理中`                 | DQ-S-01          |
| 外键关联          | biz_line 的 `关联 dim_crdt_biz_line.biz_line_id`         | DQ-S-03          |
| 分区字段          | `PARTITIONED BY (dt STRING)`                             | DQ-R-01          |
| 审计字段排除      | `create_time` 自动排除                                   | 不误触发 DQ-A-02 |

---

## 10. 完整反向示例

以下是一张信息缺失严重的 DDL，大部分规则无法匹配：

```sql
CREATE TABLE dwd_crdt_data (
  id            BIGINT                   COMMENT 'ID',
  jine          FLOAT                    COMMENT '金额',
  riqi          STRING                   COMMENT '日期',
  status        INT                      COMMENT '状态',
  ext_info      STRING                   COMMENT '扩展信息'
)
COMMENT '数据表';
```

**该 DDL 的可检查性评估**：

| 评估项   | 状态                                | 影响                             |
| -------- | ----------------------------------- | -------------------------------- |
| 业务类型 | ⚠️ 表名无关键词，归为通用类       | 仅执行 DQ-C-01、DQ-U-01、DQ-U-05 |
| 主键识别 | ⚠️ COMMENT 仅写"ID"，未标注"主键" | DQ-C-01、DQ-U-01 跳过            |
| 金额字段 | ⚠️ 拼音 `jine`，无法识别        | DQ-A-01 跳过                     |
| 日期字段 | ⚠️ 拼音 `riqi` + STRING 类型    | DQ-A-02 跳过                     |
| 枚举值域 | ⚠️ status 无值域定义              | DQ-S-01 跳过                     |
| 分区声明 | ⚠️ 无 PARTITIONED BY              | DQ-R-01 跳过                     |

**结论**：该表 23 条规则中仅 1 条（DQ-U-05 全字段重复）可执行，其余全部跳过。
