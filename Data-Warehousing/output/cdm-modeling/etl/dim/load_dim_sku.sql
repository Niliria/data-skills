-- ========================================
-- DIM 维度表 ETL SQL 模板
-- ========================================
-- 来源：上游 ODS 元数据解析文档提供的源表和字段映射


-- SCD Type II: 拉链表
DROP TABLE IF EXISTS tmp_dim_sku_new;
CREATE TABLE tmp_dim_sku_new AS
SELECT
    CAST(source.sku_id AS STRING) AS sku_id,

    source.spu_id AS spu_id,

    source.sku_name AS sku_name,

    source.category_id AS category_id,

    source.category_name AS category_name,

    source.shop_id AS shop_id,

    source.cost_price AS cost_price,

    source.sale_price AS sale_price,

    source.is_on_sale AS is_on_sale,

    CURRENT_TIMESTAMP() AS etl_time
FROM ods_mall_oltp_sku_info source
WHERE source.pt = '${bizdate}';

DROP TABLE IF EXISTS tmp_dim_sku_changed;
CREATE TABLE tmp_dim_sku_changed AS
SELECT
    old.sku_sk,
    old.sku_id,

    old.spu_id,

    old.sku_name,

    old.category_id,

    old.category_name,

    old.shop_id,

    old.cost_price,

    old.sale_price,

    old.is_on_sale,

    old.begin_date,
    '${bizdate}' AS end_date,
    0 AS is_active,
    old.etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM dim_sku old
INNER JOIN tmp_dim_sku_new new
    ON old.sku_id = new.sku_id
WHERE old.is_active = 1

  AND (

      NVL(old.cost_price, '') <> NVL(new.cost_price, '') OR

      NVL(old.sale_price, '') <> NVL(new.sale_price, '')

  );


INSERT OVERWRITE TABLE dim_sku PARTITION (pt='${bizdate}')
SELECT
    sku_sk,
    sku_id,

    spu_id,

    sku_name,

    category_id,

    category_name,

    shop_id,

    cost_price,

    sale_price,

    is_on_sale,

    begin_date,
    end_date,
    is_active,
    etl_insert_time,
    etl_update_time
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY new.sku_id) + COALESCE(max_sk.max_value, 0) AS sku_sk,
        new.sku_id,

        new.spu_id,

        new.sku_name,

        new.category_id,

        new.category_name,

        new.shop_id,

        new.cost_price,

        new.sale_price,

        new.is_on_sale,

        '${bizdate}' AS begin_date,
        '9999-12-31' AS end_date,
        1 AS is_active,
        CURRENT_TIMESTAMP() AS etl_insert_time,
        CURRENT_TIMESTAMP() AS etl_update_time
    FROM tmp_dim_sku_new new
    CROSS JOIN (
        SELECT COALESCE(MAX(sku_sk), 0) AS max_value FROM dim_sku
    ) max_sk
    LEFT JOIN dim_sku old
        ON new.sku_id = old.sku_id
       AND old.is_active = 1
    LEFT JOIN tmp_dim_sku_changed changed
        ON new.sku_id = changed.sku_id
    WHERE old.sku_id IS NULL
       OR changed.sku_id IS NOT NULL

    UNION ALL

    SELECT * FROM tmp_dim_sku_changed

    UNION ALL

    SELECT
        sku_sk,
        sku_id,

        spu_id,

        sku_name,

        category_id,

        category_name,

        shop_id,

        cost_price,

        sale_price,

        is_on_sale,

        begin_date,
        end_date,
        is_active,
        etl_insert_time,
        etl_update_time
    FROM dim_sku
    WHERE pt <> '${bizdate}'
      AND sku_id NOT IN (SELECT sku_id FROM tmp_dim_sku_changed)
) final_data;

DROP TABLE IF EXISTS tmp_dim_sku_new;
DROP TABLE IF EXISTS tmp_dim_sku_changed;

