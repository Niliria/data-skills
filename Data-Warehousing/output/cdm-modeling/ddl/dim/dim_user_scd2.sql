-- ========================================
-- DIM 维度表 DDL 模板
-- ========================================
-- 用于生成 DIM 维度表的建表语句
-- 支持 SCD Type I 和 Type II


-- ========== SCD Type II: 拉链表(完整历史) ==========
CREATE TABLE IF NOT EXISTS dim_user (
    -- 维度键
    user_sk BIGINT COMMENT 'user代理键(PK)',
    user_id STRING COMMENT 'user业务键(来自上游ODS元数据解析文档)',
    
    -- 维度属性
    
    user_name STRING COMMENT '用户名',
    
    gender STRING COMMENT '性别 1男 2女',
    
    phone STRING COMMENT '手机号',
    
    register_time STRING COMMENT '注册时间',
    
    register_channel STRING COMMENT '注册渠道',
    
    city_name STRING COMMENT '所在城市',
    
    
    -- SCD II 字段
    begin_date STRING COMMENT '维度值生效日期(开始日期,YYYY-MM-DD)',
    end_date STRING COMMENT '维度值失效日期(结束日期,当前记录为9999-12-31)',
    is_active INT COMMENT '是否当前活跃记录(1=当前,0=历史)',
    
    -- 审计字段
    etl_insert_time TIMESTAMP COMMENT 'ETL插入时间',
    etl_update_time TIMESTAMP COMMENT 'ETL更新时间'
)
COMMENT '维度表: 用户维度'
PARTITIONED BY (pt STRING COMMENT '分区日期(YYYY-MM-DD)')
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

