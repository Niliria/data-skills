-- ============================================================
-- 数仓业务建模 · DDL 输入示例文件
-- 模拟某保险公司核心业务系统的表结构
-- 涵盖承保、理赔、收付费、客户、产品等业务板块
-- ============================================================


-- ============================================================
-- 一、承保板块
-- ============================================================

-- 投保单主表
CREATE TABLE t_proposal (
  proposal_id       BIGINT        COMMENT '投保单ID，主键',
  proposal_no       VARCHAR(32)   COMMENT '投保单号，业务唯一标识',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  product_id        BIGINT        COMMENT '产品ID，关联t_product',
  channel_id        BIGINT        COMMENT '渠道ID，关联t_channel',
  agent_id          BIGINT        COMMENT '代理人ID，关联t_agent',
  org_id            BIGINT        COMMENT '出单机构ID，关联t_organization',
  province_code     VARCHAR(10)   COMMENT '投保省份编码',
  city_code         VARCHAR(10)   COMMENT '投保城市编码',
  premium           DECIMAL(18,2) COMMENT '保费金额，单位：元',
  pay_mode          VARCHAR(10)   COMMENT '缴费方式：1-年缴 2-月缴 3-趸缴',
  pay_period        INT           COMMENT '缴费期限，单位：年',
  insure_period     INT           COMMENT '保险期间，单位：年',
  status            VARCHAR(10)   COMMENT '状态：0-待审核 1-审核通过 2-审核拒绝 3-已出单 4-已撤单',
  apply_time        TIMESTAMP     COMMENT '投保申请时间',
  create_time       TIMESTAMP     COMMENT '记录创建时间',
  update_time       TIMESTAMP     COMMENT '记录更新时间'
)
COMMENT '承保业务-投保单主表';

-- 投保单明细表（险种明细）
CREATE TABLE t_proposal_item (
  item_id           BIGINT        COMMENT '明细ID，主键',
  proposal_id       BIGINT        COMMENT '投保单ID，关联t_proposal',
  risk_code         VARCHAR(20)   COMMENT '险种编码',
  risk_name         VARCHAR(100)  COMMENT '险种名称',
  sum_insured       DECIMAL(18,2) COMMENT '保额，单位：元',
  premium           DECIMAL(18,2) COMMENT '险种保费，单位：元',
  insured_id        BIGINT        COMMENT '被保人ID，关联t_insured',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-投保单险种明细表';

-- 投保人/申请人表
CREATE TABLE t_applicant (
  applicant_id      BIGINT        COMMENT '投保人ID，主键',
  proposal_id       BIGINT        COMMENT '投保单ID，关联t_proposal',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  name              VARCHAR(50)   COMMENT '投保人姓名',
  id_type           VARCHAR(10)   COMMENT '证件类型：1-身份证 2-护照 3-军官证',
  id_no             VARCHAR(30)   COMMENT '证件号码',
  phone             VARCHAR(20)   COMMENT '联系电话',
  relation_insured  VARCHAR(10)   COMMENT '与被保人关系：1-本人 2-配偶 3-子女 4-父母',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-投保人信息表';

-- 核保记录表
CREATE TABLE t_underwrite (
  uw_id             BIGINT        COMMENT '核保记录ID，主键',
  proposal_id       BIGINT        COMMENT '投保单ID，关联t_proposal',
  uw_type           VARCHAR(10)   COMMENT '核保方式：1-自动核保 2-人工核保',
  uw_result         VARCHAR(10)   COMMENT '核保结论：1-标准体承保 2-加费 3-除外 4-延期 5-拒保',
  uw_remark         VARCHAR(500)  COMMENT '核保意见',
  uw_operator       VARCHAR(50)   COMMENT '核保人员工号',
  uw_time           TIMESTAMP     COMMENT '核保时间',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-核保记录表';

-- 保单主表
CREATE TABLE t_policy (
  policy_id         BIGINT        COMMENT '保单ID，主键',
  policy_no         VARCHAR(32)   COMMENT '保单号，业务唯一标识',
  proposal_id       BIGINT        COMMENT '投保单ID，关联t_proposal',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  product_id        BIGINT        COMMENT '产品ID，关联t_product',
  channel_id        BIGINT        COMMENT '渠道ID，关联t_channel',
  agent_id          BIGINT        COMMENT '代理人ID，关联t_agent',
  org_id            BIGINT        COMMENT '出单机构ID，关联t_organization',
  province_code     VARCHAR(10)   COMMENT '承保省份编码',
  city_code         VARCHAR(10)   COMMENT '承保城市编码',
  total_premium     DECIMAL(18,2) COMMENT '总保费，单位：元',
  pay_mode          VARCHAR(10)   COMMENT '缴费方式：1-年缴 2-月缴 3-趸缴',
  pay_period        INT           COMMENT '缴费期限，单位：年',
  insure_period     INT           COMMENT '保险期间，单位：年',
  start_date        DATE          COMMENT '保险起期',
  end_date          DATE          COMMENT '保险止期',
  status            VARCHAR(10)   COMMENT '保单状态：1-有效 2-失效 3-退保 4-满期 5-理赔终止',
  sign_date         DATE          COMMENT '签单日期',
  receipt_date      DATE          COMMENT '回执签收日期',
  create_time       TIMESTAMP     COMMENT '记录创建时间',
  update_time       TIMESTAMP     COMMENT '记录更新时间'
)
COMMENT '承保业务-保单主表';

-- 保单险种明细表
CREATE TABLE t_policy_item (
  item_id           BIGINT        COMMENT '明细ID，主键',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  risk_code         VARCHAR(20)   COMMENT '险种编码',
  risk_name         VARCHAR(100)  COMMENT '险种名称',
  sum_insured       DECIMAL(18,2) COMMENT '保额，单位：元',
  premium           DECIMAL(18,2) COMMENT '险种保费，单位：元',
  insured_id        BIGINT        COMMENT '被保人ID，关联t_insured',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-保单险种明细表';

-- 被保人表
CREATE TABLE t_insured (
  insured_id        BIGINT        COMMENT '被保人ID，主键',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  name              VARCHAR(50)   COMMENT '被保人姓名',
  id_type           VARCHAR(10)   COMMENT '证件类型：1-身份证 2-护照 3-军官证',
  id_no             VARCHAR(30)   COMMENT '证件号码',
  birth_date        DATE          COMMENT '出生日期',
  gender            VARCHAR(5)    COMMENT '性别：M-男 F-女',
  occupation_code   VARCHAR(10)   COMMENT '职业编码',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-被保人信息表';

-- 批改/保全表
CREATE TABLE t_endorsement (
  endorsement_id    BIGINT        COMMENT '批单ID，主键',
  endorsement_no    VARCHAR(32)   COMMENT '批单号，业务唯一标识',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  endorse_type      VARCHAR(20)   COMMENT '批改类型：1-加保 2-减保 3-变更受益人 4-变更缴费方式 5-其他',
  old_premium       DECIMAL(18,2) COMMENT '变更前保费，单位：元',
  new_premium       DECIMAL(18,2) COMMENT '变更后保费，单位：元',
  endorse_premium   DECIMAL(18,2) COMMENT '批退/批加保费，单位：元',
  status            VARCHAR(10)   COMMENT '状态：0-待审核 1-已完成 2-已撤销',
  apply_time        TIMESTAMP     COMMENT '申请时间',
  complete_time     TIMESTAMP     COMMENT '完成时间',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-批单/保全主表';

-- 退保表
CREATE TABLE t_surrender (
  surrender_id      BIGINT        COMMENT '退保ID，主键',
  surrender_no      VARCHAR(32)   COMMENT '退保单号',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  surrender_type    VARCHAR(10)   COMMENT '退保类型：1-犹豫期退保 2-正常退保',
  refund_amount     DECIMAL(18,2) COMMENT '退保金额，单位：元',
  surrender_reason  VARCHAR(200)  COMMENT '退保原因',
  status            VARCHAR(10)   COMMENT '状态：0-待审核 1-已完成 2-已拒绝',
  apply_time        TIMESTAMP     COMMENT '申请时间',
  complete_time     TIMESTAMP     COMMENT '完成时间',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-退保记录表';

-- 续保关系表
CREATE TABLE t_renewal (
  renewal_id        BIGINT        COMMENT '续保记录ID，主键',
  old_policy_id     BIGINT        COMMENT '原保单ID，关联t_policy',
  new_policy_id     BIGINT        COMMENT '新保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  renewal_type      VARCHAR(10)   COMMENT '续保类型：1-自动续保 2-手动续保',
  renewal_date      DATE          COMMENT '续保日期',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '承保业务-续保关系表';


-- ============================================================
-- 二、理赔板块
-- ============================================================

-- 报案表
CREATE TABLE t_claim_report (
  report_id         BIGINT        COMMENT '报案ID，主键',
  report_no         VARCHAR(32)   COMMENT '报案号，业务唯一标识',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '报案人客户ID，关联t_customer',
  insured_id        BIGINT        COMMENT '被保人ID，关联t_insured',
  accident_date     DATE          COMMENT '出险日期',
  accident_type     VARCHAR(20)   COMMENT '出险类型：1-意外 2-疾病 3-身故 4-残疾',
  accident_desc     VARCHAR(500)  COMMENT '出险经过描述',
  report_date       DATE          COMMENT '报案日期',
  reporter_name     VARCHAR(50)   COMMENT '报案人姓名',
  reporter_phone    VARCHAR(20)   COMMENT '报案人电话',
  province_code     VARCHAR(10)   COMMENT '出险省份编码',
  city_code         VARCHAR(10)   COMMENT '出险城市编码',
  status            VARCHAR(10)   COMMENT '报案状态：0-待处理 1-已立案 2-拒立案 3-已销案',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-报案记录表';

-- 立案表
CREATE TABLE t_claim_register (
  register_id       BIGINT        COMMENT '立案ID，主键',
  claim_case_no     VARCHAR(32)   COMMENT '理赔案号，业务唯一标识',
  report_id         BIGINT        COMMENT '报案ID，关联t_claim_report',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  register_date     DATE          COMMENT '立案日期',
  register_operator VARCHAR(50)   COMMENT '立案人员工号',
  estimated_amount  DECIMAL(18,2) COMMENT '估损金额，单位：元',
  status            VARCHAR(10)   COMMENT '立案状态：1-已立案 2-已拒立案',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-立案记录表';

-- 查勘记录表
CREATE TABLE t_survey (
  survey_id         BIGINT        COMMENT '查勘记录ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  surveyor_id       BIGINT        COMMENT '查勘员ID',
  survey_date       DATE          COMMENT '查勘日期',
  survey_address    VARCHAR(200)  COMMENT '查勘地址',
  survey_result     VARCHAR(500)  COMMENT '查勘结论',
  province_code     VARCHAR(10)   COMMENT '查勘省份编码',
  city_code         VARCHAR(10)   COMMENT '查勘城市编码',
  status            VARCHAR(10)   COMMENT '查勘状态：0-待查勘 1-已查勘 2-需重新查勘',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-查勘记录表';

-- 定损表
CREATE TABLE t_loss_assessment (
  assessment_id     BIGINT        COMMENT '定损ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  assess_amount     DECIMAL(18,2) COMMENT '定损金额，单位：元',
  assess_date       DATE          COMMENT '定损日期',
  assessor_id       VARCHAR(50)   COMMENT '定损人员工号',
  assess_remark     VARCHAR(500)  COMMENT '定损说明',
  status            VARCHAR(10)   COMMENT '状态：0-待审核 1-已通过 2-需补充',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-定损记录表';

-- 理算表
CREATE TABLE t_claim_calculation (
  calc_id           BIGINT        COMMENT '理算ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  calc_amount       DECIMAL(18,2) COMMENT '理算金额，单位：元',
  deductible        DECIMAL(18,2) COMMENT '免赔额，单位：元',
  pay_ratio         DECIMAL(5,4)  COMMENT '赔付比例',
  calc_date         DATE          COMMENT '理算日期',
  calculator_id     VARCHAR(50)   COMMENT '理算人员工号',
  status            VARCHAR(10)   COMMENT '状态：0-待审核 1-已通过',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-理算记录表';

-- 核赔审批表
CREATE TABLE t_claim_approval (
  approval_id       BIGINT        COMMENT '核赔ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  approval_amount   DECIMAL(18,2) COMMENT '核赔金额，单位：元',
  approval_result   VARCHAR(10)   COMMENT '核赔结论：1-同意赔付 2-部分赔付 3-拒赔',
  approval_remark   VARCHAR(500)  COMMENT '核赔意见',
  approver_id       VARCHAR(50)   COMMENT '核赔人员工号',
  approval_date     DATE          COMMENT '核赔日期',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-核赔审批表';

-- 赔付记录表
CREATE TABLE t_claim_payment (
  payment_id        BIGINT        COMMENT '赔付ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  customer_id       BIGINT        COMMENT '收款人客户ID，关联t_customer',
  pay_amount        DECIMAL(18,2) COMMENT '赔付金额，单位：元',
  pay_method        VARCHAR(10)   COMMENT '支付方式：1-银行转账 2-支票',
  pay_account       VARCHAR(30)   COMMENT '收款账号',
  pay_date          DATE          COMMENT '赔付日期',
  status            VARCHAR(10)   COMMENT '状态：0-待支付 1-已支付 2-支付失败',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-赔付记录表';

-- 结案表
CREATE TABLE t_claim_close (
  close_id          BIGINT        COMMENT '结案ID，主键',
  register_id       BIGINT        COMMENT '立案ID，关联t_claim_register',
  close_date        DATE          COMMENT '结案日期',
  close_type        VARCHAR(10)   COMMENT '结案类型：1-正常结案 2-拒赔结案 3-销案',
  final_amount      DECIMAL(18,2) COMMENT '最终赔付金额，单位：元',
  close_operator    VARCHAR(50)   COMMENT '结案人员工号',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '理赔业务-结案记录表';


-- ============================================================
-- 三、收付费板块
-- ============================================================

-- 保费收取表
CREATE TABLE t_premium_receive (
  receive_id        BIGINT        COMMENT '收费ID，主键',
  receive_no        VARCHAR(32)   COMMENT '收费单号',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  agent_id          BIGINT        COMMENT '代理人ID，关联t_agent',
  org_id            BIGINT        COMMENT '收费机构ID，关联t_organization',
  channel_id        BIGINT        COMMENT '收费渠道ID，关联t_channel',
  receive_amount    DECIMAL(18,2) COMMENT '收费金额，单位：元',
  pay_method        VARCHAR(10)   COMMENT '支付方式：1-银行转账 2-现金 3-代扣',
  period_no         INT           COMMENT '期次号',
  receive_date      DATE          COMMENT '收费日期',
  status            VARCHAR(10)   COMMENT '状态：1-已收费 2-收费失败 3-待催缴',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '收付费业务-保费收取记录表';

-- 佣金计算表
CREATE TABLE t_commission_calc (
  commission_id     BIGINT        COMMENT '佣金ID，主键',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  agent_id          BIGINT        COMMENT '代理人ID，关联t_agent',
  org_id            BIGINT        COMMENT '机构ID，关联t_organization',
  commission_type   VARCHAR(10)   COMMENT '佣金类型：1-首期佣金 2-续期佣金 3-奖金',
  commission_rate   DECIMAL(5,4)  COMMENT '佣金比例',
  commission_amount DECIMAL(18,2) COMMENT '佣金金额，单位：元',
  calc_period       VARCHAR(10)   COMMENT '计算期间，如202501',
  calc_date         DATE          COMMENT '计算日期',
  status            VARCHAR(10)   COMMENT '状态：0-待发放 1-已发放',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '收付费业务-佣金计算表';


-- ============================================================
-- 四、客户板块
-- ============================================================

-- 客户主表
CREATE TABLE t_customer (
  customer_id       BIGINT        COMMENT '客户ID，主键',
  customer_name     VARCHAR(50)   COMMENT '客户姓名',
  customer_type     VARCHAR(10)   COMMENT '客户类型：1-个人 2-团体',
  id_type           VARCHAR(10)   COMMENT '证件类型：1-身份证 2-护照 3-军官证 4-统一社会信用代码',
  id_no             VARCHAR(30)   COMMENT '证件号码',
  gender            VARCHAR(5)    COMMENT '性别：M-男 F-女',
  birth_date        DATE          COMMENT '出生日期',
  phone             VARCHAR(20)   COMMENT '手机号',
  email             VARCHAR(100)  COMMENT '邮箱',
  province_code     VARCHAR(10)   COMMENT '省份编码',
  city_code         VARCHAR(10)   COMMENT '城市编码',
  address           VARCHAR(200)  COMMENT '详细地址',
  occupation_code   VARCHAR(10)   COMMENT '职业编码',
  source_channel    VARCHAR(20)   COMMENT '客户来源渠道',
  create_time       TIMESTAMP     COMMENT '记录创建时间',
  update_time       TIMESTAMP     COMMENT '记录更新时间'
)
COMMENT '客户管理-客户主表';

-- 客户证件表
CREATE TABLE t_id_info (
  id_info_id        BIGINT        COMMENT '证件记录ID，主键',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  id_type           VARCHAR(10)   COMMENT '证件类型：1-身份证 2-护照 3-军官证',
  id_no             VARCHAR(30)   COMMENT '证件号码',
  issue_date        DATE          COMMENT '证件签发日期',
  expire_date       DATE          COMMENT '证件到期日期',
  is_primary        VARCHAR(5)    COMMENT '是否主要证件：Y-是 N-否',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '客户管理-客户证件信息表';

-- 客户联系方式表
CREATE TABLE t_contact_info (
  contact_id        BIGINT        COMMENT '联系方式ID，主键',
  customer_id       BIGINT        COMMENT '客户ID，关联t_customer',
  contact_type      VARCHAR(10)   COMMENT '联系方式类型：1-手机 2-固话 3-邮箱 4-地址',
  contact_value     VARCHAR(200)  COMMENT '联系方式内容',
  is_primary        VARCHAR(5)    COMMENT '是否主要联系方式：Y-是 N-否',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '客户管理-客户联系方式表';


-- ============================================================
-- 五、产品板块
-- ============================================================

-- 产品主表
CREATE TABLE t_product (
  product_id        BIGINT        COMMENT '产品ID，主键',
  product_code      VARCHAR(20)   COMMENT '产品编码，业务唯一标识',
  product_name      VARCHAR(100)  COMMENT '产品名称',
  product_type      VARCHAR(20)   COMMENT '产品类型：1-寿险 2-健康险 3-意外险 4-财产险',
  risk_category     VARCHAR(20)   COMMENT '险类：A-人寿 B-重疾 C-医疗 D-意外 E-年金',
  company_code      VARCHAR(20)   COMMENT '所属公司编码',
  sale_start_date   DATE          COMMENT '开售日期',
  sale_end_date     DATE          COMMENT '停售日期',
  status            VARCHAR(10)   COMMENT '状态：1-在售 2-停售 3-待上架',
  create_time       TIMESTAMP     COMMENT '记录创建时间',
  update_time       TIMESTAMP     COMMENT '记录更新时间'
)
COMMENT '产品管理-产品主表';

-- 产品险种表
CREATE TABLE t_product_risk (
  risk_id           BIGINT        COMMENT '险种ID，主键',
  product_id        BIGINT        COMMENT '产品ID，关联t_product',
  risk_code         VARCHAR(20)   COMMENT '险种编码',
  risk_name         VARCHAR(100)  COMMENT '险种名称',
  risk_type         VARCHAR(10)   COMMENT '险种类型：1-主险 2-附加险',
  max_age           INT           COMMENT '最大投保年龄',
  min_age           INT           COMMENT '最小投保年龄',
  wait_period       INT           COMMENT '等待期，单位：天',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '产品管理-产品险种明细表';

-- 费率表
CREATE TABLE t_rate_table (
  rate_id           BIGINT        COMMENT '费率ID，主键',
  product_id        BIGINT        COMMENT '产品ID，关联t_product',
  risk_code         VARCHAR(20)   COMMENT '险种编码',
  age               INT           COMMENT '年龄',
  gender            VARCHAR(5)    COMMENT '性别：M-男 F-女',
  pay_period        INT           COMMENT '缴费期限',
  insure_period     INT           COMMENT '保险期间',
  rate_value        DECIMAL(10,6) COMMENT '费率值（每千元保额）',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '产品管理-费率表';


-- ============================================================
-- 六、销管板块
-- ============================================================

-- 渠道表
CREATE TABLE t_channel (
  channel_id        BIGINT        COMMENT '渠道ID，主键',
  channel_code      VARCHAR(20)   COMMENT '渠道编码',
  channel_name      VARCHAR(100)  COMMENT '渠道名称',
  channel_type      VARCHAR(20)   COMMENT '渠道类型：1-个险 2-银保 3-团险 4-电销 5-互联网',
  org_id            BIGINT        COMMENT '所属机构ID，关联t_organization',
  status            VARCHAR(10)   COMMENT '状态：1-有效 2-停用',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '销售管理-渠道信息表';

-- 代理人表
CREATE TABLE t_agent (
  agent_id          BIGINT        COMMENT '代理人ID，主键',
  agent_code        VARCHAR(20)   COMMENT '代理人工号',
  agent_name        VARCHAR(50)   COMMENT '代理人姓名',
  id_no             VARCHAR(30)   COMMENT '身份证号',
  org_id            BIGINT        COMMENT '所属机构ID，关联t_organization',
  channel_id        BIGINT        COMMENT '所属渠道ID，关联t_channel',
  team_id           BIGINT        COMMENT '所属团队ID',
  rank_code         VARCHAR(10)   COMMENT '职级编码',
  entry_date        DATE          COMMENT '入职日期',
  leave_date        DATE          COMMENT '离职日期',
  status            VARCHAR(10)   COMMENT '状态：1-在职 2-离职 3-冻结',
  create_time       TIMESTAMP     COMMENT '记录创建时间',
  update_time       TIMESTAMP     COMMENT '记录更新时间'
)
COMMENT '销售管理-代理人信息表';

-- 业绩归属表
CREATE TABLE t_performance (
  performance_id    BIGINT        COMMENT '业绩记录ID，主键',
  policy_id         BIGINT        COMMENT '保单ID，关联t_policy',
  agent_id          BIGINT        COMMENT '代理人ID，关联t_agent',
  org_id            BIGINT        COMMENT '机构ID，关联t_organization',
  channel_id        BIGINT        COMMENT '渠道ID，关联t_channel',
  product_id        BIGINT        COMMENT '产品ID，关联t_product',
  premium           DECIMAL(18,2) COMMENT '业绩保费，单位：元',
  std_premium       DECIMAL(18,2) COMMENT '标准保费，单位：元',
  fyb               DECIMAL(18,2) COMMENT '首年标保，单位：元',
  performance_type  VARCHAR(10)   COMMENT '业绩类型：1-新单 2-续期 3-加保',
  sign_date         DATE          COMMENT '签单日期',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '销售管理-业绩归属表';


-- ============================================================
-- 七、公共维度表
-- ============================================================

-- 机构表
CREATE TABLE t_organization (
  org_id            BIGINT        COMMENT '机构ID，主键',
  org_code          VARCHAR(20)   COMMENT '机构编码',
  org_name          VARCHAR(100)  COMMENT '机构名称',
  org_type          VARCHAR(10)   COMMENT '机构类型：1-总公司 2-省分公司 3-中心支公司 4-支公司 5-营销服务部',
  parent_org_id     BIGINT        COMMENT '上级机构ID，关联本表',
  org_level         INT           COMMENT '机构层级',
  province_code     VARCHAR(10)   COMMENT '所在省份编码',
  city_code         VARCHAR(10)   COMMENT '所在城市编码',
  status            VARCHAR(10)   COMMENT '状态：1-有效 2-撤销',
  create_time       TIMESTAMP     COMMENT '记录创建时间'
)
COMMENT '公共维度-机构组织表';

-- 行政区划表
CREATE TABLE t_region (
  region_code       VARCHAR(10)   COMMENT '区划编码，主键',
  region_name       VARCHAR(50)   COMMENT '区划名称',
  region_type       VARCHAR(10)   COMMENT '区划类型：1-省 2-市 3-区县',
  parent_code       VARCHAR(10)   COMMENT '上级区划编码',
  region_level      INT           COMMENT '层级'
)
COMMENT '公共维度-行政区划表';

-- 码值配置表
CREATE TABLE t_code_config (
  config_id         BIGINT        COMMENT '配置ID，主键',
  code_type         VARCHAR(50)   COMMENT '码值类型，如policy_status、claim_status',
  code_value        VARCHAR(20)   COMMENT '码值',
  code_desc         VARCHAR(100)  COMMENT '码值含义',
  sort_no           INT           COMMENT '排序号',
  status            VARCHAR(5)    COMMENT '状态：1-有效 0-停用'
)
COMMENT '公共配置-码值配置表';
