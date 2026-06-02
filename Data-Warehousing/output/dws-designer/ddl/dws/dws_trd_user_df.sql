-- ========================================
-- DWS 汇总表 DDL - 交易域用户日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：用户 + 每日
-- 数据域：TRD（交易域）

CREATE TABLE IF NOT EXISTS dws_trd_user_df (
    -- 分区字段
    dt STRING COMMENT '统计日期 (分区字段，YYYY-MM-DD)',

    -- 维度主键
    user_id STRING COMMENT '用户 ID(分组维度，来自 dwd_trd_place_order_df)',

    -- 维度冗余属性 (白名单：静态、高频、低变更)
    user_name STRING COMMENT '用户名 (来自 dim_user)',
    gender STRING COMMENT '性别 (来自 dim_user)',
    register_channel STRING COMMENT '注册渠道 (来自 dim_user)',
    city_name STRING COMMENT '所在城市 (来自 dim_user)',

    -- 原子指标 - 下单相关
    order_cnt_sum BIGINT COMMENT '下单订单数 (聚合函数：COUNT DISTINCT order_id)',
    order_amt_full_sum DECIMAL(16,2) COMMENT '订单总金额 (聚合函数：SUM total_amount)',
    pay_amt_sum DECIMAL(16,2) COMMENT '实付金额 (聚合函数：SUM pay_amount)',
    discount_amt_sum DECIMAL(16,2) COMMENT '优惠金额 (聚合函数：SUM discount_amount)',

    -- 原子指标 - 支付相关
    payment_cnt_sum BIGINT COMMENT '支付次数 (聚合函数：COUNT DISTINCT pay_id)',
    payment_amt_sum DECIMAL(16,2) COMMENT '支付金额 (聚合函数：SUM pay_amount)',

    -- 原子指标 - 退款相关
    refund_cnt_sum BIGINT COMMENT '退款次数 (聚合函数：COUNT DISTINCT refund_id)',
    refund_amt_sum DECIMAL(16,2) COMMENT '退款金额 (聚合函数：SUM refund_amount)'
)
COMMENT 'DWS 汇总表：交易域用户日汇总 - 仅承载原子指标，复合/派生指标下沉至 ADS 层'
PARTITIONED BY (dt STRING COMMENT '分区日期 (YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
