-- ========================================
-- DIM 维度表 ETL SQL 模板
-- ========================================
-- 来源：上游 ODS 元数据解析文档提供的源表和字段映射

{% if scd_type == 1 %}
-- SCD Type I: 覆盖更新
INSERT OVERWRITE TABLE {{ table_name }} PARTITION (pt='${bizdate}')
SELECT
    ROW_NUMBER() OVER (ORDER BY source.{{ business_key }}) AS {{ entity }}_sk,
    CAST(source.{{ business_key }} AS STRING) AS {{ business_key }},
{% for field in fields %}
    source.{{ field.source_field | default(field.name) }} AS {{ field.name }},
{% endfor %}
    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM {{ source_table }} source
WHERE source.pt = '${bizdate}';

{% elif scd_type == 2 %}
-- SCD Type II: 拉链表
DROP TABLE IF EXISTS tmp_dim_{{ entity }}_new;
CREATE TABLE tmp_dim_{{ entity }}_new AS
SELECT
    CAST(source.{{ business_key }} AS STRING) AS {{ business_key }},
{% for field in fields %}
    source.{{ field.source_field | default(field.name) }} AS {{ field.name }},
{% endfor %}
    CURRENT_TIMESTAMP() AS etl_time
FROM {{ source_table }} source
WHERE source.pt = '${bizdate}';

DROP TABLE IF EXISTS tmp_dim_{{ entity }}_changed;
CREATE TABLE tmp_dim_{{ entity }}_changed AS
SELECT
    old.{{ entity }}_sk,
    old.{{ business_key }},
{% for field in fields %}
    old.{{ field.name }},
{% endfor %}
    old.begin_date,
    '${bizdate}' AS end_date,
    0 AS is_active,
    old.etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time
FROM {{ table_name }} old
INNER JOIN tmp_dim_{{ entity }}_new new
    ON old.{{ business_key }} = new.{{ business_key }}
WHERE old.is_active = 1
{% if scd_tracking_fields %}
  AND (
{% for field in scd_tracking_fields %}
      NVL(old.{{ field.name }}, '') <> NVL(new.{{ field.name }}, ''){% if not loop.last %} OR{% endif %}
{% endfor %}
  );
{% else %}
  AND 1 = 0;
{% endif %}

INSERT OVERWRITE TABLE {{ table_name }} PARTITION (pt='${bizdate}')
SELECT
    {{ entity }}_sk,
    {{ business_key }},
{% for field in fields %}
    {{ field.name }},
{% endfor %}
    begin_date,
    end_date,
    is_active,
    etl_insert_time,
    etl_update_time
FROM (
    SELECT
        ROW_NUMBER() OVER (ORDER BY new.{{ business_key }}) + COALESCE(max_sk.max_value, 0) AS {{ entity }}_sk,
        new.{{ business_key }},
{% for field in fields %}
        new.{{ field.name }},
{% endfor %}
        '${bizdate}' AS begin_date,
        '9999-12-31' AS end_date,
        1 AS is_active,
        CURRENT_TIMESTAMP() AS etl_insert_time,
        CURRENT_TIMESTAMP() AS etl_update_time
    FROM tmp_dim_{{ entity }}_new new
    CROSS JOIN (
        SELECT COALESCE(MAX({{ entity }}_sk), 0) AS max_value FROM {{ table_name }}
    ) max_sk
    LEFT JOIN {{ table_name }} old
        ON new.{{ business_key }} = old.{{ business_key }}
       AND old.is_active = 1
    LEFT JOIN tmp_dim_{{ entity }}_changed changed
        ON new.{{ business_key }} = changed.{{ business_key }}
    WHERE old.{{ business_key }} IS NULL
       OR changed.{{ business_key }} IS NOT NULL

    UNION ALL

    SELECT * FROM tmp_dim_{{ entity }}_changed

    UNION ALL

    SELECT
        {{ entity }}_sk,
        {{ business_key }},
{% for field in fields %}
        {{ field.name }},
{% endfor %}
        begin_date,
        end_date,
        is_active,
        etl_insert_time,
        etl_update_time
    FROM {{ table_name }}
    WHERE pt <> '${bizdate}'
      AND {{ business_key }} NOT IN (SELECT {{ business_key }} FROM tmp_dim_{{ entity }}_changed)
) final_data;

DROP TABLE IF EXISTS tmp_dim_{{ entity }}_new;
DROP TABLE IF EXISTS tmp_dim_{{ entity }}_changed;

{% elif scd_type == 3 %}
-- SCD Type III: 当前值 + 前一值
MERGE INTO {{ table_name }} t
USING (
    SELECT
        CAST(source.{{ business_key }} AS STRING) AS {{ business_key }},
{% for field in fields %}
        source.{{ field.source_field | default(field.name) }} AS {{ field.name }},
{% endfor %}
        '${bizdate}' AS effective_date,
        CURRENT_TIMESTAMP() AS etl_time
    FROM {{ source_table }} source
    WHERE source.pt = '${bizdate}'
) s
ON t.{{ business_key }} = s.{{ business_key }}
WHEN MATCHED THEN UPDATE SET
{% for field in fields %}
    t.prior_{{ field.name }} = t.{{ field.name }},
    t.{{ field.name }} = s.{{ field.name }},
{% endfor %}
    t.effective_date = s.effective_date,
    t.etl_update_time = s.etl_time
WHEN NOT MATCHED THEN INSERT (
    {{ entity }}_sk,
    {{ business_key }},
{% for field in fields %}
    {{ field.name }},
    prior_{{ field.name }},
{% endfor %}
    effective_date,
    etl_insert_time,
    etl_update_time
) VALUES (
    ROW_NUMBER() OVER (ORDER BY s.{{ business_key }}),
    s.{{ business_key }},
{% for field in fields %}
    s.{{ field.name }},
    NULL,
{% endfor %}
    s.effective_date,
    s.etl_time,
    s.etl_time
);
{% endif %}
