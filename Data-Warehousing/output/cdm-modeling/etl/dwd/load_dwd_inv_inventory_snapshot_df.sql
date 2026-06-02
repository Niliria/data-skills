-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_inv_inventory_snapshot_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.sku_id AS STRING) AS sku_id,
    ROW_NUMBER() OVER (ORDER BY source.sku_id) AS inventory_snapshot_sk,


    COALESCE(dim_sku.sku_sk, -1) AS sku_sk,

    COALESCE(dim_shop.shop_sk, -1) AS shop_sk,



    source.stock_num AS stock_num,



    CASE
        WHEN dim_sku.sku_sk IS NOT NULL AND dim_shop.shop_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_stock_info' AS source_system
FROM ods_mall_oltp_stock_info source

LEFT JOIN dim_sku dim_sku
    ON source.sku_id = dim_sku.sku_id
   AND dim_sku.pt = '${bizdate}'

   AND dim_sku.is_active = 1


LEFT JOIN dim_shop dim_shop
    ON source.shop_id = dim_shop.shop_id
   AND dim_shop.pt = '${bizdate}'


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_inv_inventory_snapshot_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,

    MIN(stock_num) AS stock_num_min,
    MAX(stock_num) AS stock_num_max

FROM dwd_inv_inventory_snapshot_df
WHERE pt = '${bizdate}';