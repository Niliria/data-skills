-- ========================================
-- DWS 汇总表 DDL - 营销域优惠券日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：优惠券 + 每日
-- 数据域：MKT（营销域）

CREATE TABLE IF NOT EXISTS dws_mkt_coupon_df (
    -- 分区字段
    dt STRING COMMENT '统计日期 (分区字段，YYYY-MM-DD)',

    -- 维度主键
    coupon_id STRING COMMENT '优惠券 ID(分组维度，来自 dwd_mkt_coupon_usage_df)',

    -- 维度冗余属性 (白名单：静态、高频、低变更)
    coupon_name STRING COMMENT '优惠券名称 (来自 dim_coupon)',
    discount_type TINYINT COMMENT '优惠类型 (来自 dim_coupon，1=满减 2=折扣)',

    -- 原子指标 - 优惠券使用相关
    coupon_use_cnt_sum BIGINT COMMENT '使用次数 (聚合函数：COUNT DISTINCT id)',
    coupon_use_user_cnt_sum BIGINT COMMENT '使用人数 (聚合函数：COUNT DISTINCT user_id)'
)
COMMENT 'DWS 汇总表：营销域优惠券日汇总 - 仅承载原子指标，复合/派生指标下沉至 ADS 层'
PARTITIONED BY (dt STRING COMMENT '分区日期 (YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
