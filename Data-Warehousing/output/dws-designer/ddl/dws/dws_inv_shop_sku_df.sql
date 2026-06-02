-- ========================================
-- DWS 汇总表 DDL - 库存域门店商品日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：门店 + 商品 SKU + 每日
-- 数据域：INV（库存域）

CREATE TABLE IF NOT EXISTS dws_inv_shop_sku_df (
    -- 分区字段
    dt STRING COMMENT '统计日期 (分区字段，YYYY-MM-DD)',

    -- 维度主键
    shop_id STRING COMMENT '门店 ID(分组维度，来自 dwd_inv_inventory_snapshot_df)',
    sku_id STRING COMMENT '商品 SKU ID(分组维度，来自 dwd_inv_inventory_snapshot_df)',

    -- 维度冗余属性 (白名单：静态、高频、低变更)
    sku_name STRING COMMENT '商品名称 (来自 dim_sku)',
    shop_name STRING COMMENT '门店名称 (来自 dim_shop)',

    -- 原子指标 - 库存相关 (半可加度量)
    stock_num_sum BIGINT COMMENT '库存数量 (聚合函数：SUM stock_num)',
    stock_num_max BIGINT COMMENT '库存最大值 (聚合函数：MAX stock_num)',
    stock_num_min BIGINT COMMENT '库存最小值 (聚合函数：MIN stock_num)'
)
COMMENT 'DWS 汇总表：库存域门店商品日汇总 - 仅承载原子指标，复合/派生指标下沉至 ADS 层'
PARTITIONED BY (dt STRING COMMENT '分区日期 (YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
