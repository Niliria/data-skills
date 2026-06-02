-- ========================================
-- DWS 汇总表 DDL - 交易域商品日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：商品 SKU + 每日
-- 数据域：TRD（交易域）

CREATE TABLE IF NOT EXISTS dws_trd_sku_df (
    -- 分区字段
    dt STRING COMMENT '统计日期 (分区字段，YYYY-MM-DD)',

    -- 维度主键
    sku_id STRING COMMENT '商品 SKU ID(分组维度，来自 dwd_trd_order_detail_df)',

    -- 维度冗余属性 (白名单：静态、高频、低变更)
    sku_name STRING COMMENT '商品名称 (来自 dim_sku)',
    category_id BIGINT COMMENT '品类 ID(来自 dim_sku)',
    category_name STRING COMMENT '品类名称 (来自 dim_sku)',
    shop_id STRING COMMENT '门店 ID(来自 dim_sku)',

    -- 原子指标 - 销售相关
    order_qty_sum BIGINT COMMENT '销售数量 (聚合函数：SUM quantity)',
    original_amt_sum DECIMAL(16,2) COMMENT '原价金额 (聚合函数：SUM original_amount)',
    split_amt_sum DECIMAL(16,2) COMMENT '分摊金额 (聚合函数：SUM split_amount)',
    order_cnt_sum BIGINT COMMENT '订单数 (聚合函数：COUNT DISTINCT id)'
)
COMMENT 'DWS 汇总表：交易域商品日汇总 - 仅承载原子指标，复合/派生指标下沉至 ADS 层'
PARTITIONED BY (dt STRING COMMENT '分区日期 (YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
