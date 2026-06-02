-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_trd_order_detail_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.id AS STRING) AS id,
    ROW_NUMBER() OVER (ORDER BY source.id) AS order_detail_sk,


    COALESCE(dim_sku.sku_sk, -1) AS sku_sk,



    source.quantity AS quantity,

    source.original_amount AS original_amount,

    source.split_amount AS split_amount,



    CASE
        WHEN dim_sku.sku_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_order_item' AS source_system
FROM ods_mall_oltp_order_item source

LEFT JOIN dim_sku dim_sku
    ON source.sku_id = dim_sku.sku_id
   AND dim_sku.pt = '${bizdate}'

   AND dim_sku.is_active = 1


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_trd_order_detail_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,

    MIN(quantity) AS quantity_min,
    MAX(quantity) AS quantity_max,

    MIN(original_amount) AS original_amount_min,
    MAX(original_amount) AS original_amount_max,

    MIN(split_amount) AS split_amount_min,
    MAX(split_amount) AS split_amount_max

FROM dwd_trd_order_detail_df
WHERE pt = '${bizdate}';