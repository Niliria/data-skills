-- ========================================
-- DWD 事实表 DDL 模板
-- ========================================
-- OneData 口径：DWD 为原子明细事实表
-- 只保留事实粒度键、维度代理键、度量和审计字段，不展开 DIM 描述属性

CREATE TABLE IF NOT EXISTS dwd_inv_inventory_snapshot_df (
    -- 事实键
    sku_id STRING COMMENT 'inventory_snapshot业务键(来自上游总线矩阵粒度)',
    inventory_snapshot_sk BIGINT COMMENT 'inventory_snapshot代理键(事实主键)',

    -- 维度外键（包含所有维度：业务维度+日期维度）
    
    sku_sk BIGINT COMMENT '→ dim_sku(外键)',
    
    shop_sk BIGINT COMMENT '→ dim_shop(外键)',
    

    -- 度量值(可加总)
    
    stock_num INT COMMENT '库存数量(聚合函数:SUM)',
    

    -- 业务标志
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',

    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统'
)
COMMENT '事实表: inv-inventory_snapshot'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);