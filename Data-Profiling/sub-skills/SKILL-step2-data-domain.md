# Step 2: 数据域划分

## 目标

基于业务过程清单和表结构盘点，将业务过程归纳抽象为数据域，建立数据域与业务过程的映射关系。

---

## 输入

| 输入项 | 必选 | 格式 | 来源 |
|-------|------|------|------|
| 表结构盘点表 | 必选 | Markdown | Step 1 产出 (01-表结构盘点.md) |
| 业务过程清单 | 必选 | Markdown | Step 1 产出 (02-业务过程清单.md) |
| 业务流程全景图 | 推荐 | Markdown + mermaid | Step 1 产出 (03-业务流程全景图.md) |
| 行业数据域参考模板 | 可选 | Markdown | references/ 目录下对应行业的模板 |

### 输入样例

#### 样例 A：表结构盘点表（来自Step 1 产出）

即 01-表结构盘点.md 的内容，核心是这张表：

```markdown
| 序号 | 表名 | 表注释 | 表角色 | 主键 | 核心字段 | 置信度 |
|-----|------|-------|-------|------|---------|-------|
| 1 | t_proposal | 投保单主表 | 事实表 | proposal_id | proposal_no, customer_id, premium, status | 高 |
| 2 | t_proposal_item | 投保单险种明细 | 事实明细 | item_id | proposal_id, risk_code, sum_insured | 高 |
| 3 | t_applicant | 投保人信息 | 维度表 | applicant_id | proposal_id, customer_id, name | 高 |
| 4 | t_underwrite | 核保记录 | 事实表 | uw_id | proposal_id, uw_result, uw_time | 高 |
| 5 | t_policy | 保单主表 | 事实/维度 | policy_id | policy_no, customer_id, total_premium, status | 高 |
| 6 | t_policy_item | 保单险种明细 | 事实明细 | item_id | policy_id, risk_code, premium | 高 |
| 7 | t_insured | 被保人信息 | 维度表 | insured_id | customer_id, policy_id, name | 高 |
| 8 | t_endorsement | 批单/保全 | 事实表 | endorsement_id | policy_id, endorse_type, endorse_premium | 高 |
| 9 | t_surrender | 退保记录 | 事实表 | surrender_id | policy_id, refund_amount, surrender_reason | 高 |
| 10 | t_renewal | 续保关系 | 事实表 | renewal_id | old_policy_id, new_policy_id | 高 |
| 11 | t_claim_report | 报案记录 | 事实表 | report_id | policy_id, accident_date, status | 高 |
| 12 | t_claim_register | 立案记录 | 事实表 | register_id | report_id, claim_case_no, estimated_amount | 高 |
| ... | ... | ... | ... | ... | ... | ... |
```

#### 样例 B：业务过程清单（来自Step 1 产出）

即 02-业务过程清单.md 的核心内容：

```markdown
| 序号 | 业务过程 | 英文名 | 类型 | 涉及表 | 关键度量字段 |
|-----|---------|-------|------|-------|-------------|
| 1 | 投保 | submit_proposal | 事件 | t_proposal, t_proposal_item, t_applicant | premium（保费） |
| 2 | 核保 | underwrite | 事件 | t_underwrite | — |
| 3 | 出单/承保 | issue_policy | 事件 | t_policy, t_policy_item, t_insured | total_premium（总保费） |
| 4 | 回执签收 | receipt_confirm | 事件 | t_policy.receipt_date | — |
| 5 | 批改/保全 | endorsement | 事件 | t_endorsement | endorse_premium（批退/批加保费） |
| 6 | 退保 | surrender | 事件 | t_surrender | refund_amount（退保金额） |
| 7 | 续保 | renewal | 事件 | t_renewal | — |
| 8 | 报案 | claim_report | 事件 | t_claim_report | — |
| 9 | 立案 | claim_register | 事件 | t_claim_register | estimated_amount（估损金额） |
| 10 | 查勘 | survey | 事件 | t_survey | — |
| 11 | 定损 | loss_assessment | 事件 | t_loss_assessment | assess_amount（定损金额） |
| 12 | 理算 | claim_calculation | 事件 | t_claim_calculation | calc_amount（理算金额） |
| 13 | 核赔 | claim_approval | 事件 | t_claim_approval | approval_amount（核赔金额） |
| 14 | 赔付 | claim_payment | 事件 | t_claim_payment | pay_amount（赔付金额） |
| 15 | 结案 | claim_close | 事件 | t_claim_close | final_amount（最终赔付金额） |
```

#### 样例 C：业务流程全景图（来自Step 1 产出）

即 03-业务流程全景图.md，包含承保板块和理赔板块的 mermaid 流程图。

#### 样例 D：行业数据域参考模板（可选）

用户提供或 Skill 自动匹配 `references/` 下的模板：

```markdown
## 保险行业典型数据域（参考模板）

| 数据域 | 业务过程 | 核心实体 |
|-------|---------|---------|
| 承保域 | 投保、核保、出单、回执、批改、退保、续保 | 保单、投保单、批单 |
| 理赔域 | 报案、立案、查勘、定损、理算、核赔、赔付、结案 | 理赔案件、赔案 |
| 收付费域 | 保费收取、保费退费、佣金支付、手续费结算 | 收付记录、账单 |
| 产品域 | 产品定义、费率管理、条款管理、产品上下架 | 产品、费率表 |
| 客户域 | 客户建档、客户变更、客户合并 | 客户、证件、联系方式 |
| 销管域 | 渠道准入、代理人管理、业绩归属、考核 | 渠道、代理人、业绩 |
| 再保域 | 合约分保、临时分保、摊回计算 | 再保合约、分保记录 |
| 财务域 | 准备金计提、损益核算 | 会计凭证、科目余额 |
| 机构域 | 机构设立/撤销、组织架构变更 | 机构、部门 |
```

> 实际使用时以用户提供的 DDL 为准，模板仅作参考起点。

---

## 产出文件

```
output/
├── 04-数据域划分.md         # 数据域划分表 + 划分说明
└── 05-边界问题清单.md       # 跨域/待确认的边界 case
```

---

## 执行步骤

### Step 1: 核心实体识别

**目标：** 从表结构中识别核心业务实体，为数据域划分提供依据。

**操作：**

1. **提取核心实体**：从维度表候选和外键字段中识别被多张事实表引用的实体
2. **确定实体归属关系**：实体间的层级和关联关系
3. **实体聚类**：将相关实体聚为实体组，每个实体组对应一个候选数据域

**产出样例：**

```markdown
## 核心实体清单

| 实体名称 | 英文名 | 核心表 | 被引用次数 | 被引用事实表 | 关联实体 |
|---------|-------|-------|-----------|------------|---------|
| 保单 | policy | t_policy | 8 | t_endorsement, t_surrender, t_renewal, t_claim_report, t_premium_receive, t_commission_calc, t_performance | 客户、产品、代理人、机构 |
| 客户 | customer | t_customer | 10 | t_policy, t_proposal, t_surrender, t_claim_report, t_claim_register, t_claim_payment, t_premium_receive | 保单、理赔案 |
| 产品 | product | t_product | 4 | t_proposal, t_policy, t_commission_calc, t_performance | 险种 |
| 理赔案件 | claim_case | t_claim_register | 6 | t_survey, t_loss_assessment, t_claim_calculation, t_claim_approval, t_claim_payment, t_claim_close | 保单、客户 |
| 代理人 | agent | t_agent | 3 | t_policy, t_commission_calc, t_performance | 机构、渠道 |
| 机构 | organization | t_organization | 5 | t_policy, t_agent, t_channel, t_commission_calc, t_performance | 代理人 |
| 渠道 | channel | t_channel | 3 | t_policy, t_premium_receive, t_performance | 机构 |
| 投保单 | proposal | t_proposal | 2 | t_proposal_item, t_underwrite | 客户、产品 |
```

### Step 2: 数据域划分

**目标：** 按核心实体聚类，将业务过程归入数据域。

**划分原则（优先级从高到低）：**

1. **业务过程内聚性**：同一流程中的事件归入同一域
2. **核心实体归属**：围绕同一核心实体的操作归入同一域
3. **部门/系统边界**：作为辅助参考

**边界处理规则：**

| 场景 | 处理原则 | 示例 |
|------|---------|------|
| 一个过程跨两个域 | 归入主实体所在域 | 退保涉及退费，退保动作归承保域，退费归收付费域 |
| 公共维度表 | 不归入业务数据域，放入公共维度层 | 时间维度、地域维度、机构维度 |
| 系统支撑表 | 不归入业务数据域 | 码值配置表、系统日志表 |

**操作：**

1. 基于核心实体聚类结果，定义数据域
2. 将业务过程逐一归入对应数据域
3. 处理跨域的业务过程
4. 校验：每个业务过程必须归属一个数据域，无遗漏无重复

**产出样例：**

```markdown
# 04-数据域划分

## 概览
- 数据域数量：6 个
- 业务过程总数：15 个（不含公共维度）
- 覆盖校验：✅ 全部覆盖

---

## 数据域明细

### 承保域（underwriting）

| 属性 | 内容 |
|------|------|
| 数据域中文名 | 承保域 |
| 数据域英文名 | underwriting |
| 核心实体 | 保单（policy）、投保单（proposal）、批单（endorsement） |
| 划分依据 | 围绕"保单"实体的全生命周期操作，从投保到退保 |
| 数据来源系统 | 核心业务系统 |

**包含的业务过程：**

| 业务过程 | 英文名 | 类型 | 涉及表 |
|---------|-------|------|-------|
| 投保 | submit_proposal | 事件 | t_proposal, t_proposal_item, t_applicant |
| 核保 | underwrite | 事件 | t_underwrite |
| 出单/承保 | issue_policy | 事件 | t_policy, t_policy_item, t_insured |
| 回执签收 | receipt_confirm | 事件 | t_policy.receipt_date |
| 批改/保全 | endorsement | 事件 | t_endorsement |
| 退保 | surrender | 事件 | t_surrender |
| 续保 | renewal | 事件 | t_renewal |

---

### 理赔域（claim）

| 属性 | 内容 |
|------|------|
| 数据域中文名 | 理赔域 |
| 数据域英文名 | claim |
| 核心实体 | 理赔案件（claim_case） |
| 划分依据 | 围绕"理赔案件"从报案到结案的全流程操作 |
| 数据来源系统 | 理赔系统 |

**包含的业务过程：**

| 业务过程 | 英文名 | 类型 | 涉及表 |
|---------|-------|------|-------|
| 报案 | claim_report | 事件 | t_claim_report |
| 立案 | claim_register | 事件 | t_claim_register |
| 查勘 | survey | 事件 | t_survey |
| 定损 | loss_assessment | 事件 | t_loss_assessment |
| 理算 | claim_calculation | 事件 | t_claim_calculation |
| 核赔 | claim_approval | 事件 | t_claim_approval |
| 赔付 | claim_payment | 事件 | t_claim_payment |
| 结案 | claim_close | 事件 | t_claim_close |

---

### 收付费域（payment）

| 属性 | 内容 |
|------|------|
| 数据域中文名 | 收付费域 |
| 数据域英文名 | payment |
| 核心实体 | 收付记录（receive_record） |
| 划分依据 | 围绕"资金流动"的所有操作，包括收费和付费 |
| 数据来源系统 | 收付费系统 |

**包含的业务过程：**

| 业务过程 | 英文名 | 类型 | 涉及表 |
|---------|-------|------|-------|
| 保费收取 | premium_receive | 事件 | t_premium_receive |
| 佣金支付 | commission_pay | 事件 | t_commission_calc |

> 注：当前 DDL 中收付费域仅有 2 张表，若后续有退费、手续费结算等表，也应归入此域。

---

### 客户域（customer）

| 属性 | 内容 |
|------|------|
| 数据域中文名 | 客户域 |
| 数据域英文名 | customer |
| 核心实体 | 客户（customer） |
| 划分依据 | 围绕"客户"实体的信息管理操作 |
| 数据来源系统 | 客户系统（CRM） |

**包含的业务过程：** 当前 DDL 中客户表（t_customer、t_id_info、t_contact_info）均为维度表，
记录客户状态信息而非业务事件，暂无独立业务过程。客户表作为一致性维度被承保域、理赔域、收付费域引用。

> 注：若后续有"客户建档"、"客户合并"、"客户信息变更"等事件表，应归入此域。

---

### 产品域（product）

**包含的业务过程：** 当前 DDL 中产品表（t_product、t_product_risk、t_rate_table）均为维度表，
暂无独立业务过程。若后续有"产品定义"、"产品上架"等事件表，应归入此域。

---

### 销管域（sales）

| 属性 | 内容 |
|------|------|
| 数据域中文名 | 销管域 |
| 数据域英文名 | sales |
| 核心实体 | 代理人（agent）、渠道（channel）、业绩（performance） |
| 划分依据 | 围绕销售团队管理和业绩考核的操作 |
| 数据来源系统 | 销管系统 |

**包含的业务过程：**

| 业务过程 | 英文名 | 类型 | 涉及表 |
|---------|-------|------|-------|
| 业绩归属 | performance_record | 事件 | t_performance |

> 注：t_agent、t_channel 当前为维度表。若后续有"代理人招募"、"代理人入离职"、"考核"等事件表，应归入此域。

---

## 数据域划分汇总表

| 数据域 | 业务过程 | 核心实体 | 表数量 |
|-------|---------|---------|-------|
| 承保域 | 投保、核保、出单、回执签收、批改/保全、退保、续保 | 保单、投保单、批单 | 10 |
| 理赔域 | 报案、立案、查勘、定损、理算、核赔、赔付、结案 | 理赔案件 | 8 |
| 收付费域 | 保费收取、佣金支付 | 收付记录 | 2 |
| 客户域 | （暂无事件表） | 客户 | 3（维度） |
| 产品域 | （暂无事件表） | 产品 | 3（维度） |
| 销管域 | 业绩归属 | 代理人、渠道、业绩 | 3 |
| 公共维度 | — | 机构、地域、码值 | 3 |
```

### Step 3: 边界问题清单

**目标：** 整理所有需要人工确认的边界 case 和待确认项。

**产出样例：**

```markdown
# 05-边界问题清单

## 跨域业务过程

| 业务过程 | 可能归属域 | 当前归属 | 归属理由 | 待确认 |
|---------|-----------|---------|---------|-------|
| 退保（surrender） | 承保域 / 收付费域 | 承保域 | 退保动作在承保域发起，t_surrender 与 t_policy 强关联 | 如果退保退费是独立流程（有独立退费表），退费动作应归收付费域 |
| 佣金支付（commission_pay） | 销管域 / 收付费域 | 收付费域 | 佣金支付本质是资金流出，归入收付费域 | 佣金计算逻辑归属销管域，是否需要拆分计算和支付两个过程？ |

## 待人工确认项

| 序号 | 问题 | 来源 | 建议 |
|-----|------|------|------|
| 1 | 客户域和产品域当前无事件表，是否仍作为独立数据域？ | 只有维度表，无业务事件 | 建议保留，后续扩展时可直接归入 |
| 2 | t_busi_log（业务日志）归属哪个域？ | Step 1 标记为低置信度 | 建议归入系统支撑层，不计入业务数据域 |
| 3 | 回执签收是独立业务过程还是保单的一个字段更新？ | 仅有 t_policy.receipt_date 字段，无独立表 | 若无独立事件表，可考虑合并到"出单"过程中 |

## 公共维度表（不归入业务数据域）

| 表名 | 表注释 | 说明 |
|-----|-------|------|
| t_organization | 机构组织表 | 机构维度，被承保域、销管域、收付费域引用 |
| t_region | 行政区划表 | 地域维度，公共维度 |
| t_code_config | 码值配置表 | 系统配置，非业务表 |
```

---

## 注意事项

1. **数据域互斥**：同一业务过程只能归属一个数据域（跨域的拆分到不同过程）
2. **完整性**：所有业务过程必须归属，不能有"无主"过程
3. **粒度适当**：数据域不宜过多（一般 5-12 个），过细会导致模型碎片化
4. **参考但不照搬**：行业模板仅作参考，需根据用户实际数据调整
5. **标注所有不确定项**：用 `❓` 标记，由人工最终确认
