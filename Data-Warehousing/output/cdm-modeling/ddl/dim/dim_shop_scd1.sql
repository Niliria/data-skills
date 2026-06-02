-- ========================================
-- DIM 维度表 DDL 模板
-- ========================================
-- 用于生成 DIM 维度表的建表语句
-- 支持 SCD Type I 和 Type II


-- ========== SCD Type I: 覆盖更新 ==========
CREATE TABLE IF NOT EXISTS dim_shop (
    -- 维度键
    shop_sk BIGINT COMMENT 'shop代理键(PK)',
    shop_id STRING COMMENT 'shop业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    
    shop_name STRING COMMENT '门店名称',
    
    city_id BIGINT COMMENT '城市ID',
    
    city_name STRING COMMENT '城市名称',
    
    manager_name STRING COMMENT '店长',
    
    is_open TINYINT COMMENT '是否营业',
    
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '维度表: 门店维度'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

