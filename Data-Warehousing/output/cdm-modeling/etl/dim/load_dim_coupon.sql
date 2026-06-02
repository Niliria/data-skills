-- ========================================
-- DIM 维度表 ETL SQL 模板
-- ========================================
-- 来源：上游 ODS 元数据解析文档提供的源表和字段映射


-- SCD Type I: 覆盖更新
INSERT OVERWRITE TABLE dim_coupon PARTITION (pt='${bizdate}')
SELECT
    ROW_NUMBER() OVER (ORDER BY source.coupon_id) AS coupon_sk,
    CAST(source.coupon_id AS STRING) AS coupon_id,

    source.coupon_name AS coupon_name,

    source.discount_type AS discount_type,

    source.min_amount AS min_amount,

    source.discount_amount AS discount_amount,

    source.start_time AS start_time,

    source.end_time AS end_time,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM ods_mall_oltp_coupon_info source
WHERE source.pt = '${bizdate}';

