-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_mkt_coupon_usage_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.id AS STRING) AS id,
    ROW_NUMBER() OVER (ORDER BY source.id) AS coupon_usage_sk,


    COALESCE(dim_user.user_sk, -1) AS user_sk,

    COALESCE(dim_coupon.coupon_sk, -1) AS coupon_sk,





    CASE
        WHEN dim_user.user_sk IS NOT NULL AND dim_coupon.coupon_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_user_coupon' AS source_system
FROM ods_mall_oltp_user_coupon source

LEFT JOIN dim_user dim_user
    ON source.user_id = dim_user.user_id
   AND dim_user.pt = '${bizdate}'

   AND dim_user.is_active = 1


LEFT JOIN dim_coupon dim_coupon
    ON source.coupon_id = dim_coupon.coupon_id
   AND dim_coupon.pt = '${bizdate}'


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_mkt_coupon_usage_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records

FROM dwd_mkt_coupon_usage_df
WHERE pt = '${bizdate}';