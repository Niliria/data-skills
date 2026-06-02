-- ========================================
-- DIM 维度表 ETL SQL 模板
-- ========================================
-- 来源：上游 ODS 元数据解析文档提供的源表和字段映射


-- SCD Type II: 拉链表
DROP TABLE IF EXISTS tmp_dim_user_new;
CREATE TABLE tmp_dim_user_new AS
SELECT
    CAST(source.user_id AS STRING) AS user_id,

    source.user_name AS user_name,

    source.gender AS gender,

    source.phone AS phone,

    source.register_time AS register_time,

    source.register_channel AS register_channel,

    source.city_name AS city_name,

    CURRENT_TIMESTAMP() AS etl_time
FROM ods_mall_oltp_user_info source
WHERE source.pt = '${bizdate}';

DROP TABLE IF EXISTS tmp_dim_user_changed;
CREATE TABLE tmp_dim_user_changed AS
SELECT
    old.user_sk,
    old.user_id,

    old.user_name,

    old.gender,

    old.phone,

    old.register_time,

    old.register_channel,

    old.city_name,

    old.begin_date,
    '${bizdate}' AS end_date,
    0 AS is_active,
    old.etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM dim_user old
INNER JOIN tmp_dim_user_new new
    ON old.user_id = new.user_id
WHERE old.is_active = 1

  AND (

      NVL(old.city_name, '') <> NVL(new.city_name, '')

  );


INSERT OVERWRITE TABLE dim_user PARTITION (pt='${bizdate}')
SELECT
    user_sk,
    user_id,

    user_name,

    gender,

    phone,

    register_time,

    register_channel,

    city_name,

    begin_date,
    end_date,
    is_active,
    etl_insert_time,
    etl_update_time
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY new.user_id) + COALESCE(max_sk.max_value, 0) AS user_sk,
        new.user_id,

        new.user_name,

        new.gender,

        new.phone,

        new.register_time,

        new.register_channel,

        new.city_name,

        '${bizdate}' AS begin_date,
        '9999-12-31' AS end_date,
        1 AS is_active,
        CURRENT_TIMESTAMP() AS etl_insert_time,
        CURRENT_TIMESTAMP() AS etl_update_time
    FROM tmp_dim_user_new new
    CROSS JOIN (
        SELECT COALESCE(MAX(user_sk), 0) AS max_value FROM dim_user
    ) max_sk
    LEFT JOIN dim_user old
        ON new.user_id = old.user_id
       AND old.is_active = 1
    LEFT JOIN tmp_dim_user_changed changed
        ON new.user_id = changed.user_id
    WHERE old.user_id IS NULL
       OR changed.user_id IS NOT NULL

    UNION ALL

    SELECT * FROM tmp_dim_user_changed

    UNION ALL

    SELECT
        user_sk,
        user_id,

        user_name,

        gender,

        phone,

        register_time,

        register_channel,

        city_name,

        begin_date,
        end_date,
        is_active,
        etl_insert_time,
        etl_update_time
    FROM dim_user
    WHERE pt <> '${bizdate}'
      AND user_id NOT IN (SELECT user_id FROM tmp_dim_user_changed)
) final_data;

DROP TABLE IF EXISTS tmp_dim_user_new;
DROP TABLE IF EXISTS tmp_dim_user_changed;

