-- ========================================
-- DWD 事实表 DDL 模板
-- ========================================
-- OneData 口径：DWD 为原子明细事实表
-- 只保留事实粒度键、维度代理键、度量和审计字段，不展开 DIM 描述属性

CREATE TABLE IF NOT EXISTS {{ table_name }} (
    -- 事实键
    {{ business_key }} STRING COMMENT '{{ entity }}业务键(来自上游总线矩阵粒度)',
    {{ entity }}_sk BIGINT COMMENT '{{ entity }}代理键(事实主键)',

    -- 维度外键（包含所有维度：业务维度+日期维度）
    {% for dim in dimensions %}
    {{ dim.entity }}_sk BIGINT COMMENT '→ {{ dim.table_name | default('dim_' ~ dim.entity) }}(外键)',
    {% endfor %}

    -- 度量值(可加总)
    {% for measure in measures %}
    {{ measure.name }} {{ measure.type }} COMMENT '{{ measure.description }}(聚合函数:{{ measure.aggregation }})',
    {% endfor %}

    -- 业务标志
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',

    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统'
)
COMMENT '{{ table_comment }}'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);
