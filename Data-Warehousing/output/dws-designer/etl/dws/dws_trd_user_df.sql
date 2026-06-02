-- ========================================
-- DWS 汇总表 ETL - 交易域用户日汇总
-- ========================================
-- OneData 口径：DWS 层仅承载原子指标，不包含复合/派生指标
-- 聚合粒度：用户 + 每日
-- 数据域：TRD（交易域）
-- 调度周期：日增量

INSERT OVERWRITE TABLE dws_trd_user_df PARTITION(dt = '${bizdate}')
SELECT
    -- 维度主键
    o.user_id,

    -- 维度冗余属性（来自 dim_user）
    u.user_name,
    u.gender,
    u.register_channel,
    u.city_name,

    -- 原子指标 - 下单相关
    COUNT(DISTINCT o.order_id) AS order_cnt_sum,
    SUM(COALESCE(o.total_amount, 0)) AS order_amt_full_sum,
    SUM(COALESCE(o.pay_amount, 0)) AS pay_amt_sum,
    SUM(COALESCE(o.discount_amount, 0)) AS discount_amt_sum,

    -- 原子指标 - 支付相关
    COUNT(DISTINCT p.pay_id) AS payment_cnt_sum,
    SUM(COALESCE(p.pay_amount, 0)) AS payment_amt_sum,

    -- 原子指标 - 退款相关
    COUNT(DISTINCT r.refund_id) AS refund_cnt_sum,
    SUM(COALESCE(r.refund_amount, 0)) AS refund_amt_sum

FROM dwd_trd_place_order_df o
-- 关联用户维度表（获取冗余属性）
LEFT JOIN dim_user u
    ON o.user_sk = u.user_sk
    AND u.is_active = 1
    AND u.pt = '${bizdate}'
-- 关联支付事实表
LEFT JOIN dwd_trd_payment_df p
    ON o.user_sk = p.user_sk
    AND p.pt = '${bizdate}'
-- 关联退款事实表
LEFT JOIN dwd_trd_refund_df r
    ON o.user_sk = r.user_sk
    AND r.pt = '${bizdate}'
WHERE o.pt = '${bizdate}'
    AND o.is_valid = 1
GROUP BY
    o.user_id,
    u.user_name,
    u.gender,
    u.register_channel,
    u.city_name;
