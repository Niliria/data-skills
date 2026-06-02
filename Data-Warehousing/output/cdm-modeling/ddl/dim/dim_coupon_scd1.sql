-- ========================================
-- DIM 维度表 DDL 模板
-- ========================================
-- 用于生成 DIM 维度表的建表语句
-- 支持 SCD Type I 和 Type II


-- ========== SCD Type I: 覆盖更新 ==========
CREATE TABLE IF NOT EXISTS dim_coupon (
    -- 维度键
    coupon_sk BIGINT COMMENT 'coupon代理键(PK)',
    coupon_id STRING COMMENT 'coupon业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    
    coupon_name STRING COMMENT '优惠券名称',
    
    discount_type TINYINT COMMENT '1满减 2折扣',
    
    min_amount DECIMAL(16,2) COMMENT '最低使用金额',
    
    discount_amount DECIMAL(16,2) COMMENT '优惠金额/折扣率',
    
    start_time STRING COMMENT '生效时间',
    
    end_time STRING COMMENT '失效时间',
    
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '维度表: 优惠券维度'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

