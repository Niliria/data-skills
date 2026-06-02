-- ========================================
-- DWS 汇总表 ETL - 交易域门店日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：门店 + 每日
-- 数据域：TRD（交易域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_trd_shop_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    o.shop_id,

    -- 维度冗余属性（来自 dim_shop）
    s.shop_name,
    s.city_id,
    s.city_name,
    s.is_open,

    -- 原子指标 - 下单相关
    COUNT(DISTINCT o.order_id) AS order_cnt_sum,
    SUM(COALESCE(o.total_amount, 0)) AS order_amt_full_sum,
    SUM(COALESCE(o.pay_amount, 0)) AS pay_amt_sum,

    -- 原子指标 - 退款相关
    COUNT(DISTINCT r.refund_id) AS refund_cnt_sum,
    SUM(COALESCE(r.refund_amount, 0)) AS refund_amt_sum

FROM dwd_trd_place_order_df o
-- 关联门店维度表（获取冗余属性）
LEFT JOIN dim_shop s
    ON o.shop_sk = s.shop_sk
    AND s.pt = '${bizdate}'
-- 关联退款事实表
LEFT JOIN dwd_trd_refund_df r
    ON o.shop_sk = r.shop_sk
    AND r.pt = '${bizdate}'
WHERE o.pt = '${bizdate}'
    AND o.is_valid = 1
GROUP BY
    o.shop_id,
    s.shop_name,
    s.city_id,
    s.city_name,
    s.is_open;
