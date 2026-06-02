-- ========================================
-- DIM 维度表 DDL 模板
-- ========================================
-- 用于生成 DIM 维度表的建表语句
-- 支持 SCD Type I 和 Type II


-- ========== SCD Type II: 拉链表(完整历史) ==========
CREATE TABLE IF NOT EXISTS dim_sku (
    -- 维度键
    sku_sk BIGINT COMMENT 'sku代理键(PK)',
    sku_id STRING COMMENT 'sku业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    
    spu_id BIGINT COMMENT 'SPU ID',
    
    sku_name STRING COMMENT '商品名称',
    
    category_id BIGINT COMMENT '��类ID',
    
    category_name STRING COMMENT '品类名称',
    
    shop_id BIGINT COMMENT '门店ID',
    
    cost_price DECIMAL(16,2) COMMENT '成本价',
    
    sale_price DECIMAL(16,2) COMMENT '销售价',
    
    is_on_sale TINYINT COMMENT '是否上架',
    
    
    -- SCD II 字段
    begin_date STRING COMMENT '维度值生效日期(开始日期,YYYY-MM-DD)',
    end_date STRING COMMENT '维度值失效日期(结束日期,当前记录为9999-12-31)',
    is_active INT COMMENT '是否当前活跃记录(1=当前,0=历史)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '维度表: 商品维度'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

