-- ========================================
-- DWS 汇总表 ETL - 库存域门店商品日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：门店 + 商品 SKU + 每日
-- 数据域：INV（库存域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_inv_shop_sku_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    i.shop_id,
    i.sku_id,

    -- 维度冗余属性
    sku.sku_name,
    s.shop_name,

    -- 原子指标 - 库存相关（半可加度量）
    SUM(COALESCE(i.stock_num, 0)) AS stock_num_sum,
    MAX(i.stock_num) AS stock_num_max,
    MIN(i.stock_num) AS stock_num_min

FROM dwd_inv_inventory_snapshot_df i
-- 关联商品维度表（获取冗余属性）
LEFT JOIN dim_sku sku
    ON i.sku_sk = sku.sku_sk
    AND sku.is_active = 1
    AND sku.pt = '${bizdate}'
-- 关联门店维度表（获取冗余属性）
LEFT JOIN dim_shop s
    ON i.shop_sk = s.shop_sk
    AND s.pt = '${bizdate}'
WHERE i.pt = '${bizdate}'
    AND i.is_valid = 1
GROUP BY
    i.shop_id,
    i.sku_id,
    sku.sku_name,
    s.shop_name;
