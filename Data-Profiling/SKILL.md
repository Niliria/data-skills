---
name: 业务场景模拟
description: >
  输入一个行业名称和探查深度，自动生成该行业的业务场景模拟网页。
  包含业务线清单、业务流程、表结构 DDL、模拟数据、ER 关系图。
  当用户提到"业务场景"、"行业模拟"、"生成表结构"、"模拟数据"、
  "生成业务场景网页"或输入行业名称时触发。
---

# 业务场景模拟

## 概述

本 Skill 接收用户输入的行业名称（如"电商"、"金融"、"医疗"）和探查深度（1/2/≥3），
通过 LLM 分步生成业务数据，注入 HTML 模板，输出一个可交互的单文件网页。

## 深度参数

| 探查深度 | 业务线数 | 每业务表数 | 流程描述 | 模拟数据量 |
|---------|---------|-----------|---------|-----------|
| 1 | 2-3 | 3-5 | 纯文字描述 | 每表 5-10 条 |
| 2（默认） | 4-5 | 5-10 | 文字 + Mermaid 流程图 | 每表 10-20 条 |
| ≥3 | 5-8 | 10-20 | 完整流程图 + 异常分支 | 每表 20-50 条 |

**默认行为：** 用户未指定深度时，默认使用深度=2（中等）。

**输入校验：**
- 行业名称为空 → 提示用户输入
- 深度=0、负数、非数字 → 按深度=1 处理
- 模板文件不存在 → 提示用户并终止

## 核心工作流

### Step 1：读取模板

读取 `templates/index.html` 文件内容，作为输出 HTML 的骨架。

如果模板文件不存在，提示用户并终止执行。

### Step 2：生成业务数据 JSON

根据用户输入的行业和深度，生成符合以下结构的 JSON 数据：

```json
{
  "industry": "string - 行业名称",
  "depth": "number - 探查深度(1/2/≥3)",
  "generateTime": "string - YYYY-MM-DD HH:mm:ss",
  "businessLines": [
    {
      "name": "string - 业务线名称",
      "description": "string - 业务线描述",
      "processes": [
        {
          "name": "string - 流程名称",
          "description": "string - 流程描述",
          "flowchart": "string - Mermaid graph 语法(深度≥2时生成)",
          "tables": ["string - 表名"]
        }
      ],
      "tables": [
        {
          "name": "string - 表名",
          "comment": "string - 表注释",
          "columns": [
            { "name": "string", "type": "string", "comment": "string", "isPk": "boolean" }
          ],
          "ddl": "string - 完整 CREATE TABLE 语句",
          "data": ["object - 每行是一个键值对，key 为字段名"]
        }
      ],
      "relations": [
        { "from": "string - 源表名", "to": "string - 目标表名", "type": "string - 1:N 或 1:1", "field": "string - 关联字段名" }
      ]
    }
  ]
}
```

**生成规则：**
- 业务线名称要符合行业实际，不要编造不存在的业务
- 表命名遵循数仓规范：dim_（维度表）、dwd_（明细事实表）、dws_（汇总事实表）
- 字段命名使用 snake_case，类型使用 Hive/MySQL 常见类型
- 模拟数据要真实合理，符合业务场景
- 深度=1 时不生成 flowchart 字段

### Step 3：注入数据到模板

将生成的 JSON 数据替换模板中的 `null; // BIZ_DATA_PLACEHOLDER` 占位符。

```javascript
const BIZ_DATA = { ...生成的JSON... };
```

即把模板中的：
```javascript
const BIZ_DATA = null; // BIZ_DATA_PLACEHOLDER — Skill 执行时替换为实际 JSON 数据
```
替换为：
```javascript
const BIZ_DATA = { "industry": "...", "depth": ..., ... };
```

### Step 4：输出 HTML 文件

将填充后的 HTML 内容写入文件：

```
Data-Profiling/biz-scenario-{行业}-{时间戳}.html
```

文件名规则：`biz-scenario-{行业拼音或英文}-{YYYYMMDDHHmm}.html`

### Step 5：告知用户

输出文件路径，告知用户可以双击打开查看。

## 增量迭代

当用户要求调整深度时（如"把深度改为3"、"再深入一点"、"简化一些"）：

1. **读取已有 HTML 文件**，找到 `const BIZ_DATA = ` 行，提取 `=` 之后到 `;` 之前的 JSON 内容
2. **判断方向：**
   - **深化**（深度增加）：保留已有表，新增表到目标数量；已有表追加模拟数据；流程描述加深
   - **简化**（深度减少）：保留核心表，移除扩展表；模拟数据缩减到目标数量
3. **重新生成差异部分**，合并到已有数据
4. **重新注入模板**，覆盖原文件或生成新文件

## 示例

**用户输入：** 帮我生成电商行业的业务场景，深度2

**执行：**
1. 读取模板
2. 生成电商行业 JSON（商品管理、订单交易、用户中心、营销推广、物流 5 个业务线）
3. 每个业务线 5-10 张表，含 Mermaid 流程图
4. 每表 10-20 条模拟数据
5. 输出 `Data-Profiling/biz-scenario-dianshang-202605081430.html`

**用户输入：** 把深度改为3，继续深化

**执行：**
1. 读取已有 HTML，提取 BIZ_DATA
2. 深度从 2 升到 3，新增表到 10-20 张/业务线
3. 模拟数据追加到 20-50 条
4. 流程描述增加异常分支
5. 更新文件
