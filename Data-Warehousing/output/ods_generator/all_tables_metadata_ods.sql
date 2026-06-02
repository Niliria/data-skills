-- Hive ODS层表结构定义
-- 生成时间: 2026-05-11 20:54:27
-- 共 10 个表

CREATE TABLE IF NOT EXISTS ods_mall_oltp_coupon_info_df (
  `coupon_id` BIGINT COMMENT '',
  `coupon_name` STRING COMMENT '',
  `discount_type` TINYINT COMMENT '1满减 2折扣',
  `min_amount` DECIMAL COMMENT '',
  `discount_amount` DECIMAL COMMENT '',
  `start_time` STRING COMMENT '',
  `end_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '优惠券表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_order_info_df (
  `order_id` BIGINT COMMENT '订单ID',
  `user_id` BIGINT COMMENT '用户ID',
  `shop_id` BIGINT COMMENT '门店ID',
  `order_status` TINYINT COMMENT '订单状态 1待支付 2已支付 3已发货 4已完成 5已取消',
  `total_amount` DECIMAL COMMENT '订单总金额',
  `pay_amount` DECIMAL COMMENT '实付金额',
  `discount_amount` DECIMAL COMMENT '优惠金额',
  `order_time` STRING COMMENT '下单时间',
  `pay_time` STRING COMMENT '支付时间',
  `is_deleted` TINYINT COMMENT '',
  `create_time` STRING COMMENT '',
  `update_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '订单主表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_order_item_df (
  `id` BIGINT COMMENT '',
  `order_id` BIGINT COMMENT '订单ID',
  `sku_id` BIGINT COMMENT '商品ID',
  `sku_name` STRING COMMENT '商品名称',
  `quantity` INT COMMENT '购买数量',
  `original_amount` DECIMAL COMMENT '原价金额',
  `split_amount` DECIMAL COMMENT '分摊金额',
  `create_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '订单明细表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_payment_info_df (
  `pay_id` BIGINT COMMENT '',
  `order_id` BIGINT COMMENT '',
  `user_id` BIGINT COMMENT '',
  `pay_type` STRING COMMENT '支付方式 支付宝/微信/银行卡',
  `pay_amount` DECIMAL COMMENT '支付金额',
  `pay_status` TINYINT COMMENT '1成功 2失败',
  `pay_time` STRING COMMENT '',
  `create_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '支付信息表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_refund_info_df (
  `refund_id` BIGINT COMMENT '',
  `order_id` BIGINT COMMENT '',
  `user_id` BIGINT COMMENT '',
  `sku_id` BIGINT COMMENT '',
  `refund_amount` DECIMAL COMMENT '退款金额',
  `refund_status` TINYINT COMMENT '0申请中 1成功 2拒绝',
  `refund_time` STRING COMMENT '',
  `create_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '退款表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_shop_info_df (
  `shop_id` BIGINT COMMENT '门店ID',
  `shop_name` STRING COMMENT '门店名称',
  `city_id` BIGINT COMMENT '城市ID',
  `city_name` STRING COMMENT '城市名称',
  `manager_name` STRING COMMENT '店长',
  `is_open` TINYINT COMMENT '是否营业',
  `create_time` STRING COMMENT '',
  `update_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '门店信息表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_sku_info_df (
  `sku_id` BIGINT COMMENT '商品SKU ID',
  `spu_id` BIGINT COMMENT 'SPU ID',
  `sku_name` STRING COMMENT '商品名称',
  `category_id` BIGINT COMMENT '品类ID',
  `category_name` STRING COMMENT '品类名称',
  `shop_id` BIGINT COMMENT '门店ID',
  `cost_price` DECIMAL COMMENT '成本价',
  `sale_price` DECIMAL COMMENT '销售价',
  `is_on_sale` TINYINT COMMENT '是否上架',
  `is_deleted` TINYINT COMMENT '',
  `create_time` STRING COMMENT '',
  `update_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '商品SKU表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_stock_info_df (
  `id` BIGINT COMMENT '',
  `sku_id` BIGINT COMMENT '',
  `shop_id` BIGINT COMMENT '',
  `stock_num` INT COMMENT '库存数量',
  `update_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '商品库存表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_user_coupon_df (
  `id` BIGINT COMMENT '',
  `user_id` BIGINT COMMENT '',
  `coupon_id` BIGINT COMMENT '',
  `order_id` BIGINT COMMENT '使用订单ID',
  `use_status` TINYINT COMMENT '0未使用 1已使用 2已过期',
  `create_time` STRING COMMENT '',
  `use_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '用户优惠券表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;

CREATE TABLE IF NOT EXISTS ods_mall_oltp_user_info_df (
  `user_id` BIGINT COMMENT '用户ID',
  `user_name` STRING COMMENT '用户名',
  `gender` STRING COMMENT '性别 1男 2女',
  `phone` STRING COMMENT '手机号',
  `register_time` STRING COMMENT '注册时间',
  `register_channel` STRING COMMENT '注册渠道',
  `city_name` STRING COMMENT '所在城市',
  `is_deleted` TINYINT COMMENT '是否删除',
  `create_time` STRING COMMENT '',
  `update_time` STRING COMMENT '',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '用户基础信息表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;