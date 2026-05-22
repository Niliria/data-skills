---
name: 数据治理-数据质量规范检查
description: >
  基于 DDL/SQL 自动识别表的业务类型，推断该类数据应有的质量规则，
  连接数仓逐条执行检查，生成数据质量报告。
  覆盖完整性、准确性、一致性、唯一性、合理性五个维度，共 23 条内置规则 + 自定义规则支持。
  当用户提到"数据质量"、"DQ 检查"、"数据质量规范"、"质量规则"、"数据干净"、
  "空值检查"、"重复检查"、"格式校验"等诉求时触发此 skill。
  需要提供数仓连接配置（host、port、database、用户名、密码）。
  输出为 Excel 文件，上半部分是明细问题，下半部分是检查摘要。
---
# 数据治理 · 数据质量规范检查

## 概述

本 skill 从**业务和数据内容层面**对 Hive 数仓表进行数据质量检查。不同于其他子 skill 仅检查代码规范，本 skill 会：

1. 根据 DDL 中的表名/注释/字段结构，自动识别每张表的**业务类型**（交易类、客户类、账户类、汇总类、映射类）
2. 基于业务类型，从内置规则库中**推断该类数据应有的质量规则**
3. 生成可执行的 Hive 检查 SQL，**连接数仓实际执行**
4. 收集执行结果，生成**数据质量 Excel 报告**

覆盖以下五个维度：

1. **完整性**（DQ-C-01 ～ DQ-C-06）— 主键空值、核心字段空值、必填字段空值
2. **准确性**（DQ-A-01 ～ DQ-A-05）— 金额负值、日期超未来、格式校验、年龄范围、余额负值
3. **一致性**（DQ-S-01 ～ DQ-S-04）— 枚举越界、属性冲突、映射缺失、状态异常
4. **唯一性**（DQ-U-01 ～ DQ-U-05）— 主键重复、ID 重复、多余额、键重复、全字段重复
5. **合理性**（DQ-R-01 ～ DQ-R-03）— 数据量波动、分区缺失、分区波动

输入为：

- **数仓连接配置**：host、port、database、用户名、密码
- **DDL 文档**：包含一个或多个 `CREATE TABLE` 语句
- **SQL 文档**（可选）：包含 INSERT/SELECT 的加工语句，用于辅助类型识别和关联检查
- **自定义规则**（可选）：用户自定义的业务规则 SQL

输出为 **Excel 文件**，上半部分是明细问题，下半部分是检查摘要。

> **边界说明**：本 skill 检查数据本身的质量（空值、重复、格式、波动等）。表命名规范、字段命名规范、SQL 写法规范、血缘健康度请使用配套的子 skill（[SKILL-table.md](SKILL-table.md)、[SKILL-field.md](SKILL-field.md)、[SKILL-sql.md](SKILL-sql.md)、[SKILL-lineage.md](SKILL-lineage.md)）。

---

## 前置要求

### 数仓连接配置

用户必须提供数仓连接信息，格式为 YAML 或在输入消息中提供以下字段：

| 字段            | 是否必须 | 说明                           | 示例                              |
| --------------- | -------- | ------------------------------ | --------------------------------- |
| host            | 必须     | HiveServer2 地址               | `10.0.0.1`                      |
| port            | 必须     | HiveServer2 端口               | `10000`                         |
| database        | 必须     | 目标数据库名                   | `dwd_crdt`                      |
| username        | 必须     | 连接用户名                     | `hive_user`                     |
| password        | 必须     | 连接密码                       | `***`                           |
| auth_mechanism  | 可选     | 认证机制，默认 `LDAP`        | `LDAP` / `PLAIN` / `NOSASL` |
| partition_value | 可选     | 检查的目标分区值，默认最新分区 | `2026-05-20`                    |

**连接配置示例**：

```yaml
host: 10.0.0.1
port: 10000
database: dwd_crdt
username: hive_user
password: your_password
auth_mechanism: LDAP
partition_value: 2026-05-20
```

### 环境依赖

本 skill 执行时需要 Python 环境安装以下依赖之一：

- `pyhive` + `thrift` + `sasl`（Hive 连接）
- 或 `impyla`（Impala 连接）

如果执行时检测到依赖未安装，会提示用户先安装依赖。安装命令：

```bash
pip install pyhive thrift sasl thrift-sasl    # Hive
# 或
pip install impyla                             # Impala
```

### DDL 文档

包含一个或多个 `CREATE TABLE` 语句，用于识别表结构和推断业务类型。

### DDL 编写规范（重要）

数据质量检查的规则匹配高度依赖 DDL 中的信息。**DDL 写得越规范，检查覆盖越完整；DDL 信息缺失，对应规则会被跳过且标注原因。**

> **建议**：在执行数据质量检查前，先运行表级 DDL 规范检查（SKILL-table）和字段级 DDL 规范检查（SKILL-field），确保 DDL 质量。

以下逐项说明 DDL 各部分需要怎么写、为什么重要、以及正反案例对比。

---

#### 1. 表名：必须包含业务关键词

skill 通过表名中的关键词自动判断表的业务类型（交易类/客户类/账户类/汇总类/映射类），不同类型的表执行不同的规则子集。

| 业务类型      | 表名应包含的关键词                                             | 匹配到的规则                                      |
| ------------- | -------------------------------------------------------------- | ------------------------------------------------- |
| 交易类        | `txn`、`ord`、`trade`、`flow`、`pay`                 | DQ-C-01/02, DQ-A-01/02, DQ-S-01, DQ-U-01, DQ-R-01 |
| 客户/主数据类 | `client`、`customer`、`dim_`                             | DQ-C-03, DQ-A-03/04, DQ-S-02/04, DQ-U-02          |
| 账户/余额类   | `account`、`balance`、`acct`                             | DQ-C-04, DQ-A-05, DQ-U-03                         |
| 汇总/指标类   | 分层前缀 `dws_`/`ads_`，或含 `sum`、`agg`、`profile` | DQ-C-05, DQ-R-02/03                               |
| 映射/字典类   | `dict`、`mapping`、`rel`、`enum`                       | DQ-C-06, DQ-S-03, DQ-U-04                         |
| 通用类        | 以上都不匹配                                                   | 仅 DQ-C-01, DQ-U-01, DQ-U-05                      |

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

#### 2. 表注释（COMMENT）：必须描述业务含义

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

#### 3. 字段命名：使用标准后缀模式

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

#### 4. 字段注释 — 主键标识：必须标注"主键"

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

#### 5. 字段注释 — 枚举值域：必须列出所有合法值

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

#### 6. 字段注释 — 必填标识：标注"必填""不能为空"

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

#### 7. 字段注释 — 外键关联：用"关联 表名.字段名"格式

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

#### 8. 字段注释 — 金额单位：必须注明单位

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

#### 9. 完整正向示例

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

#### 10. 完整反向示例

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

### SQL 文档（可选）

包含 INSERT/SELECT 的加工语句，辅助判断表的加工逻辑和关联关系。

### 自定义规则（可选）

用户可提供自定义业务规则，格式为：

| 字段         | 是否必须 | 说明                                           |
| ------------ | -------- | ---------------------------------------------- |
| rule_id      | 必须     | 自定义规则 ID，格式 `DQ-CUST-XXX`            |
| rule_name    | 必须     | 规则名称                                       |
| target_table | 必须     | 适用表名                                       |
| severity     | 必须     | 高 / 中 / 低                                   |
| sql          | 必须     | 检查 SQL，必须返回 `COUNT(*) AS error_count` |
| threshold    | 可选     | 阈值，默认 `0`（不允许异常）                 |

**自定义规则示例**：

```yaml
custom_rules:
  - rule_id: DQ-CUST-001
    rule_name: 账户总额与明细之和差异
    target_table: dwd_crdt_account
    severity: 高
    sql: >
      SELECT
        a.account_id,
        a.balance AS declared_balance,
        COALESCE(SUM(d.amount), 0) AS detail_balance,
        ABS(a.balance - COALESCE(SUM(d.amount), 0)) AS diff
      FROM dwd_crdt_account a
      LEFT JOIN dwd_crdt_txn_detail d ON a.account_id = d.account_id AND d.dt = '${bizdate}'
      WHERE a.dt = '${bizdate}'
      GROUP BY a.account_id, a.balance
      HAVING ABS(a.balance - COALESCE(SUM(d.amount), 0)) > 0.01
    threshold: 0
```

---

## 规则库

### 业务类型识别

从 DDL 的表名、表注释、字段名自动判断表的业务类型：

| 关键词匹配（表名或注释中含以下词）                                           | 业务类型                                              |
| ---------------------------------------------------------------------------- | ----------------------------------------------------- |
| `ord`、`txn`、`trade`、`flow`、`pay`、`流水`、`订单`、`交易` | 交易类                                                |
| `client`、`customer`、`dim_`、`客户`、`维表`、`用户`             | 客户/主数据类                                         |
| `account`、`balance`、`acct`、`账户`、`余额`                       | 账户/余额类                                           |
| 分层前缀为 `dws`/`ads`，或含 `sum`、`agg`、`profile`、`汇总`     | 汇总/指标类                                           |
| `dict`、`mapping`、`rel`、`enum`、`映射`、`字典`                 | 映射/字典类                                           |
| 以上都不匹配                                                                 | 通用类（使用基础规则子集：DQ-C-01、DQ-U-01、DQ-U-05） |

---

### 维度一：完整性

检查核心字段是否有空值、分区数据是否缺失。

| 规则 ID | 适用表类型     | 规则描述                    | 检测方法                                                                                                                                                                                                                                                                                                                                       | 严重级别 |
| ------- | -------------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| DQ-C-01 | 交易类、通用类 | 主键/流水号空值率必须为 0%  | 从 DDL 中识别主键字段（COMMENT 含"主键"/"流水号"/"唯一"或字段名为 `*_id` 且 NOT NULL），执行 `COUNT WHERE pk IS NULL / COUNT(*)`                                                                                                                                                                                                           | 高       |
| DQ-C-02 | 交易类         | 核心业务字段空值率 < 1%     | 从 DDL 中识别核心字段：①注释含"主键""必填""核心"等关键词的字段；②字段名以 `_id`（非审计）、`_amt`/`_amount`、`_no` 结尾的业务字段；③字段名含 `client_id`、`trade_amt`、`trade_dt` 等明确业务模式的字段。排除审计字段（`create_time`、`insert_time`、`update_time`），执行 `COUNT WHERE core_field IS NULL / COUNT(*)` | 高       |
| DQ-C-03 | 客户/主数据类  | 必填字段空值率 < 0.1%       | 从 DDL 注释推断必填字段（含"必填""不能为空""主键"等词），或字段名为 `*_id`、`*_name`、`*_code`，执行空值率检查                                                                                                                                                                                                                           | 高       |
| DQ-C-04 | 账户/余额类    | 账户 ID 空值率必须为 0%     | 字段名含 `account_id`/`acct_id`，执行 `COUNT WHERE account_id IS NULL / COUNT(*)`                                                                                                                                                                                                                                                        | 高       |
| DQ-C-05 | 汇总/指标类    | 汇总粒度字段空值率必须为 0% | 汇总表的分组字段（如 `client_id`、`dt`、`product_id`）不能为空，执行空值率检查                                                                                                                                                                                                                                                           | 高       |
| DQ-C-06 | 映射/字典类    | 映射目标字段空值率 < 0.1%   | 映射表的目标字段（非键字段）执行空值率检查                                                                                                                                                                                                                                                                                                     | 高       |

---

### 维度二：准确性

检查数据值是否符合业务逻辑和格式要求。

| 规则 ID | 适用表类型    | 规则描述                                   | 检测方法                                                                                                                                                                                                                                       | 严重级别 |
| ------- | ------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| DQ-A-01 | 交易类        | 金额字段不允许出现负值                     | 字段名含 `_amt`/`_amount`/`_price`/`_fee`，执行 `COUNT WHERE amt_field < 0`                                                                                                                                                          | 高       |
| DQ-A-02 | 交易类        | 交易日期不允许晚于当前日期                 | 字段名含 `_dt`/`_date` 且类型为 DATE/TIMESTAMP，排除审计字段（`create_time`、`insert_time`、`update_time`、`etl_time`），仅检查业务日期字段（如 `trade_dt`、`last_change_dt`），执行 `COUNT WHERE date_field > CURRENT_DATE` | 高       |
| DQ-A-03 | 客户/主数据类 | 手机号/身份证号格式必须合规                | 字段名含 `phone`/`mobile`/`id_card`/`cert_no`，执行正则校验：手机号 `^1[3-9]\d{9}$`，身份证 `^\d{17}[\dXx]$`                                                                                                                       | 高       |
| DQ-A-04 | 客户/主数据类 | 年龄必须在合理范围内（0～150）             | 字段名含 `age`，执行 `COUNT WHERE age < 0 OR age > 150`                                                                                                                                                                                    | 中       |
| DQ-A-05 | 账户/余额类   | 余额不允许为负值（除非允许透支的业务场景） | 字段名含 `balance`/`bal`，执行 `COUNT WHERE balance < 0`。若表注释含"透支""贷款"等词则跳过                                                                                                                                               | 高       |

---

### 维度三：一致性

检查数据值之间是否自洽、与外部引用是否一致。

| 规则 ID | 适用表类型    | 规则描述                               | 检测方法                                                                                                                                                                                                                                                                       | 严重级别 |
| ------- | ------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| DQ-S-01 | 交易类        | 状态枚举值必须在定义范围内             | 从 DDL 注释中解析值域（如 `S-成功 F-失败 P-处理中`），执行 `SELECT DISTINCT status WHERE status NOT IN (合法值)`                                                                                                                                                           | 高       |
| DQ-S-02 | 客户/主数据类 | 同一客户在不同记录中的关键属性不应冲突 | 按 `client_id` 分组，检查 `gender`/`cert_type` 等字段是否有多个不同值：`COUNT(DISTINCT field) > 1`                                                                                                                                                                     | 中       |
| DQ-S-03 | 映射/字典类   | 映射值必须在目标表中存在对应记录       | 从字段 COMMENT 中匹配正则 `关联\s+(\w+)\.(\w+)` 或 `引用\s+(\w+)\.(\w+)` 提取目标表名和字段名；如果注释中未包含关联信息，跳过该字段并在报告中注明"注释未声明关联目标，跳过映射检查"。执行 `LEFT JOIN` 检查映射表的外键是否在目标表中有匹配：`WHERE target.key IS NULL` | 中       |
| DQ-S-04 | 客户/主数据类 | 已注销/删除客户不应有活跃标记          | 字段名含 `is_deleted`/`cancel_dt` 且值为已删除的记录，检查 `status` 不应为 `active`/`正常`，或 `last_activity_dt` 不应晚于 `cancel_dt`                                                                                                                           | 中       |

---

### 维度四：唯一性

检查是否存在不应该有的重复记录。

| 规则 ID | 适用表类型     | 规则描述                             | 检测方法                                                                                | 严重级别 |
| ------- | -------------- | ------------------------------------ | --------------------------------------------------------------------------------------- | -------- |
| DQ-U-01 | 交易类、通用类 | 主键/流水号不允许重复                | 从 DDL 识别主键字段，执行 `GROUP BY pk HAVING COUNT(*) > 1`                           | 高       |
| DQ-U-02 | 客户/主数据类  | 客户 ID 不允许重复                   | 字段名含 `client_id`/`customer_id`，执行 `GROUP BY client_id HAVING COUNT(*) > 1` | 高       |
| DQ-U-03 | 账户/余额类    | 同一账户同一日期不允许有多条余额记录 | 按 `account_id` + `dt` 分组，执行 `GROUP BY account_id, dt HAVING COUNT(*) > 1`   | 高       |
| DQ-U-04 | 映射/字典类    | 映射键不允许重复                     | 映射表的主键字段执行 `GROUP BY key HAVING COUNT(*) > 1`                               | 高       |
| DQ-U-05 | 所有类型       | 全字段重复记录                       | 按所有非审计字段分组，执行 `GROUP BY ... HAVING COUNT(*) > 1`                         | 中       |

---

### 维度五：合理性

检查数据分布是否符合预期，是否有异常波动或缺失。

| 规则 ID | 适用表类型  | 规则描述                             | 检测方法                                                                                                     | 严重级别 |
| ------- | ----------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------ | -------- |
| DQ-R-01 | 交易类      | 分区数据量环比波动不应超过 ±50%     | 执行 `SELECT dt, COUNT(*) FROM table GROUP BY dt ORDER BY dt`，计算相邻分区计数的变化率，波动 > ±50% 告警 | 中       |
| DQ-R-02 | 汇总/指标类 | 分区不应有缺失（连续日期分区应完整） | 执行 `SELECT DISTINCT dt FROM table ORDER BY dt`，检查分区日期是否连续，缺失天数告警                       | 高       |
| DQ-R-03 | 汇总/指标类 | 汇总分区数据量环比波动不应超过 ±30% | 同 DQ-R-01，但汇总表的阈值更紧（±30%）                                                                      | 中       |

---

### 内置默认阈值

用户未提供自定义阈值时，使用以下默认值：

| 规则类型                 | 默认阈值 |
| ------------------------ | -------- |
| 主键/流水号空值率        | = 0%     |
| 核心业务字段空值率       | < 1%     |
| 必填字段空值率           | < 0.1%   |
| 金额负值记录数           | = 0      |
| 日期超未来记录数         | = 0      |
| 格式不合规记录数         | < 0.1%   |
| 枚举越界记录数           | = 0      |
| 主键重复记录数           | = 0      |
| 数据量环比波动（交易类） | < ±50%  |
| 数据量环比波动（汇总类） | < ±30%  |

---

## 核心工作流

### Step 1：接收连接配置，验证环境

1. 从用户输入中提取数仓连接信息（host、port、database、username、password）
2. **未提供完整连接信息** → 跳过数据质量检查，在报告中注明"未提供数仓连接配置，数据质量检查已跳过"，结束执行
3. 检查 Python 环境中是否安装了 `pyhive` 或 `impyla`
   - 未安装 → 跳过数据质量检查，在报告中注明"未安装 pyhive/impyla 依赖，数据质量检查已跳过"，结束执行
4. 尝试连接数仓，验证连通性
   - 连接失败 → 跳过数据质量检查，在报告中注明"数仓连接失败，数据质量检查已跳过"，结束执行
   - 连接成功 → 继续

### Step 2：解析 DDL，提取表结构

从完整 DDL 文档中逐一提取每张表的以下信息：

- **表名**：`CREATE TABLE` 后的名称
- **表注释**：表级 `COMMENT` 的值
- **字段列表**：每个字段的名称、类型、注释、是否 `NOT NULL`
- **分区字段**：`PARTITIONED BY` 中声明的字段
- **表分层**：根据表名前缀判断（ods/dwd/dws/ads/dim）

### Step 3：DDL 可检查性评估

在匹配规则之前，对每张表评估 DDL 信息是否足够支撑规则推断。如果 DDL 信息不足，对应规则不会默默跳过，而是在报告中明确标注"跳过（DDL 信息不足）"及具体原因。

对每张表逐项评估：

| 评估项              | 判断标准                                                                           | 影响规则           |
| ------------------- | ---------------------------------------------------------------------------------- | ------------------ |
| 业务类型可识别      | 表名或表注释命中至少一个关键词                                                     | 所有规则的适用范围 |
| 主键可识别          | 至少有一个字段的 COMMENT 含"主键"/"流水号"/"唯一"，或字段名为 `*_id` 且 NOT NULL | DQ-C-01, DQ-U-01   |
| 核心字段可识别      | 存在符合 `_id`/`_amt`/`_no` 后缀模式的业务字段，或注释含"必填""核心"         | DQ-C-02            |
| 金额字段可识别      | 存在 `_amt`/`_amount`/`_price`/`_fee` 后缀的字段                           | DQ-A-01            |
| 日期字段可识别      | 存在 `_dt`/`_date` 后缀且类型为 DATE/TIMESTAMP 的非审计字段                    | DQ-A-02            |
| 枚举值域可解析      | 枚举类字段（status/type/flag/state）的 COMMENT 中有 `值-含义` 格式的值域定义     | DQ-S-01            |
| 关联表可解析        | 外键类字段的 COMMENT 中有 `关联 表名.字段名` 或 `引用 表名.字段名` 格式        | DQ-S-03            |
| 字段 COMMENT 覆盖率 | 有 COMMENT 的字段数 / 总字段数                                                     | 依赖注释的所有规则 |

**评估输出**（每张表一段，在明细问题之前展示）：

```
dwd_crdt_txn 可检查性评估：
✅ 业务类型：交易类（表名含 txn）
✅ 主键可识别：txn_id（COMMENT 含"主键"）
✅ 核心字段可识别：client_id, trade_amt, trade_dt
✅ 枚举值域可解析：trade_status（S-成功 F-失败 P-处理中）
⚠️ 无外键关联字段，DQ-S-03 将跳过
✅ 字段 COMMENT 覆盖率：100%（8/8）

dwd_crdt_data 可检查性评估：
⚠️ 业务类型：通用类（表名无关键词），仅执行 3 条基础规则
⚠️ 主键不可识别：无字段标注"主键"/"流水号"/"唯一"，DQ-C-01/DQ-U-01 将跳过
⚠️ 枚举字段 status 的 COMMENT 未定义值域，DQ-S-01 将跳过
⚠️ 字段 COMMENT 覆盖率：40%（2/5），部分规则可能无法匹配
```

**评估结果的处理**：

- ✅ 通过：对应规则正常执行
- ⚠️ 不通过：对应规则在 Excel 明细中标记为"跳过（DDL 信息不足）"，整改建议必须包含：①跳过原因（对应上述评估项）②具体补充方法（如何修改 DDL 使该规则可执行），使明细行自解释
- 如果一张表的可检查性评估全部 ⚠️，在报告中置顶提示"该表 DDL 信息严重不足，建议先完善 DDL 注释后重新检查"

### Step 4：识别业务类型，匹配 DQ 规则

对每张表：

1. 根据表名和表注释中的关键词，匹配业务类型（交易类/客户类/账户类/汇总类/映射类/通用类）
2. 根据业务类型，从规则库中匹配对应的 DQ 规则
3. 对每条匹配的规则，从 DDL 中提取具体的字段信息：
   - 主键字段（用于 DQ-C-01、DQ-U-01）
   - 金额字段（用于 DQ-A-01）
   - 日期字段（用于 DQ-A-02）
   - 枚举字段及值域（用于 DQ-S-01）
   - 等等
4. 合并用户提供的自定义规则

### Step 5：逐条生成 SQL 并连接数仓执行

对每条匹配到的规则：

1. 根据规则定义和 DDL 中提取的字段信息，生成具体的 Hive 检查 SQL
2. **确定分区值**：
   - 用户在连接配置中指定了 `partition_value` → 使用该值
   - 未指定 → 先执行 `SELECT MAX(dt) FROM {table}` 获取最新分区值
   - 将 SQL 中的 `${bizdate}` 替换为实际分区值
3. **非分区表处理**：如果表没有 `PARTITIONED BY` 声明（如维表 `dim_crdt_product_mapping`），生成的检查 SQL 中不添加分区过滤条件（`WHERE dt = ...`），直接对全表执行检查
4. 连接数仓执行 SQL，收集结果
5. 对比结果与阈值，判断是否通过

SQL 生成示例：

```sql
-- DQ-C-01: 主键空值检查（分区表）
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN txn_id IS NULL THEN 1 ELSE 0 END) AS error_count,
  ROUND(SUM(CASE WHEN txn_id IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS error_rate_pct
FROM dwd_crdt_txn
WHERE dt = '2026-05-20';

-- DQ-A-01: 金额负值检查
SELECT
  COUNT(*) AS error_count,
  COLLECT_LIST(CONCAT('trade_amt=', CAST(trade_amt AS STRING))) AS error_samples
FROM dwd_crdt_txn
WHERE dt = '2026-05-20'
  AND trade_amt < 0
LIMIT 10;

-- DQ-U-01: 主键重复检查
SELECT
  txn_id,
  COUNT(*) AS dup_count
FROM dwd_crdt_txn
WHERE dt = '2026-05-20'
GROUP BY txn_id
HAVING COUNT(*) > 1
LIMIT 10;

-- DQ-U-04: 映射键重复检查（非分区表，无 WHERE dt 条件）
SELECT
  product_code,
  COUNT(*) AS dup_count
FROM dim_crdt_product_mapping
GROUP BY product_code
HAVING COUNT(*) > 1
LIMIT 10;
```

### Step 6：汇总结果，分级排序

```
🔴 高优先级 — 主键空值、主键重复、金额负值、格式不合规、分区缺失，必须整改
🟡 中优先级 — 属性冲突、映射缺失、数据量波动、全字段重复，建议整改
🔵 低优先级 — 优化建议，可在下次迭代处理
```

### Step 7：生成 Excel 报告

使用 xlsx skill 生成 Excel 文件，本类检查的结果放在一个独立的 sheet 页中。

**Sheet 上半部分 — 明细问题：**

| 列名       | 说明                                                                                                                                                    |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 表名       | 被检查的表名                                                                                                                                            |
| 字段名     | 被检查的字段名（多条字段用逗号分隔；表级检查显示"-"）                                                                                                   |
| 规则 ID    | 触发的规则编号，如 DQ-C-01、DQ-A-03                                                                                                                     |
| 维度       | "完整性" / "准确性" / "一致性" / "唯一性" / "合理性"                                                                                                    |
| 规则描述   | 具体的规则描述                                                                                                                                          |
| 严重级别   | 高 / 中 / 低                                                                                                                                            |
| 检查结果   | 通过 / 失败 / 跳过（DDL 信息不足）                                                                                                                      |
| 总记录数   | 该表参与检查的总记录数；合理性规则（DQ-R-01/R-02/R-03）显示"-"                                                                                          |
| 异常记录数 | 违反该规则的记录数                                                                                                                                      |
| 异常比例   | 异常记录占总记录的比例（%）                                                                                                                             |
| 异常样本   | 异常数据样本（前 5 条，用于人工确认）                                                                                                                   |
| 整改建议   | 具体的修改建议。对于"跳过（DDL 信息不足）"的行，必须包含：①跳过原因（对应 Step 3 评估项）②具体补充方法（如何修改 DDL 使该规则可执行），使明细行自解释 |

**Sheet 下半部分 — 检查摘要（紧跟明细问题之后，中间空一行）：**

#### 总体统计

| 统计项                     | 值 |
| -------------------------- | -- |
| 检查表数                   | X  |
| 执行规则数                 | X  |
| 通过规则数                 | X  |
| 失败规则数                 | X  |
| 跳过规则数（DDL 信息不足） | X  |
| 通过率                     | X% |
| 高优先级问题               | X  |
| 中优先级问题               | X  |
| 低优先级问题               | X  |

#### 按维度统计

| 维度   | 规则数 | 通过 | 失败 | 跳过（DDL 信息不足） | 通过率 |
| ------ | ------ | ---- | ---- | -------------------- | ------ |
| 完整性 | X      | X    | X    | X                    | X%     |
| 准确性 | X      | X    | X    | X                    | X%     |
| 一致性 | X      | X    | X    | X                    | X%     |
| 唯一性 | X      | X    | X    | X                    | X%     |
| 合理性 | X      | X    | X    | X                    | X%     |

#### 按表统计

| 表名    | 业务类型 | 规则数 | 通过 | 失败 | 跳过（DDL 信息不足） | 通过率 |
| ------- | -------- | ------ | ---- | ---- | -------------------- | ------ |
| table_a | 交易类   | X      | X    | X    | X                    | X%     |
| table_b | 客户类   | X      | X    | X    | X                    | X%     |

#### 按类型统计（Top 5 高频问题规则）

| 规则 ID | 规则描述   | 触发次数 |
| ------- | ---------- | -------- |
| DQ-C-01 | 主键空值率 | X        |
| DQ-U-01 | 主键重复   | X        |
| ...     | ...        | ...      |

---

## 输出示例

### 输入示例

**连接配置**：

```yaml
host: 10.0.0.1
port: 10000
database: dwd_crdt
username: hive_user
password: my_password
partition_value: 2026-05-20
```

**DDL 文档（支持多张表，以下是各类型的典型示例）**：

```sql
-- ============================
-- 示例 1：交易类表（表名含 txn / ord / trade / flow / pay）
-- 匹配规则：DQ-C-01, DQ-C-02, DQ-A-01, DQ-A-02, DQ-S-01, DQ-U-01, DQ-R-01
-- ============================
CREATE TABLE dwd_crdt_txn (
  txn_id        STRING         COMMENT '流水号，主键',
  client_id     STRING         COMMENT '客户ID',
  trade_amt     DECIMAL(18,2)  COMMENT '交易金额，单位：元',
  trade_status  STRING         COMMENT '交易状态：S-成功 F-失败 P-处理中',
  trade_dt      DATE           COMMENT '交易日期',
  create_time   TIMESTAMP      COMMENT '记录创建时间'
)
COMMENT '信贷业务-交易流水明细增量表'
PARTITIONED BY (dt STRING);

-- ============================
-- 示例 2：客户/主数据类表（表名含 client / customer / dim_）
-- 匹配规则：DQ-C-03, DQ-A-03, DQ-A-04, DQ-S-02, DQ-S-04, DQ-U-02
-- ============================
CREATE TABLE ods_uf_client (
  client_id     STRING         COMMENT '客户ID，主键',
  client_name   STRING         COMMENT '客户姓名，必填',
  phone         STRING         COMMENT '手机号码',
  id_card       STRING         COMMENT '身份证号',
  age           INT            COMMENT '年龄',
  gender        STRING         COMMENT '性别：M-男 F-女',
  is_deleted    STRING         COMMENT '是否注销：Y-是 N-否',
  cancel_dt     DATE           COMMENT '注销日期',
  status        STRING         COMMENT '客户状态：active-正常 inactive-注销',
  last_activity_dt TIMESTAMP   COMMENT '最后活跃时间',
  create_time   TIMESTAMP      COMMENT '记录创建时间',
  insert_time   TIMESTAMP      COMMENT '记录插入时间'
)
COMMENT '贴源层-UF系统客户基础信息表'
PARTITIONED BY (dt STRING);

-- ============================
-- 示例 3：账户/余额类表（表名含 account / balance / acct）
-- 匹配规则：DQ-C-04, DQ-A-05, DQ-U-03
-- ============================
CREATE TABLE dwd_crdt_balance (
  account_id    STRING         COMMENT '账户ID，主键',
  balance       DECIMAL(18,2)  COMMENT '账户余额，单位：元',
  last_change_amt DECIMAL(18,2) COMMENT '最后变动金额，单位：元',
  last_change_dt DATE          COMMENT '最后变动日期',
  create_time   TIMESTAMP      COMMENT '记录创建时间',
  insert_time   TIMESTAMP      COMMENT '记录插入时间'
)
COMMENT '信贷业务-账户余额日快照表'
PARTITIONED BY (dt STRING);

-- ============================
-- 示例 4：汇总/指标类表（分层为 dws/ads，或含 sum / agg / profile）
-- 匹配规则：DQ-C-05, DQ-R-02, DQ-R-03
-- ============================
CREATE TABLE dws_crdt_daily_summary (
  client_id     STRING         COMMENT '客户ID',
  total_amt     DECIMAL(18,2)  COMMENT '当日交易总金额，单位：元',
  txn_count     INT            COMMENT '当日交易笔数',
  create_time   TIMESTAMP      COMMENT '记录创建时间'
)
COMMENT '信贷业务-客户每日交易汇总表'
PARTITIONED BY (dt STRING);

-- ============================
-- 示例 5：映射/字典类表（表名含 dict / mapping / rel / enum）
-- 匹配规则：DQ-C-06, DQ-S-03, DQ-U-04
-- ============================
CREATE TABLE dim_crdt_product_mapping (
  product_code  STRING         COMMENT '产品编码，主键',
  product_name  STRING         COMMENT '产品名称',
  product_type  STRING         COMMENT '产品类型：loan-贷款 deposit-存款',
  biz_line      STRING         COMMENT '所属业务线，关联 dim_crdt_biz_line.biz_line_id'
)
COMMENT '信贷业务-产品字典映射表';

-- ============================
-- 示例 6：通用类表（不匹配以上任何关键词，执行基础规则 DQ-C-01、DQ-U-01、DQ-U-05）
-- ============================
CREATE TABLE dwd_crdt_log (
  log_id        BIGINT         COMMENT '日志ID',
  content       STRING         COMMENT '日志内容',
  level         STRING         COMMENT '日志级别：INFO/WARN/ERROR',
  create_time   TIMESTAMP      COMMENT '记录创建时间'
)
COMMENT '信贷业务-操作日志表'
PARTITIONED BY (dt STRING);
```

> 以上 6 种类型是 skill 能自动识别的表类型。实际使用时，你的 DDL 文件可以包含任意数量的 `CREATE TABLE` 语句，skill 会自动按类型匹配对应的质量规则。如果表名/注释中的关键词不在上述识别范围内，则该表归类为"通用类"，执行基础规则子集（主键空值 DQ-C-01、主键重复 DQ-U-01、全字段重复 DQ-U-05）。

### 执行结果摘要

skill 自动识别 `dwd_crdt_txn` 为**交易类**表（表名含 `txn`，注释含"交易流水"），匹配以下规则并执行：

| 规则 ID | 维度   | 规则描述       | 结果                                   |
| ------- | ------ | -------------- | -------------------------------------- |
| DQ-C-01 | 完整性 | 主键空值率     | 通过（0/1000000）                      |
| DQ-C-02 | 完整性 | 核心字段空值率 | 失败（client_id 空值 12,000 条，1.2%） |
| DQ-A-01 | 准确性 | 金额负值       | 通过（0 条）                           |
| DQ-A-02 | 准确性 | 日期超未来     | 通过（0 条）                           |
| DQ-S-01 | 一致性 | 状态枚举越界   | 失败（发现异常值 `X`，3 条）         |
| DQ-U-01 | 唯一性 | 主键重复       | 通过（0 条）                           |
| DQ-R-01 | 合理性 | 数据量波动     | 通过（环比 +2.3%）                     |

### 输出

生成 Excel 文件 `数据质量检查报告.xlsx`，包含以下数据：

**「数据质量规范」sheet：**

| 表名          | 字段名       | 规则 ID | 维度   | 规则描述                                        | 严重级别 | 检查结果             | 总记录数  | 异常记录数 | 异常比例 | 异常样本                       | 整改建议                                                                                                                                      |
| ------------- | ------------ | ------- | ------ | ----------------------------------------------- | -------- | -------------------- | --------- | ---------- | -------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| dwd_crdt_txn  | client_id    | DQ-C-02 | 完整性 | 核心业务字段 client_id 空值率 1.2%（阈值 < 1%） | 高       | 失败                 | 1,000,000 | 12,000     | 1.2%     | client_id=NULL, txn_id=TXN_001 | 检查上游数据源，确认 client_id 丢失原因                                                                                                       |
| dwd_crdt_txn  | trade_status | DQ-S-01 | 一致性 | 交易状态存在定义范围外的值 `X`                | 高       | 失败                 | 1,000,000 | 3          | 0.0003%  | trade_status=X                 | 确认 `X` 是否为新增状态值，更新枚举定义或修复脏数据                                                                                         |
| dwd_crdt_data | id           | DQ-C-01 | 完整性 | 主键空值检查                                    | 高       | 跳过（DDL 信息不足） | -         | -          | -        | -                              | 主键不可识别：无字段 COMMENT 标注"主键"/"流水号"/"唯一"，且无 `*_id` + NOT NULL 字段。**建议**：在主键字段的 COMMENT 中加上"主键"标识 |
| dwd_crdt_data | jine         | DQ-A-01 | 准确性 | 金额负值检查                                    | 高       | 跳过（DDL 信息不足） | -         | -          | -        | -                              | 金额字段不可识别：字段名 `jine` 不符合 `_amt`/`_amount`/`_price`/`_fee` 后缀模式。**建议**：改为 `trade_amt` 等标准命名     |

**检查摘要：**

总体统计：

| 统计项                     | 值    |
| -------------------------- | ----- |
| 检查表数                   | 2     |
| 执行规则数                 | 9     |
| 通过规则数                 | 5     |
| 失败规则数                 | 2     |
| 跳过规则数（DDL 信息不足） | 2     |
| 通过率                     | 55.6% |
| 高优先级问题               | 2     |
| 中优先级问题               | 0     |
| 低优先级问题               | 0     |

按维度统计：

| 维度   | 规则数 | 通过 | 失败 | 跳过（DDL 信息不足） | 通过率 |
| ------ | ------ | ---- | ---- | -------------------- | ------ |
| 完整性 | 3      | 1    | 1    | 1                    | 33.3%  |
| 准确性 | 3      | 2    | 0    | 1                    | 66.7%  |
| 一致性 | 1      | 0    | 1    | 0                    | 0.0%   |
| 唯一性 | 1      | 1    | 0    | 0                    | 100.0% |
| 合理性 | 1      | 1    | 0    | 0                    | 100.0% |

按表统计：

| 表名          | 业务类型 | 规则数 | 通过 | 失败 | 跳过（DDL 信息不足） | 通过率 |
| ------------- | -------- | ------ | ---- | ---- | -------------------- | ------ |
| dwd_crdt_txn  | 交易类   | 7      | 5    | 2    | 0                    | 71.4%  |
| dwd_crdt_data | 通用类   | 2      | 0    | 0    | 2                    | 0.0%   |

按类型统计（Top 5 高频问题规则）：

| 规则 ID | 规则描述           | 触发次数 |
| ------- | ------------------ | -------- |
| DQ-C-02 | 核心业务字段空值率 | 1        |
| DQ-S-01 | 状态枚举越界       | 1        |

---

## 注意事项

1. **未提供连接配置**：用户未提供数仓连接信息时，自动跳过数据质量检查，在报告中注明"未提供数仓连接配置，数据质量检查已跳过"。不影响其他子 skill（表级、字段级、SQL、血缘）的正常执行。
2. **连接失败**：数仓连接不通或认证失败时，同样跳过数据质量检查，在报告中注明"数仓连接失败，数据质量检查已跳过"。
3. **连接安全**：密码等敏感信息仅在执行时使用，不记录到日志或输出文件中。Excel 报告中不包含密码。
4. **分区参数**：默认检查最新分区（`MAX(dt)`），用户可在连接配置中指定 `partition_value` 检查特定分区。
5. **执行超时**：单条 SQL 执行超时时间默认 300 秒，超时则标记"执行超时"并跳过。大批量表建议先在测试分区验证。
6. **样本限制**：异常样本默认取前 5～10 条，避免 Excel 过大。如需查看完整异常数据，可在数仓中手动执行对应 SQL。
7. **阈值调整**：不同业务场景对"可接受"的定义不同，内置默认阈值仅作参考。用户可通过自定义规则覆盖任意阈值。
8. **枚举值解析**：DDL 注释中的枚举值域格式应为 `值-含义`（如 `S-成功 F-失败 P-处理中`），skill 自动提取值部分（`S`、`F`、`P`）进行校验。如果注释中未定义值域，跳过 DQ-S-01 并在报告中注明"注释未定义值域，跳过枚举检查"。
9. **手机号/身份证格式**：正则规则为内置默认（中国大陆格式）。如果业务涉及其他国家/地区，用户应在自定义规则中提供对应的格式校验 SQL。
10. **大批量输入**：超过 20 张表时，高优先级问题逐条列出，中低优先级合并为统计摘要，避免 Excel 过长。（阈值低于其他子 skill 的 50 张，因为数据质量检查需连数仓逐表执行 SQL，耗时较长。）
11. **与 DDL/SQL 检查的关系**：本 skill 不检查建表语句的命名规范（表名/字段名/注释等）和 SQL 写法规范（安全/性能/格式），请使用配套的表级 DDL 规范检查（[SKILL-table.md](SKILL-table.md)）、字段级 DDL 规范检查（[SKILL-field.md](SKILL-field.md)）和 SQL 代码规范检查（[SKILL-sql.md](SKILL-sql.md)）。两者可组合使用：先做规范检查确保 DDL/SQL 写法正确，再做数据质量检查确保数据本身干净。
12. **临时表处理**：以 `tmp_` 开头的临时表不参与数据质量检查，不计入统计。
13. **ODS 层表**：ODS 层作为源系统数据，同样执行数据质量检查（源数据脏数据会在后续加工链路中传递，及早发现更有价值）。
14. **DDL 质量依赖**：数据质量检查的规则匹配高度依赖 DDL 中的信息（表名关键词、字段 COMMENT、字段命名模式）。如果 DDL 信息不足，对应规则会被标记为"跳过（DDL 信息不足）"而非"通过"。**建议在执行数据质量检查前，先运行表级 DDL 规范检查（[SKILL-table.md](SKILL-table.md)）和字段级 DDL 规范检查（[SKILL-field.md](SKILL-field.md)），确保 DDL 质量后再执行数据质量检查。** DDL 越规范，DQ 检查覆盖越完整。详见"前置要求 → DDL 编写规范"章节。
