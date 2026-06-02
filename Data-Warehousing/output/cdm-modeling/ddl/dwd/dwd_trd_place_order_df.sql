-- ========================================
-- DWD 事实表 DDL 模板
-- ========================================
-- OneData 口径：DWD 为原子明细事实表
-- 只保留事实粒度键、维度代理键、度量和审计字段，不展开 DIM 描述属性

CREATE TABLE IF NOT EXISTS dwd_trd_place_order_df (
    -- 事实键
    order_id STRING COMMENT 'place_order业务键(来自上游总线矩阵粒度)',
    place_order_sk BIGINT COMMENT 'place_order代理键(事实主键)',

    -- 维度外键（包含所有维度：业务维度+日期维度）
    
    user_sk BIGINT COMMENT '→ dim_user(外键)',
    
    shop_sk BIGINT COMMENT '→ dim_shop(外键)',
    

    -- 度量值(可加总)
    
    total_amount DECIMAL(16,2) COMMENT '订单总金额(聚合函数:SUM)',
    
    pay_amount DECIMAL(16,2) COMMENT '实付金额(聚合函数:SUM)',
    
    discount_amount DECIMAL(16,2) COMMENT '优惠金额(聚合函数:SUM)',
    

    -- 业务标志
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',

    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统'
)
COMMENT '事实表: trd-place_order'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);