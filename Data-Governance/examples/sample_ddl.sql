-- ============================================================
-- 数据治理综合检查 · DDL 示例文件
-- 本文件包含大量反例，旨在尽可能触发所有规则。
-- 注释中标注了每条会触发的规则 ID。
-- ============================================================


-- ============================================================
-- 表级规范测试表
-- ============================================================

-- 【L-01】表名无合法分层前缀
CREATE TABLE client_base (
  client_id STRING COMMENT '客户唯一标识'
);

-- 【L-02】使用临时前缀 tmp_
CREATE TABLE tmp_client_dump (
  client_id STRING COMMENT '客户ID'
)
COMMENT '临时客户数据';

-- 【L-03】分层前缀叠加
CREATE TABLE ods_dwd_client_info (
  client_id STRING COMMENT '客户信息'
)
COMMENT '叠加前缀的表';


-- ============================================================
-- ODS 层 - 结构问题
-- ============================================================

-- 【S-ODS-01】【S-ODS-02】ODS 缺少数据库名段（仅两段）
CREATE TABLE ods_uf_client (
  client_id STRING COMMENT '客户唯一标识',
  client_name STRING COMMENT '客户名称',
  age STRING COMMENT '年龄',
  -- 【FC-07】注释纯英文缩写堆砌
  status INT COMMENT 'status flag code',
  jine FLOAT COMMENT '金额'
)
COMMENT '贴源层-UF系统客户基础信息表';


-- ============================================================
-- DIM 层 - 结构问题
-- ============================================================

-- 【S-DIM-02】DIM 只有一段 dim_pub
CREATE TABLE dim_pub (
  area_code STRING COMMENT '区域编码',
  area_name STRING COMMENT '区域名称'
)
COMMENT '公共维度-行政区域维表';

-- 【S-DIM-03】DIM 命名标签无限叠加
CREATE TABLE dim_crdt_region_province_city_town_tag (
  region_id STRING COMMENT '区域ID'
)
COMMENT '信贷区域省市镇标签表';

-- 【S-DIM-01】去掉 dim_ 后第一段不是已知业务板块缩写或 pub
CREATE TABLE dim_xyz_area (
  area_code STRING COMMENT '区域编码'
)
COMMENT '未知业务板块维度表';


-- ============================================================
-- DWD 层 - 结构问题
-- ============================================================

-- 【S-DWD-01】DWD 只有两段（缺少业务过程）
-- 【FD-03】DWD 层缺少 create_time/insert_time 数据追溯字段
CREATE TABLE dwd_crdt_account (
  account_id STRING COMMENT '账户ID',
  balance DECIMAL(18,2) COMMENT '余额，单位：元'
)
COMMENT '信贷业务账户层表';

-- 【S-DWD-03】DWD 段名超过 8 个字符（transactionmanagement 超长）
CREATE TABLE dwd_crdt_transactionmanagement_quotachg (
  id BIGINT COMMENT '主键',
  chg_amt DECIMAL(18,2) COMMENT '变更金额，单位：元'
)
COMMENT '信贷事务管理额度变更表';

-- 【S-DWD-02】增量标识放在中间而非最末段
CREATE TABLE dwd_crdt_agr_i_quota_chg (
  id BIGINT COMMENT '主键',
  client_id STRING COMMENT '客户ID',
  chg_amt DECIMAL(18,2) COMMENT '变更金额，单位：元',
  chg_type STRING COMMENT '变更类型：ADD-增加 DEC-减少',
  create_time TIMESTAMP COMMENT '记录创建时间'
)
COMMENT '信贷业务协议层-客户授信额度变更明细增量表';


-- ============================================================
-- DWS 层 - 结构/周期问题
-- ============================================================

-- 【S-DWS-01】DWS 只有两段（缺少数据粒度）
CREATE TABLE dws_crdt_asset (
  total_asset DECIMAL(18,2) COMMENT '总资产，单位：元'
)
COMMENT '信贷资产主题汇总表';

-- 【S-DWS-02】时间周期格式不合法（_day）
CREATE TABLE dws_crdt_ord_debt_day (
  client_id STRING COMMENT '客户ID',
  total_amt DECIMAL(18,2) COMMENT '总金额，单位：元',
  order_dt DATE COMMENT '订单日期'
)
COMMENT '信贷订单负债按日汇总表';

-- 【S-DWS-03】包含多个统计周期
CREATE TABLE dws_crdt_ord_debt_1d_7d (
  client_id STRING COMMENT '客户ID',
  amt_1d DECIMAL(18,2) COMMENT '1日金额',
  amt_7d DECIMAL(18,2) COMMENT '7日金额'
)
COMMENT '信贷订单负债多周期汇总表';


-- ============================================================
-- ADS 层 - 结构问题
-- ============================================================

-- 【S-ADS-01】ADS 只有一段业务板块
CREATE TABLE ads_crdt (
  report_data STRING COMMENT '报表数据'
)
COMMENT '信贷报表';

-- 【S-ADS-02】ADS 命名风格与 DWS 完全不同（DWS 用 crdt_ast_accnt，ADS 用 report_1d 完全不同的模式）
CREATE TABLE ads_report_1d (
  report_id STRING COMMENT '报表ID'
)
COMMENT '报表日汇总';


-- ============================================================
-- 字符规范测试
-- ============================================================

-- 【C-01】表名含大写字母
CREATE TABLE dwd_crdt_OrdInfo (
  id BIGINT COMMENT '主键'
)
COMMENT '订单信息表';

-- 【C-03】表名以数字开头
CREATE TABLE dwd_crdt_1table (
  id BIGINT COMMENT '主键'
)
COMMENT '数字开头表名';

-- 【C-04】表名以下划线结尾
CREATE TABLE dwd_crdt_pay_ (
  pay_id BIGINT COMMENT '支付ID'
)
COMMENT '支付记录表';

-- 【C-05】表名含连续下划线
CREATE TABLE dwd_crdt__log (
  log_id BIGINT COMMENT '日志ID'
)
COMMENT '日志表';

-- 【C-02】表名含中文字符
CREATE TABLE dwd_crdt_订单 (
  id BIGINT COMMENT '主键'
)
COMMENT '订单表';

-- 【C-06】Hive 关键字作表名
CREATE TABLE dwd_crdt_table (
  id BIGINT COMMENT '主键'
)
COMMENT '关键字表名';

-- 【C-07】全表名超长（超过 64 字符）
CREATE TABLE dwd_crdt_very_very_very_very_very_long_table_name_for_testing_max_length (
  id BIGINT COMMENT '主键'
)
COMMENT '超长表名测试';


-- ============================================================
-- 语义清晰度测试
-- ============================================================

-- 【M-01】拼音命名（yonghu）
-- 【M-02】宽泛词（info）
-- 【M-04】同文档 amt 与 amount 混用（触发缩写不一致）
CREATE TABLE dwd_crdt_yonghu_info (
  client_id STRING COMMENT '客户唯一标识',
  user_name STRING COMMENT '用户名称',
  trade_amt DECIMAL(18,2) COMMENT '交易金额，单位：元',
  fee_amount DECIMAL(18,2) COMMENT '手续费金额，单位：元'
)
COMMENT '信贷业务-用户信息明细表';

-- 【M-03】同域同类对象命名不一致（order vs orders 并存）
CREATE TABLE dwd_crdt_orders (
  order_id STRING COMMENT '订单ID'
)
COMMENT '信贷业务-订单明细表';


-- ============================================================
-- 表注释规范测试
-- ============================================================

-- 【T-01】缺失表级 COMMENT
CREATE TABLE dwd_crdt_missing_comment (
  id BIGINT COMMENT '主键'
);

-- 【T-02】注释为空字符串
CREATE TABLE dwd_crdt_empty_comment (
  id BIGINT COMMENT '主键'
)
COMMENT '';

-- 【T-03】注释与表名直接转写
CREATE TABLE dwd_crdt_order_detail (
  id BIGINT COMMENT '主键'
)
COMMENT 'dwd crdt order detail';

-- 【T-05】注释缺少要素（只写了"表"，无业务对象/事件/粒度）
CREATE TABLE dwd_crdt_simple_note (
  id BIGINT COMMENT '主键'
)
COMMENT '表';

-- 【T-07】注释含占位词
CREATE TABLE dwd_crdt_todo_table (
  id BIGINT COMMENT '主键'
)
COMMENT '待补充';

-- 【T-06】注释过长（超过 80 字）
CREATE TABLE dwd_crdt_long_comment (
  id BIGINT COMMENT '主键'
)
COMMENT '这是一个非常非常长的表注释，用来测试表注释规范中的长度检查规则，按照规则要求注释长度应该在十个到五十个汉字之间，超过八十个汉字应该被精简，这个注释已经远远超过了这个长度限制，所以应该触发T-06规则告警';


-- ============================================================
-- 模型冗余测试（与 dwd_crdt_missing_comment 字段高度重复）
-- ============================================================

-- 【R-01】与 dwd_crdt_missing_comment 字段重复度 100%
CREATE TABLE dwd_crdt_dup_table (
  id BIGINT COMMENT '主键'
)
COMMENT '信贷业务-重复建模测试表';

-- 【R-03】表名相似度高但非版本/时间后缀差异
CREATE TABLE dwd_crdt_order_detail (
  order_id STRING COMMENT '订单ID',
  client_id STRING COMMENT '客户ID'
)
COMMENT '信贷业务-订单明细表';

-- 【R-03】与 dwd_crdt_order_detail 表名相似度高
CREATE TABLE dwd_crdt_order_info (
  order_id STRING COMMENT '订单ID',
  client_id STRING COMMENT '客户ID',
  status STRING COMMENT '状态：P-处理中 S-成功 F-失败'
)
COMMENT '信贷业务-订单信息表';

-- 【R-02】字段是 dwd_crdt_missing_comment 的真子集 + 额外字段
CREATE TABLE dwd_crdt_subset_table (
  id BIGINT COMMENT '主键',
  name STRING COMMENT '名称',
  age INT COMMENT '年龄'
)
COMMENT '信贷业务-子集字段测试表';


-- ============================================================
-- 合规 ODS 表（对照用）
-- ============================================================
CREATE TABLE ods_uf_ha_client (
  client_id STRING COMMENT '客户唯一标识，关联业务系统uf_ha.client',
  client_name STRING COMMENT '客户名称',
  create_time TIMESTAMP COMMENT '记录创建时间',
  is_deleted STRING COMMENT '是否删除：Y-是 N-否',
  trade_dt DATE COMMENT '交易日期'
)
COMMENT '贴源层-UF系统客户库-client基础信息表';


-- ============================================================
-- 字段级规范测试表（整合多维度反例）
-- ============================================================

CREATE TABLE dwd_crdt_field_test (
  -- 【FC-01】缺失注释
  client_id STRING,

  -- 【F-01】大写字母
  -- 【FC-03】注释与字段名转写相同
  ClientName STRING COMMENT 'client name',

  -- 【F-02】拼音
  -- 【FT-01】金额用 FLOAT
  -- 【FC-05】金额注释未说明单位
  jine FLOAT COMMENT '金额',

  -- 【F-03】Hive 关键字
  date STRING COMMENT '日期',

  -- 【F-05】时间字段不以 _time/_dt/_date/_ts 结尾
  -- 【FT-03】日期用 STRING
  createTime STRING COMMENT '创建时间',

  -- 【F-04】布尔字段无 is_ 前缀
  -- 【FT-05】枚举用 INT 存
  -- 【FC-04】枚举字段注释未列值域
  deleted INT COMMENT '删除标记',

  -- 【FT-04】纯数值用 STRING
  age STRING COMMENT '年龄',

  -- 【FT-02】DECIMAL 裸写无精度
  price DECIMAL COMMENT '价格',

  -- 【F-06】_amount 与 _amt 混用（与 trade_amt 不一致）
  fee_amount DECIMAL(18,2) COMMENT '手续费金额',

  -- 【FC-02】注释含占位词
  status_code STRING COMMENT '待补充',

  -- 【F-07】含义相似字段（client_id 已存在）
  clientid STRING COMMENT '客户编号',

  -- 【FD-01】语义重叠（remark 和 memo）
  remark STRING COMMENT '备注信息',
  memo STRING COMMENT '备注',

  -- 【FD-02】无限扩展式字段
  ext_info STRING COMMENT '扩展信息',
  extra_col1 STRING COMMENT '扩展列1',
  extra_col2 STRING COMMENT '扩展列2',

  -- 【FT-07】TINYINT 用于一般 ID
  level_code TINYINT COMMENT '等级编码',

  -- 【FD-04】指标字段无统计口径
  total_amount DECIMAL(18,2) COMMENT '总金额',

  -- 【FC-06】外键注释未说明关联表字段
  ref_id BIGINT COMMENT '关联ID',

  -- 【FC-08】注释过短（仅 1 字）
  desc_col STRING COMMENT '描述',

  -- 【F-08】字段名超长（超过 40 字符）
  this_is_a_very_long_field_name_for_testing_over_forty_chars STRING COMMENT '超长字段名测试',

  -- 合规字段
  trade_amt DECIMAL(18,2) COMMENT '交易金额，单位：元',
  trade_status STRING COMMENT '交易状态：S-成功 F-失败 P-处理中',
  create_time TIMESTAMP COMMENT '记录创建时间'
)
COMMENT '信贷业务-字段规范综合测试表';


-- ============================================================
-- 跨表类型一致性测试
-- ============================================================

-- 【FT-06】client_id 在此表为 STRING，在 dwd_crdt_field_test 中也是 STRING → 一致
-- 但下面这张表的 client_id 用了 BIGINT，触发不一致
CREATE TABLE dws_crdt_client_summary_1d (
  client_id BIGINT COMMENT '客户ID',
  total_orders INT COMMENT '总订单数',
  total_amount DECIMAL(18,2) COMMENT '总金额，单位：元'
)
COMMENT '信贷业务-客户维度订单日汇总宽表';
