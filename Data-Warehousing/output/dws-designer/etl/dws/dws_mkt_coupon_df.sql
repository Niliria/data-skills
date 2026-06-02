-- ========================================
-- DWS 汇总表 ETL - 营销域优惠券日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：优惠券 + 每日
-- 数据域：MKT（营销域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_mkt_coupon_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    c.coupon_id,

    -- 维度冗余属性（来自 dim_coupon）
    cp.coupon_name,
    cp.discount_type,

    -- 原子指标 - 优惠券使用相关
    COUNT(DISTINCT c.id) AS coupon_use_cnt_sum,
    COUNT(DISTINCT c.user_id) AS coupon_use_user_cnt_sum

FROM dwd_mkt_coupon_usage_df c
-- 关联优惠券维度表（获取冗余属性）
LEFT JOIN dim_coupon cp
    ON c.coupon_sk = cp.coupon_sk
    AND cp.pt = '${bizdate}'
WHERE c.pt = '${bizdate}'
    AND c.is_valid = 1
GROUP BY
    c.coupon_id,
    cp.coupon_name,
    cp.discount_type;
