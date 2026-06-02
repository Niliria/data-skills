-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_trd_payment_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.pay_id AS STRING) AS pay_id,
    ROW_NUMBER() OVER (ORDER BY source.pay_id) AS payment_sk,


    COALESCE(dim_user.user_sk, -1) AS user_sk,



    source.pay_amount AS pay_amount,



    CASE
        WHEN dim_user.user_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_payment_info' AS source_system
FROM ods_mall_oltp_payment_info source

LEFT JOIN dim_user dim_user
    ON source.user_id = dim_user.user_id
   AND dim_user.pt = '${bizdate}'

   AND dim_user.is_active = 1


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_trd_payment_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,

    MIN(pay_amount) AS pay_amount_min,
    MAX(pay_amount) AS pay_amount_max

FROM dwd_trd_payment_df
WHERE pt = '${bizdate}';