-- ========================================
-- DWD 事实表 ETL SQL 模板
-- ========================================
-- OneData 口径：DWD ETL 关联 DIM 仅获取代理键，不展开 DIM 描述属性

INSERT OVERWRITE TABLE {{ table_name }} PARTITION (pt='${bizdate}')
SELECT
    CAST(source.{{ business_key }} AS STRING) AS {{ business_key }},
    ROW_NUMBER() OVER (ORDER BY source.{{ business_key }}) AS {{ entity }}_sk,

{% for dim in dimensions %}
    COALESCE(dim_{{ dim.entity }}.{{ dim.entity }}_sk, -1) AS {{ dim.entity }}_sk,
{% endfor %}

{% for measure in measures %}
    source.{{ measure.source_field | default(measure.name) }} AS {{ measure.name }},
{% endfor %}

{% if dimensions %}
    CASE
        WHEN {% for dim in dimensions %}dim_{{ dim.entity }}.{{ dim.entity }}_sk IS NOT NULL{% if not loop.last %} AND {% endif %}{% endfor %}
        THEN 1
        ELSE 0
    END AS is_valid,
{% else %}
    1 AS is_valid,
{% endif %}
    CURRENT_TIMESTAMP() AS etl_insert_time,
    CURRENT_TIMESTAMP() AS etl_update_time,
    '{{ source_table }}' AS source_system
FROM {{ source_table }} source
{% for dim in dimensions %}
LEFT JOIN {{ dim.table_name | default('dim_' ~ dim.entity) }} dim_{{ dim.entity }}
    ON source.{{ dim.source_field | default(dim.target_field) | default(dim.business_key) }} = dim_{{ dim.entity }}.{{ dim.business_key }}
   AND dim_{{ dim.entity }}.pt = '${bizdate}'
{% if dim.scd_type == 2 %}
   AND dim_{{ dim.entity }}.is_active = 1
{% endif %}
{% endfor %}
WHERE source.pt = '${bizdate}';

-- 数据质量检查
SELECT
    '{{ table_name }}' AS table_name,
    '${bizdate}' AS pt,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 1 THEN 1 ELSE 0 END) AS valid_records{% if measures %},{% endif %}
{% for measure in measures %}
    MIN({{ measure.name }}) AS {{ measure.name }}_min,
    MAX({{ measure.name }}) AS {{ measure.name }}_max{% if not loop.last %},{% endif %}
{% endfor %}
FROM {{ table_name }}
WHERE pt = '${bizdate}';
