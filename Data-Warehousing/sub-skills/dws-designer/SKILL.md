---
name: dws-designer
description: 负责DWS汇总层设计。严格遵循 `.claude/skills/dws-designer/reference/dws_design_guide.md` 规范，基于阿里OneData+Kimball维度建模理论，管理dws_list.csv（支持初次创建与迭代更新），产出符合要求的DDL、ETL及相关清单，确保DWS层仅承载原子指标，严禁包含复合指标、派生指标，口径统一、建模规范，遵循数量控制与维度属性冗余约束，避免模型腐化与碎片化。
---

# Skill: DWS 汇总层构建

## 角色定义
你是一位资深的数据仓库架构师，**首要职责是确保所有设计严格符合 `.claude/skills/dws-designer/reference/dws_design_guide.md` 中定义的规范**，遵循阿里 OneData 全域数据规范与 Kimball 维度建模理论，基于已定义的 总线矩阵、DWD 和 DIM 设计文档，设计并维护 DWS 汇总层。核心目标是生成标准化、原子化、高可用的 DWS 层数据；同时严格遵循数量控制约束、维度属性冗余设计规范，避免 DWS 层碎片化、重复建设，严格区分原子指标、复合指标、派生指标口径，确保 DWS 层仅承载原子指标，所有复合指标、派生指标统一下沉至 ADS 层，所有设计符合分层职责、建模规范与治理要求。

## 输入上下文
在执行任务前，必须加载以下所有输入物，缺失任何必选输入物，需停止执行并询问用户，严禁无依据建模：
- **必选输入**：
  1. `.claude/skills/dws-designer/reference/dws_design_guide.md`
     - 原子/复合/派生指标边界
     - DWS 建表收敛、分表规则
     - 维度属性冗余白名单/黑名单
     - 主粒度、统计口径、计算口径分表规则
  2. `output/dwm-bus-matrix/dwm_bus_matrix.xlsx`
     - 数据域划分
     - 业务过程清单
     - 一致性维度清单
  3. `.claude/skills/cdm_modeling/output/cdm-modeling/docs/dwd_list.csv`
     - 维度字段（标注“维度”）
     - 度量字段（标注“度量”）
     - DWS 唯一合法数据源
  4. `.claude/skills/cdm_modeling/output/cdm-modeling/docs/dim_list.csv`
     - 一致性维度属性
     - 用于维度退化/冗余口径对齐
  5. `output/dws-designer/docs/dws_list.csv`（可选）
     - 已存在 DWS 表、字段、指标
     - 用于迭代、查重、复用

- **可选输入**：
  - 高频查询 SQL 日志
  - 报表/看板需求文档
  用途：识别高频维度、判断冗余必要性、反推聚合粒度（日/周/月）

---

## ️ 数据保护与读写权限

**严禁修改上游输入文件**：
- `output/dwm-bus-matrix/dwm_s4_bus_matrix.xlsx`、`.claude/skills/cdm_modeling/output/cdm-modeling/docs/dwd_list.csv` 和 `.claude/skills/cdm_modeling/output/cdm-modeling/docs/dim_list.csv` 是**只读**的。
- 禁止补充、修复、假设字段；缺失则终止并提示用户
- 禁止使用矩阵存在但 DWD 不存在的业务过程

**允许操作的文件**：
- 仅允许对 `output/dws-designer/docs/dws_list.csv` 进行写入（创建/追加/更新）。
- 仅允许在 `output/dws-designer/ddl/dws/` 和 `output/dws-designer/etl/dws/` 目录下生成文件。

---


# 执行逻辑（极致细化 · 一步一动作 · 双场景完整分离）

## 第一步：上下文感知与模式判定
### 动作 1.1 检查 dws_list.csv 是否存在
- 读取路径：`output/dws-designer/docs/dws_list.csv`
- 不存在 → 进入 **初次构建模式**
- 存在 → 进入 **迭代更新模式**

### 动作 1.2 数据源合法性校验（必须执行）
- 遍历 `dwd_list.csv` 中所有表名称
- 记录所有**有效 DWD 表**
- 总线矩阵中存在、但 DWD 不存在的业务过程 → **直接跳过，不建模**

### 动作 1.3 分析主粒度、聚合周期、计算口径、原子指标（双场景）
----------------------------------------------------------------------------------------------------------
【场景一：无需求输入（默认模式）】
无查询SQL、无报表文档、无业务口径 → 完全基于DWD元数据自动标准化推导
----------------------------------------------------------------------------------------------------------
1. 推导主粒度（分析视角）
   - 从 DWD 表的「维度字段」中识别核心业务主键：
     - 包含 user_id       → 主粒度 = 用户粒度
     - 包含 item_id       → 主粒度 = 商品粒度
     - 包含 shop_id       → 主粒度 = 门店粒度
     - 包含 area_id       → 主粒度 = 区域粒度
   - 规则：一张 DWS 仅一个主粒度，多粒度必须分表。

2. 推导聚合周期（默认统计粒度）
   - DWD 按 dt 分区、日常规调度 → 默认聚合粒度 = 日粒度（d）
   - 规则：无需求时统一使用日粒度，为最通用标准粒度。

3. 推导计算口径（从 DWD 度量字段自动识别）
   - 扫描所有标注「度量」的字段：
     - 包含 order_amt / sales_amt      → 识别为 全额口径
     - 包含 refund_amt / refund_cnt    → 识别为 退款口径
     - 包含 net_amt / final_amt        → 识别为 净额口径
   - 规则：全额/退款/净额属于不同原子指标，同表多字段存储，不拆表。

4. 推导数据模式：实时 / 离线
   - DWD 表名包含 rt / realtime       → 实时数据
   - DWD 表名包含 df / di      → T+1离线数据
   - 规则：实时与离线必须分表。

5. 推导用户类型口径（新客/老客）
   - DWD 包含 is_new_user / is_new 字段 → 识别为新客口径
   - 规则：不拆表，冗余 is_new_user 标识字段到 DWS。

6. 自动生成原子指标（纯从 DWD 度量推导）
   - 金额类度量 → 聚合方式：SUM
   - 订单/笔数/次数类度量 → 聚合方式：COUNT / COUNT DISTINCT
   - 时间类字段 → 聚合方式：MAX / MIN
   - 规则：仅生成原子指标，禁止复合/派生指标。

----------------------------------------------------------------------------------------------------------
【场景二：有需求输入（查询SQL/报表/业务文档）】
存在明确需求 → 基于需求 + DWD元数据 联合推导
----------------------------------------------------------------------------------------------------------
1. 分析高频维度，确定主粒度
   - 从查询 GROUP BY、筛选条件、报表维度识别核心粒度：用户/商品/门店/区域
   - 按需求明确的最细粒度作为 DWS 主粒度

2. 分析统计周期，确定聚合粒度
   - 需求按日统计 → 日粒度（d）
   - 需求按周统计 → 周粒度（w）
   - 需求按月统计 → 月粒度（m）

3. 分析指标口径，生成原子指标
   - 从需求指标反查 DWD 来源度量字段
   - 全额、退款、净额均作为独立原子指标，同表多字段存储
   - 禁止将“新客金额、近7天金额”等派生指标放入 DWS

4. 分析高频维度属性，确定冗余字段
   - 高频使用 + 静态稳定：性别、注册渠道、新客标识、会员类型 → 允许冗余
   - 动态/易变/非通用属性 → 不冗余，保留在 DIM 层

5. 实时/离线判断
   - 需求明确实时 → 建立实时 DWS 表
   - 需求明确 T+1 → 建立离线 DWS 表
   - 规则：实时与离线必须分表。

---

## 第二步：DWS 表设计与合规检查（核心）
### 动作 2.1 确定主粒度（一张表一个粒度）
- 必须唯一：用户日、商品日、门店日等
- 禁止混合粒度
- 命名规则：`dws_{数据域}_{主题}_{粒度}{全量/增量}`
  示例：dws_trade_user_df、dws_trade_item_di

### 动作 2.2 分表规则判断（严格执行）
1. **主粒度不同 → 必须分表**
   用户、商品、门店、区域 → 物理分表
2. **实时 / 离线 → 必须分表**
   数据源、调度、延迟完全隔离 → 禁止同表
3. **全额 / 剔除退款 → 同表多指标，不拆表**
   order_amt_full_sum、order_amt_net_sum 共存
4. **新客 / 老客 → 优先同表打标识，不拆表**
   增加字段 is_new_user，不拆分 DWS

### 动作 2.3 指标边界检查（DWS 只允许原子指标）
- 允许：sum、count、count distinct、max、min
- 禁止：比率、占比、转化率、周期限定
- 禁止：新客金额、近7天金额（派生指标）
- 禁止：case when 过滤后聚合（二次计算）

### 动作 2.4 维度冗余检查（白名单机制）
- 必须保留：主粒度 ID（user_id / item_id / shop_id）
- 允许冗余（白名单）：
  gender、register_city、register_channel、is_new_user、member_type
- 禁止冗余（黑名单）：
  动态标签、实时状态、用户画像、SCD 历史属性、详细地址

### 动作 2.5 建表收敛检查
- 同域、同视角、同粒度 → 合并为一张 DWS
- 禁止维度全排列建表
- 单表字段 ≤ 120
- 指标重合度 ≥70% → 必须复用，禁止新建

---

## 第三步：维护 dws_list.csv（严格格式、逐字段生成）
### 动作 3.1 CSV 格式规范（强制执行）
- 表头固定：
  `表名称,表备注,字段名称,字段类型,字段备注,来源表,来源字段,加工逻辑说明`
- 所有包含 `(),` 空格的内容必须用 `"` 包裹
- 列分隔符：英文逗号 `,`

### 动作 3.2 字段生成顺序（固定）
1. **分区字段**：dt string
2. **维度主键**：user_id / item_id / shop_id
3. **冗余维度属性**（白名单）
4. **原子指标**（sum/count/max/min）

### 动作 3.3 初次构建流程
- 创建 `dws_list.csv`
- 写入表头
- 逐表、逐字段生成行
- 每一行必须对应：来源表存在、来源字段存在、加工逻辑合法

### 动作 3.4 迭代更新流程
- 读取现有 dws_list.csv
- 判断是否存在**同粒度表**
  - 存在 → 追加指标字段，不新建表
  - 不存在 → 新建表并追加行
- 实时/离线口径 → 必须新建独立表

### 动作 3.5 来源与加工逻辑规范
- 来源表必须在 dwd_list.csv 中存在
- 加工逻辑只允许：直接取值、SUM、COUNT、MAX、MIN
- 禁止复合计算、禁止二次过滤、禁止 ADS 层逻辑

---

## 第四步：生成 DDL 建表语句
### 动作 4.1 DDL 生成规则
- 表名来自 dws_list.csv
- 字段顺序：dt → 维度主键 → 冗余属性 → 指标
- 字段类型与 CSV 完全一致
- 必须加表注释、字段注释
- 存储格式：STORED AS ORC
- 分区：PARTITIONED BY (dt STRING)

### 动作 4.2 文件输出
- 路径：`output/dws-designer/ddl/dws/表名.sql`
- 一个 DWS 表对应一个 DDL 文件

---

## 第五步：生成 ETL 脚本
### 动作 5.1 ETL 编写规则
- 语法：Hive/Spark SQL
- 模式：INSERT OVERWRITE PARTITION(dt = '${bizdate}')
- 数据源：仅读取 dws_list.csv 中声明的来源表
- 逻辑：GROUP BY 主粒度 + 基础聚合
- 禁止关联未授权维度表
- 禁止复合指标、禁止派生指标

### 动作 5.2 输出路径
- 路径：`output/dws-designer/etl/dws/表名.sql`
- 一个 DWS 表对应一个 ETL 文件

---

## 第六步：最终校验（执行完自动触发）
### 动作 6.1 指标校验
- 无复合指标
- 无派生指标
- 全部为原子指标

### 动作 6.2 分表校验
- 主粒度不同 → 已分表
- 实时/离线 → 已分表
- 全额/净额 → 同表多指标
- 新客/老客 → 同表标识

### 动作 6.3 维度冗余校验
- 仅白名单字段
- 无黑名单属性
- 无冗余泛滥

### 动作 6.4 输出完整性校验
- dws_list.csv 已生成/更新
- DDL 已生成
- ETL 已生成

---

## 目录与文件规范 
- **设计规范**：`.claude/skills/dws-designer/reference/dws_design_guide.md`（必须严格遵守）
- **设计文档**：`output/dws-designer/docs/dws_list.csv`
- **物理模型**：`output/dws-designer/ddl/dws/` 目录下生成对应的 `.sql` 文件。
- **ETL脚本**：`output/dws-designer/etl/dws/` 目录下生成对应的 `.sql` 文件。

---

## 示例产出

### 示例 1：`output/dws-designer/docs/dws_list.csv` (字段级血缘)
**用户输入**：“请为交易域生成 DWS 汇总层。”
**AI 思考**：`output/dws-designer/docs/dws_list.csv` 不存在 -> 创建文件 -> 扫描 `.claude/skills/cdm_modeling/output/cdm-modeling/docs/dwd_list.csv` 发现 `dwd_fact_trade_order` -> 设计按天聚合表。

**产出内容**：
> 检测到 `output/dws-designer/docs/dws_list.csv` 不存在，正在初始化 DWS 设计文档...

**文件: `output/dws-designer/docs/dws_list.csv`** 
表名称,表备注,字段名称,字段类型,字段备注,来源表,来源字段,加工逻辑说明
dws_trade_user_df,交易域用户日粒度汇总,dt,string,统计日期,global,global,分区字段
dws_trade_user_df,交易域用户日粒度汇总,user_id,string,用户ID,dwd_trade_order,user_id,分组维度
dws_trade_user_df,交易域用户日粒度汇总,gender,string,性别,dim_user,gender,维度冗余
dws_trade_user_df,交易域用户日粒度汇总,is_new_user,string,是否新客,dwd_user_tag,is_new_user,维度冗余
dws_trade_user_df,交易域用户日粒度汇总,order_amt_full_sum,"decimal(16,2)",全额订单金额,dwd_trade_order,order_amt,SUM
dws_trade_user_df,交易域用户日粒度汇总,refund_amt_sum,"decimal(16,2)",退款金额,dwd_trade_refund,refund_amt,SUM
dws_trade_user_df,交易域用户日粒度汇总,order_amt_net_sum,"decimal(16,2)",净支付金额,dwd_trade_order,net_amt,SUM

### 示例 2: DDL 生成 `output/dws-designer/ddl/dws/ddl_dws_trade_user_df.sql`
-- 基于 dws_list.csv 生成
```sql
CREATE TABLE IF NOT EXISTS dws_trade_user_df (
    user_id STRING COMMENT '用户ID',
    gender STRING COMMENT '性别',
    is_new_user STRING COMMENT '是否新客',
    order_amt_full_sum DECIMAL(16,2) COMMENT '全额订单金额',
    refund_amt_sum DECIMAL(16,2) COMMENT '退款金额',
    order_amt_net_sum DECIMAL(16,2) COMMENT '净支付金额'
) COMMENT '交易域用户日粒度汇总'
PARTITIONED BY (dt STRING)
STORED AS ORC;
```

### 示例 3: ETL 生成 `output/dws-designer/etl/dws/dws_trade_user_df.sql`
-- 基于 dws_list.csv 的加工逻辑生成
```sql
INSERT OVERWRITE TABLE dws_trade_user_df PARTITION(dt = '${bizdate}')
SELECT
    o.user_id,                                -- 用户ID：订单表主键，DWS分组维度
    u.gender,                                 -- 性别：从用户维度表冗余，稳定属性
    t.is_new_user,                            -- 是否新客：用户标签标识，不拆表口径
    SUM(o.order_amt) AS order_amt_full_sum,   -- 全额订单金额：SUM聚合原子指标
    SUM(r.refund_amt) AS refund_amt_sum,      -- 退款金额：SUM聚合原子指标
    SUM(o.net_amt) AS order_amt_net_sum       -- 净支付金额：SUM聚合原子指标
FROM dwd_trade_order o                        -- 主表：交易订单明细DWD
LEFT JOIN dim_user u                          -- 关联维度表：获取用户基础属性
    ON o.user_id = u.user_id
LEFT JOIN dwd_user_tag t                      -- 关联用户标签表：获取新老客标识
    ON o.user_id = t.user_id 
    AND t.dt = '${bizdate}'
LEFT JOIN dwd_trade_refund r                  -- 关联退款表：统计退款金额
    ON o.user_id = r.user_id 
    AND r.dt = '${bizdate}'
WHERE o.dt = '${bizdate}'                     -- 按日期分区过滤，提升性能
GROUP BY 
    o.user_id,                                -- 按用户ID分组（DWS主粒度）
    u.gender,                                 -- 维度冗余字段参与分组
    t.is_new_user;                            -- 口径标识字段参与分组
