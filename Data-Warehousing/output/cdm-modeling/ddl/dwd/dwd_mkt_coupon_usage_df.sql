-- ========================================
-- DWD 事实表 DDL 模板
-- ========================================
-- OneData 口径：DWD 为原子明细事实表
-- 只保留事实粒度键、维度代理键、度量和审计字段，不展开 DIM 描述属性

CREATE TABLE IF NOT EXISTS dwd_mkt_coupon_usage_df (
    -- 事实键
    id STRING COMMENT 'coupon_usage业务键(来自上游总线矩阵粒度)',
    coupon_usage_sk BIGINT COMMENT 'coupon_usage代理键(事实主键)',

    -- 维度外键（包含所有维度：业务维度+日期维度）
    
    user_sk BIGINT COMMENT '→ dim_user(外键)',
    
    coupon_sk BIGINT COMMENT '→ dim_coupon(外键)',
    

    -- 度量值(可加总)
    

    -- 业务标志
    is_valid INT COMMENT '是否有效记录(1=有效,0=无效)',

    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间',
    source_system STRING COMMENT '来源系统'
)
COMMENT '事实表: mkt-coupon_usage'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES (
    'orc.compress'='SNAPPY',
    'orc.stripe.size'='67108864'
);