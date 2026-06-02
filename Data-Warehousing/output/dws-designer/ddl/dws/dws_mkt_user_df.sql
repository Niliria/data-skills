-- ========================================
-- DWS 汇总表 DDL - 营销域用户日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：用户 + 每日
-- 数据域：MKT（营销域）

CREATE TABLE IF NOT EXISTS dws_mkt_user_df (
    -- 分区字段
    dt STRING COMMENT '统计日期 (分区字段，YYYY-MM-DD)',

    -- 维度主键
    user_id STRING COMMENT '用户 ID(分组维度，来自 dwd_mkt_coupon_usage_df)',

    -- 维度冗余属性 (白名单：静态、高频、低变更)
    user_name STRING COMMENT '用户名 (来自 dim_user)',

    -- 原子指标 - 优惠券使用相关
    coupon_use_cnt_sum BIGINT COMMENT '优惠券使用次数 (聚合函数：COUNT DISTINCT id)'
)
COMMENT 'DWS 汇总表：营销域用户日汇总 - 仅承载原子指标，复合/派生指标下沉至 ADS 层'
PARTITIONED BY (dt STRING COMMENT '分区日期 (YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
