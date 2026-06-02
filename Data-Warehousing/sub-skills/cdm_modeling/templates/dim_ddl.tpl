-- ========================================
-- DIM 维度表 DDL 模板
-- ========================================
-- 用于生成 DIM 维度表的建表语句
-- 支持 SCD Type I 和 Type II

{% if scd_type == 1 %}
-- ========== SCD Type I: 覆盖更新 ==========
CREATE TABLE IF NOT EXISTS {{ table_name }} (
    -- 维度键
    {{ entity }}_sk BIGINT COMMENT '{{ entity }}代理键(PK)',
    {{ business_key }} STRING COMMENT '{{ entity }}业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    {% for attr in attributes %}
    {{ attr.name }} {{ attr.type }} COMMENT '{{ attr.description }}',
    {% endfor %}
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '{{ table_comment }}'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

{% elif scd_type == 2 %}
-- ========== SCD Type II: 拉链表(完整历史) ==========
CREATE TABLE IF NOT EXISTS {{ table_name }} (
    -- 维度键
    {{ entity }}_sk BIGINT COMMENT '{{ entity }}代理键(PK)',
    {{ business_key }} STRING COMMENT '{{ entity }}业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    {% for attr in attributes %}
    {{ attr.name }} {{ attr.type }} COMMENT '{{ attr.description }}',
    {% endfor %}
    
    -- SCD II 字段
    begin_date STRING COMMENT '维度值生效日期(开始日期,YYYY-MM-DD)',
    end_date STRING COMMENT '维度值失效日期(结束日期,当前记录为9999-12-31)',
    is_active INT COMMENT '是否当前活跃记录(1=当前,0=历史)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '{{ table_comment }}'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

{% elif scd_type == 3 %}
-- ========== SCD Type III: 混合型(当前值+前一值) ==========
CREATE TABLE IF NOT EXISTS {{ table_name }} (
    -- 维度键
    {{ entity }}_sk BIGINT COMMENT '{{ entity }}代理键(PK)',
    {{ business_key }} STRING COMMENT '{{ entity }}业务键(来自上游ODS元数据解析文档)',
    
    -- 当前值属性
    {% for attr in attributes %}
    {{ attr.name }} {{ attr.type }} COMMENT '{{ attr.description }}(当前值)',
    {% endfor %}
    
    -- 前一值属性（用于对比）
    {% for attr in attributes %}
    prior_{{ attr.name }} {{ attr.type }} COMMENT '前一个{{ attr.name }}(前一值)',
    {% endfor %}
    
    -- SCD III 字段
    effective_date STRING COMMENT '本次变化的有效日期',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '{{ table_comment }}'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

{% endif %}
