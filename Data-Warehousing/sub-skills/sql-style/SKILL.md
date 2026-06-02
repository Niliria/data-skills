---
name: sql-style
description: >-
  SQL 代码风格规范 Skill。Use when the user asks about "SQL风格", "SQL规范",
  "代码风格", "SQL格式", "format SQL", "SQL code style", or when generating
  any SQL script that should follow the standard DDL/DML style conventions.
  This skill defines the canonical SQL formatting rules for all generated
  SparkSQL/HiveSQL scripts in this project.
version: 1.0.0
---

# SQL 代码风格规范

## 职责

规定本项目所有 SQL 脚本（DDL 建表 + DML 数据写入）的统一书写风格。
**任何生成或审查 SQL 的场景，均须遵循此规范。**

## 规范速查

### DDL

- `CREATE` 前保留注释掉的 `-- DROP TABLE IF EXISTS ...;`
- 左括号 `(` 紧跟表名，不换行
- 首列 4 空格缩进，**无**前导逗号；后续列前导逗号 `,` **紧贴**列名
- 列名、类型、`COMMENT` 三列各自对齐，以最长类型为基准
- 右括号 `)` **紧跟** `COMMENT '表注释'`，不留空格
- `PARTITIONED BY` / `STORED AS ORC` 各占独立一行
- 语句以独立 `;` 结尾

### DML

- WITH CTE：每个 CTE 前加 `-- 处理xxxx` 注释，内部遵循 SELECT 规范，非末尾 CTE 的 `)` 后跟 `,`
- `INSERT OVERWRITE TABLE ... PARTITION (dt = '${bizdate}')`
- **禁止 `SELECT *`**，必须显式列出所有字段
- SELECT 字段**分层前缀规则**：
  - **最内层从单个真实表 SELECT（无 JOIN）**：不给表加别名，字段直接写列名，无前缀
  - **外层从子查询 `(…) t1` 或有 JOIN 的 SELECT**：子查询必须有别名，字段必须带 `t1.`/`t2.` 前缀
- SELECT 首列与 SELECT 同行，后续列 4 空格 + `, ` 前导
- `AS` 别名**右对齐**到统一列位置，别名后可加 `-- 注释`（`--` 后有空格）
- 多参数函数逗号后加空格：`IF(a, b, c)`、`COALESCE(a, b)`
- 所有 SQL 关键字、内置函数**大写**；表名、列名**小写**
- 表别名使用 `t1, t2, t3...`；缩进单位 **4 空格**，禁用 Tab
- `FROM` / `LEFT JOIN` / `INNER JOIN` 各自独占一行
- 子查询括号 `(` 单独成行，内容缩进 4 空格，`)` 后紧跟别名
- 子查询内首行可加 `-- 查询xxxx` 注释
- `ON` / `AND` 对齐；`WHERE` 首个条件同行，`AND` 与 `WHERE` 对齐
- `CASE WHEN` 与首条件同行，后续 `WHEN`/`ELSE` 对齐，`END` 在末尾分支同行
- 窗口函数整体一行，`OVER(` 紧跟聚合函数
- `GROUP BY` 多列：前导逗号换行缩进；`HAVING` / `ORDER BY` 各占独立一行
- `UNION ALL` 独占一行，前后各留一空行
- `WHERE EXISTS` / `WHERE IN (子查询)` 后换行，`(` 另起一行，内部遵循标准子查询格式
- `LATERAL VIEW EXPLODE(...)` 独占一行紧跟 FROM，多个时纵向对齐
- 语句以独立 `;` 结尾
- **每个 SQL 文件顶部**必须有元数据注释块：脚本名称、功能描述、输入/输出表、作者、修改记录

## 详细规格

Read `references/sql-style-guide.md` for complete rules with ✅/❌ examples and a full reference template.
