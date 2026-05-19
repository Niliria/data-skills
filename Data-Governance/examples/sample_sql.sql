-- ============================================================
-- 数据治理综合检查 · SQL 示例文件
-- 本文件包含大量反例，旨在尽可能触发所有 SQL 规范规则和血缘规则。
-- 注释中标注了每条会触发的规则 ID。
-- ============================================================


-- ============================================================
-- 【安全合规】
-- ============================================================

-- 【SEC-01】硬编码明文密码
-- 【SEC-02】DML 无分区过滤
DELETE FROM dwd_crdt_agr_quota_chg_i
WHERE id = 1 AND password = 'admin123' AND access_key = 'AKIAIOSFODNN7EXAMPLE';


-- ============================================================
-- 【性能优化 + 代码规范】综合反例
-- ============================================================

-- 【PERF-01】隐式笛卡尔积（FROM 多表无 JOIN）
-- 【CODE-01】无意义单字母别名
-- 【CODE-09】窗口函数缺 PARTITION BY
SELECT a.id, b.name, ROW_NUMBER() OVER() AS rn
FROM dwd_crdt_agr_quota_chg_i a, dwd_crdt_client_test b
WHERE a.id > 100;


-- ============================================================
-- 【性能优化】ORDER BY 无 LIMIT
-- ============================================================

-- 【PERF-02】ORDER BY 未搭配 LIMIT
-- 【CODE-10】SELECT DISTINCT *
SELECT DISTINCT *
FROM dwd_crdt_agr_quota_chg_i
ORDER BY chg_amt DESC;


-- ============================================================
-- 【性能优化】同一表多次出现无 WHERE 过滤
-- ============================================================

-- 【PERF-05】同一表在 SQL 中多次出现且均无 WHERE 过滤
SELECT a.id, b.chg_amt AS current_amt, c.chg_amt AS prev_amt
FROM dwd_crdt_agr_quota_chg_i a
JOIN dwd_crdt_agr_quota_chg_i b ON a.client_id = b.client_id
JOIN dwd_crdt_agr_quota_chg_i c ON a.client_id = c.client_id AND b.create_time > c.create_time;


-- ============================================================
-- 【性能优化】非等值 JOIN 无注释 + 子查询嵌套
-- ============================================================

-- 【PERF-03】非等值 JOIN 无注释说明原因
-- 【PERF-04】子查询嵌套超过 3 层
-- 【CODE-02】CTE 名称无业务含义
SELECT *
FROM (
  SELECT *
  FROM (
    SELECT *
    FROM (
      SELECT id, client_id, chg_amt
      FROM dwd_crdt_agr_quota_chg_i
      WHERE chg_amt > 0
    ) t1
  ) t2
) t3
JOIN dwd_crdt_client_test t4 ON t3.client_id < t4.client_id;


-- ============================================================
-- 【代码规范】CASE WHEN 超 3 分支无注释 + 注释与行为不一致
-- ============================================================

-- 【CODE-04】CASE WHEN 分支超 3 个无注释
-- 【CODE-05】注释说"过滤"但 WHERE 是"包含"
SELECT
  client_id,
  CASE chg_type
    WHEN 'ADD' THEN '增加'
    WHEN 'DEC' THEN '减少'
    WHEN 'MOD' THEN '修改'
    WHEN 'DEL' THEN '删除'
    ELSE '未知'
  END AS type_name
FROM dwd_crdt_agr_quota_chg_i
WHERE client_id IN ('A', 'B'); -- 过滤正常数据


-- ============================================================
-- 【代码规范】WHERE OR 连接不同表字段 + JOIN 混用 WHERE
-- ============================================================

-- 【CODE-06】WHERE 中 OR 连接不同表字段
-- 【CODE-07】JOIN 条件混用 WHERE 过滤
SELECT a.id, b.name
FROM dwd_crdt_agr_quota_chg_i a
JOIN dwd_crdt_client_test b ON a.client_id = b.client_id AND a.chg_amt > 0
WHERE a.client_id = 'X' OR b.name = 'Y';


-- ============================================================
-- 【代码规范】窗口函数缺 ORDER BY + 跨时区无时区参数
-- ============================================================

-- 【CODE-09】窗口函数缺 ORDER BY
-- 【CODE-11】跨时区转换无时区参数
SELECT
  client_id,
  SUM(chg_amt) OVER(PARTITION BY client_id) AS client_total,
  to_utc_timestamp(create_time) AS utc_time
FROM dwd_crdt_agr_quota_chg_i;


-- ============================================================
-- 【血缘】越层依赖 + 跨域依赖
-- ============================================================

-- 【J-01】跳过中间层跨层依赖（ADS 直接读 ODS）
-- 【J-03】ODS 层引用 DWD 层（反向依赖 - 这里用 INSERT 模拟）
-- 【J-04】跨业务域依赖（crdt → ord）
INSERT INTO ads_crdt_report_1d
SELECT
  o.client_id,
  SUM(o.order_amt) AS total_order,
  c.total_asset
FROM ods_uf_ha_client c
LEFT JOIN dwd_ord_order_info o ON c.client_id = o.client_id
GROUP BY o.client_id, c.total_asset;


-- ============================================================
-- 【血缘】断链 + 同层依赖
-- ============================================================

-- 【J-02】同层依赖（DWS 引用 DWS）
-- 【L-01】血缘链路断链（dwd_crdt_client_test 未找到上游加工逻辑）
INSERT INTO dws_crdt_profile_1d
SELECT
  p.client_id,
  p.total_debt
FROM dws_crdt_debt_1d p
LEFT JOIN dwd_crdt_client_test c ON p.client_id = c.client_id;


-- ============================================================
-- 【血缘】多任务写入冲突
-- ============================================================

-- 【L-02】同一表被不同 SQL 独立写入
INSERT INTO dwd_crdt_agr_quota_chg_i
SELECT
  id,
  client_id,
  chg_amt,
  chg_type,
  create_time
FROM tmp_import_table;


-- ============================================================
-- 【血缘复杂度】上游过多 + 下游过多
-- ============================================================

-- 【P-01】单表上游超过 10 张
INSERT INTO dws_crdt_wide_1d
SELECT
  c.client_id,
  c1.col1, c2.col2, c3.col3, c4.col4,
  c5.col5, c6.col6, c7.col7, c8.col8,
  c9.col9, c10.col10
FROM dwd_crdt_client c
JOIN dwd_crdt_account c1 ON c.client_id = c1.client_id
JOIN dwd_crdt_order c2 ON c.client_id = c2.client_id
JOIN dwd_crdt_payment c3 ON c.client_id = c3.client_id
JOIN dwd_crdt_refund c4 ON c.client_id = c4.client_id
JOIN dwd_crdt_contract c5 ON c.client_id = c5.client_id
JOIN dwd_crdt_guarantee c6 ON c.client_id = c6.client_id
JOIN dwd_crdt_collateral c7 ON c.client_id = c7.client_id
JOIN dwd_crdt_rating c8 ON c.client_id = c8.client_id
JOIN dwd_crdt_contact c9 ON c.client_id = c9.client_id
JOIN dwd_crdt_employment c10 ON c.client_id = c10.client_id;


-- ============================================================
-- 【血缘复杂度】JOIN 超过 8 张
-- ============================================================

-- 【PERF-06】单条 SQL JOIN 超过 8 张表
SELECT *
FROM dwd_crdt_client a
JOIN dwd_crdt_account b ON a.client_id = b.client_id
JOIN dwd_crdt_order c ON a.client_id = c.client_id
JOIN dwd_crdt_payment d ON a.client_id = d.client_id
JOIN dwd_crdt_refund e ON a.client_id = e.client_id
JOIN dwd_crdt_contract f ON a.client_id = f.client_id
JOIN dwd_crdt_guarantee g ON a.client_id = g.client_id
JOIN dwd_crdt_collateral h ON a.client_id = h.client_id
JOIN dwd_crdt_rating i ON a.client_id = i.client_id;


-- ============================================================
-- 【代码规范】IN 列表超 100 个值（缩写版，实际应有 100+）
-- ============================================================

-- 【CODE-08】IN 列表值超 100 个（此处仅示意，实际应列出 100+ 值）
-- 【CODE-03】SQL 开头无注释块（本 SQL 无注释说明）
SELECT * FROM dwd_crdt_agr_quota_chg_i
WHERE client_id IN ('C001', 'C002', 'C003', 'C004', 'C005', 'C006', 'C007', 'C008', 'C009', 'C010',
  'C011', 'C012', 'C013', 'C014', 'C015', 'C016', 'C017', 'C018', 'C019', 'C020',
  'C021', 'C022', 'C023', 'C024', 'C025', 'C026', 'C027', 'C028', 'C029', 'C030',
  'C031', 'C032', 'C033', 'C034', 'C035', 'C036', 'C037', 'C038', 'C039', 'C040',
  'C041', 'C042', 'C043', 'C044', 'C045', 'C046', 'C047', 'C048', 'C049', 'C050',
  'C051', 'C052', 'C053', 'C054', 'C055', 'C056', 'C057', 'C058', 'C059', 'C060',
  'C061', 'C062', 'C063', 'C064', 'C065', 'C066', 'C067', 'C068', 'C069', 'C070',
  'C071', 'C072', 'C073', 'C074', 'C075', 'C076', 'C077', 'C078', 'C079', 'C080',
  'C081', 'C082', 'C083', 'C084', 'C085', 'C086', 'C087', 'C088', 'C089', 'C090',
  'C091', 'C092', 'C093', 'C094', 'C095', 'C096', 'C097', 'C098', 'C099', 'C100',
  'C101');


-- ============================================================
-- 【血缘复杂度】同一表被大量下游引用（由上面多个 INSERT 触发）
-- ============================================================

-- 【P-02】单表被超过 20 张下游表引用
-- 【P-03】血缘链路深度超过 4 层（ODS → DWD → DWS → ADS 的链路）
-- 【P-04】扇入+扇出双高（dwd_crdt_agr_quota_chg_i 同时作为大量下游引用的来源）
-- 这些规则需要结合完整的血缘图谱才能判断，
-- 上述所有 SQL 组合后，dwd_crdt_agr_quota_chg_i 会被多个下游引用，触发 P-02/P-04。
