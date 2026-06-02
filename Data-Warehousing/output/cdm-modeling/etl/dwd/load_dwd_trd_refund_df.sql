-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_trd_refund_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.refund_id AS STRING) AS refund_id,
    ROW_NUMBER() OVER (ORDER BY source.refund_id) AS refund_sk,


    COALESCE(dim_user.user_sk, -1) AS user_sk,

    COALESCE(dim_sku.sku_sk, -1) AS sku_sk,



    source.refund_amount AS refund_amount,



    CASE
        WHEN dim_user.user_sk IS NOT NULL AND dim_sku.sku_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_refund_info' AS source_system
FROM ods_mall_oltp_refund_info source

LEFT JOIN dim_user dim_user
    ON source.user_id = dim_user.user_id
   AND dim_user.pt = '${bizdate}'

   AND dim_user.is_active = 1


LEFT JOIN dim_sku dim_sku
    ON source.sku_id = dim_sku.sku_id
   AND dim_sku.pt = '${bizdate}'

   AND dim_sku.is_active = 1


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_trd_refund_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,

    MIN(refund_amount) AS refund_amount_min,
    MAX(refund_amount) AS refund_amount_max

FROM dwd_trd_refund_df
WHERE pt = '${bizdate}';