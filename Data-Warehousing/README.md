# 数据仓库建设

基于 Kimball《数据仓库工具箱》与《阿里巴巴大数据之路》方法论，从 0 到 1 构建数据仓库。

## 目录结构

```
Data-Warehousing/
├── input/          # 输入：数据库连接配置、词根参考等
├── output/         # 输出：各阶段产出（DDL、ETL、总线矩阵等）
└── sub-skills/     # 负责各环节的 skill 定义与脚本
```

## 总体流程

整体遵循五步递进，每一步的产出是下一步的输入：

1. **元数据补全**（`metadata_parse`） — 连接业务库，导出表结构、字段、主外键、空值率
2. **ODS 贴源层**（`ods-generator`） — 基于元数据生成贴源层 Hive DDL
3. **总线矩阵**（`dwm-*`） — 识别业务过程、确认维度与事实，组装总线矩阵
4. **CDM 建模**（`cdm_modeling`） — 生成 DIM/DWD 模型、建表语句和 ETL
5. **DWS 汇总层**（`dws-designer`） — 基于 DIM/DWD 生成原子指标汇总模型

详细每个步骤的设计、触发词、输入输出见下方建设流程。

## 建设流程

### 步骤1：元数据补全

> **涉及 skill**：`metadata_parse`

```mermaid
flowchart LR
    A[💬 触发词] --> B[⚙️ 处理] --> C[📦 输出]

    A -->|"分析数据库结构<br/>表关系<br/>数据质量"| A

    B -->|"连接业务数据库<br/>导出所有表元数据<br/>自动生成字段注释<br/>计算字段空值率<br/>解析外键引用关系"| B

    C -->|"output/metadata_parse/<br/>all_tables_metadata.xlsx<br/>包含：表名、字段、主键、<br/>外键引用、空值率、行数"| C
```

| 项目 | 说明 |
|------|------|
| 输入 | `input/metadata_parse/config.yaml`（数据库连接信息） |
| 核心逻辑 | 连接业务库 → 遍历所有表 → 提取字段/注释/主外键/空值率 → 输出 Excel |
| 输出 | `output/metadata_parse/all_tables_metadata.xlsx` |
| 效果 | 一份完整的基础元数据档案，字段角色、外键引用关系、数据质量一目了然 |

---

### 步骤2：ODS 层生成

> **涉及 skill**：`ods-generator`

```mermaid
flowchart LR
    A[💬 触发词] --> B[⚙️ 处理] --> C[📦 输出]

    A -->|"生成ODS表结构<br/>Excel转Hive DDL<br/>批量生成Hive建表语句"| A

    B -->|"读取元数据Excel<br/>数据类型映射→Hive<br/>字段名规范化<br/>主外键自动识别<br/>命名：ods_{系统}_{表名}_df"| B

    C -->|"output/ods_generator/<br/>all_tables_metadata_ods.xlsx<br/>all_tables_metadata_ods.sql<br/>可直接执行的Hive DDL"| C
```

| 项目 | 说明 |
|------|------|
| 输入 | `output/metadata_parse/all_tables_metadata.xlsx` |
| 核心逻辑 | 读取元数据 → 类型映射（VARCHAR→STRING 等） → 字段规范化 → 生成 `ods_{系统}_{表}_df` 格式的 DDL |
| 输出 | `output/ods_generator/xxx_ods.xlsx`、`xxx_ods.sql` |
| 效果 | 所有业务表对应的 ODS 贴源层建表语句，按 `pt` 日期分区，ORC 格式存储 |

---

### 步骤3：总线矩阵设计

> **涉及 skill**：`dwm-business-process` → `dwm-dimension` → `dwm-matrix`（串联编排）

```mermaid
flowchart TD
    A[💬 触发词] --> B[① dwm-business-process]
    B --> C[② dwm-dimension]
    C --> D[③ dwm-matrix]

    A -->|"构建总线矩阵<br/>识别业务过程<br/>确认维度/事实<br/>总线矩阵验证"| A

    B -->|"识别业务过程<br/>声明粒度<br/>确认事实表类型<br/>度量归属"| B
    B -->|产出| B1["dwm_bp_business_process<br/>dwm_dwd_fact_spec<br/>dwm_dwd_join_spec"]

    C -->|"提取维度引用<br/>收敛一致性维度<br/>SCD策略确认<br/>退化维度判定"| C
    C -->|产出| C1["dwm_dim_spec<br/>dwm_dim_join_spec"]

    D -->|"组装总线矩阵<br/>粒度唯一性验证<br/>JOIN缺失率验证<br/>维度口径一致性验证"| D
    D -->|"产出<br/>output/dwm-bus-matrix/<br/>dwm_bus_matrix.xlsx"| D1["总线矩阵Excel<br/>事实×维度交叉表"]
```

| 项目 | 说明 |
|------|------|
| 输入 | `output/metadata_parse/all_tables_metadata.xlsx`、`output/ods_generator/` ODS 表清单 |
| 核心逻辑 | 识别业务过程 → 确定粒度 → 确认事实/度量 → 提取维度 → 收敛一致性维度 → 组装验证总线矩阵 |
| 输出 | `output/dwm-bus-matrix/dwm_bus_matrix.xlsx`（含业务过程清单、主题域、维度规格、事实规格） |
| 效果 | 一张事实 × 维度的交叉矩阵，所有后续建模以此为准绳 |

---

### 步骤4：CDM 层建模（DIM + DWD）

> **涉及 skill**：`cdm_modeling`

```mermaid
flowchart TD
    A[💬 触发词] --> S1[① 读取校验上游] --> S2[② DIM 设计] --> S3[③ DWD 设计] --> S4[④ 生成 DDL/ETL] --> S5[⑤ 门禁校验]

    A -->|"CDM建模<br/>DIM设计/DWD设计<br/>维度表/事实表生成<br/>SCD策略/拉链表<br/>建表语句/ETL脚本"| A

    S1 -->|"解析 DWM DIM/DWD spec<br/>校验输入完整性"| S1

    S2 -->|"生成维度表设计<br/>确定业务键、属性<br/>确认 SCD 策略"| S2

    S3 -->|"生成事实表设计<br/>确定粒度、外键、度量<br/>星形模型关联"| S3

    S4 -->|"渲染 DDL/ETL<br/>字段映射清单<br/>依赖关系清单"| S4

    S5 -->|"模型校验报告<br/>validation_report.md"| S5
```

| 项目 | 说明 |
|------|------|
| 输入 | 总线矩阵 DIM/DWD spec（步骤3产出） |
| 核心逻辑 | 五步流程：上游校验 → DIM 设计（维度表+SCD） → DWD 设计（事实表+度量） → 生成 DDL/ETL → 门禁校验 |
| 输出 | `output/cdm-modeling/ddl/{dim,dwd}/`、`output/cdm-modeling/etl/{dim,dwd}/`、`docs/dim_list.csv`、`docs/dwd_list.csv` |
| 效果 | 维度表与事实表的完整 DDL + ETL，星形模型可直接部署 |

---

### 步骤5：DWS 汇总层设计

> **涉及 skill**：`dws-designer`

```mermaid
flowchart LR
    A[💬 触发词] --> B[⚙️ 处理] --> C[📦 输出]

    A -->|"DWS汇总层设计<br/>原子指标聚合<br/>汇总模型生成"| A

    B -->|"加载 DWD/DIM spec<br/>确定主粒度与聚合周期<br/>分表规则判断<br/>维度属性冗余白名单<br/>DWS 仅承载原子指标"| B

    C -->|"output/dws-designer/<br/>docs/dws_list.csv<br/>ddl/dws/xxx.sql<br/>etl/dws/xxx.sql"| C
```

| 项目 | 说明 |
|------|------|
| 输入 | `output/dwm-bus-matrix/dwm_bus_matrix.xlsx`、`output/cdm-modeling/docs/{dwd,dim}_list.csv` |
| 核心逻辑 | 确定主粒度 → 判断分表规则（粒度不同/实时离线 必须分表） → 维度属性冗余（白名单机制） → 原子指标聚合（禁止复合/派生指标） |
| 输出 | `output/dws-designer/docs/dws_list.csv`、`output/dws-designer/{ddl,etl}/dws/` |
| 效果 | 按主粒度分表的汇总层模型，口径统一，指标原子化，可直接上调度 |

---

## 全局 Skill

| skill | 触发词 | 说明 |
|-------|--------|------|
| `sql-style` | SQL风格、SQL规范、代码风格、SQL格式 | 统一所有 DDL/DML 的书写风格：缩进、对齐、命名、注释规范 |

## 设计原则

- **自下而上**：从业务元数据出发，逐层推导 ODS → 总线矩阵 → DIM/DWD → DWS
- **维度建模**：以总线矩阵为核心，统一维度和事实的口径定义，星形模型组织
- **输入输出分离**：`input/` 存放原始输入，`output/` 存放各阶段产出，`sub-skills/` 集中管理 skill 定义与脚本
- **原子指标边界**：DWS 层仅承载原子指标（SUM/COUNT/MAX/MIN），复合/派生指标下沉至 ADS
