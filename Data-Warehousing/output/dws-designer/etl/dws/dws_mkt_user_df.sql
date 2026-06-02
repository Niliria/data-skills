-- ========================================
-- DWS 汇总表 ETL - 营销域用户日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：用户 + 每日
-- 数据域：MKT（营销域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_mkt_user_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    c.user_id,

    -- 维度冗余属性（来自 dim_user）
    u.user_name,

    -- 原子指标 - 优惠券使用相关
    COUNT(DISTINCT c.id) AS coupon_use_cnt_sum

FROM dwd_mkt_coupon_usage_df c
-- 关联用户维度表（获取冗余属性）
LEFT JOIN dim_user u
    ON c.user_sk = u.user_sk
    AND u.is_active = 1
    AND u.pt = '${bizdate}'
WHERE c.pt = '${bizdate}'
    AND c.is_valid = 1
GROUP BY
    c.user_id,
    u.user_name;
