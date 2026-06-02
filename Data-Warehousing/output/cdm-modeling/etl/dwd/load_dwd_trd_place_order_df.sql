-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE dwd_trd_place_order_df PARTITION (pt='${bizdate}')
SELECT
    CAST(source.order_id AS STRING) AS order_id,
    ROW_NUMBER() OVER (ORDER BY source.order_id) AS place_order_sk,


    COALESCE(dim_user.user_sk, -1) AS user_sk,

    COALESCE(dim_shop.shop_sk, -1) AS shop_sk,



    source.total_amount AS total_amount,

    source.pay_amount AS pay_amount,

    source.discount_amount AS discount_amount,



    CASE
        WHEN dim_user.user_sk IS NOT NULL AND dim_shop.shop_sk IS NOT NULL
        THEN 1
        ELSE 0
    END AS is_valid,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    'ods_mall_oltp_order_info' AS source_system
FROM ods_mall_oltp_order_info source

LEFT JOIN dim_user dim_user
    ON source.user_id = dim_user.user_id
   AND dim_user.pt = '${bizdate}'

   AND dim_user.is_active = 1


LEFT JOIN dim_shop dim_shop
    ON source.shop_id = dim_shop.shop_id
   AND dim_shop.pt = '${bizdate}'


WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    'dwd_trd_place_order_df' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,

    MIN(total_amount) AS total_amount_min,
    MAX(total_amount) AS total_amount_max,

    MIN(pay_amount) AS pay_amount_min,
    MAX(pay_amount) AS pay_amount_max,

    MIN(discount_amount) AS discount_amount_min,
    MAX(discount_amount) AS discount_amount_max

FROM dwd_trd_place_order_df
WHERE pt = '${bizdate}';