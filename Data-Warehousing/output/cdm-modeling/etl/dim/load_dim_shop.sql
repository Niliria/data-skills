-- ========================================
-- DIM 维度表 ETL SQL 模板
-- ========================================
-- 来源：上游 ODS 元数据解析文档提供的源表和字段映射


-- SCD Type I: 覆盖更新
INSERT OVERWRITE TABLE dim_shop PARTITION (pt='${bizdate}')
SELECT
    ROW_NUMBER() OVER (ORDER BY source.shop_id) AS shop_sk,
    CAST(source.shop_id AS STRING) AS shop_id,

    source.shop_name AS shop_name,

    source.city_id AS city_id,

    source.city_name AS city_name,

    source.manager_name AS manager_name,

    source.is_open AS is_open,

    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM ods_mall_oltp_shop_info source
WHERE source.pt = '${bizdate}';

