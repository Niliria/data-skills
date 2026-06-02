-- ========================================
-- DWS 汇总表 ETL - 交易域商品日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：商品 SKU + 每日
-- 数据域：TRD（交易域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_trd_sku_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    od.sku_id,

    -- 维度冗余属性（来自 dim_sku）
    s.sku_name,
    s.category_id,
    s.category_name,
    s.shop_id,

    -- 原子指标 - 销售相关
    SUM(COALESCE(od.quantity, 0)) AS order_qty_sum,
    SUM(COALESCE(od.original_amount, 0)) AS original_amt_sum,
    SUM(COALESCE(od.split_amount, 0)) AS split_amt_sum,
    COUNT(DISTINCT od.id) AS order_cnt_sum

FROM dwd_trd_order_detail_df od
-- 关联商品维度表（获取冗余属性）
LEFT JOIN dim_sku s
    ON od.sku_sk = s.sku_sk
    AND s.is_active = 1
    AND s.pt = '${bizdate}'
WHERE od.pt = '${bizdate}'
    AND od.is_valid = 1
GROUP BY
    od.sku_id,
    s.sku_name,
    s.category_id,
    s.category_name,
    s.shop_id;
