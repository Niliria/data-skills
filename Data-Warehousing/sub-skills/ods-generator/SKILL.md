---
name: ods-generator
description: 从output/metadata_parse这个路径下读取Excel文件读取表结构信息，智能生成数据仓库ODS层的Hive表结构。当用户需要"生成ODS表结构"、"Excel转Hive DDL"、"创建Hive分区表"、"数据仓库表结构设计"、"批量生成Hive建表语句"时立即触发。特别适用于从业务系统元数据Excel生成标准化的ODS层表结构，支持智能数据类型映射、主外键识别、字段规范化等高级功能。

compatibility:
  - python3
  - pandas
  - openpyxl
---

# Hive ODS 表结构生成器

## 功能概述

该技能用于从Excel文件中读取表结构信息，智能生成数据仓库ODS层的表结构，并输出到Excel文件和Hive SQL文件中。

### 核心特性

- **智能数据类型映射**：自动识别并转换常见数据类型（VARCHAR→STRING, INT→INT, DECIMAL→DECIMAL等）
- **字段名规范化**：自动处理特殊字符、空格，确保符合Hive命名规范
- **主外键识别**：自动提取并记录主键、外键信息
- **分区表支持**：自动生成按日期分区的ODS表结构
- **批量处理**：支持一次处理多个表的元数据
- **错误处理**：完善的异常处理和日志记录

## 输入要求

### Excel文件格式

输入Excel文件必须包含以下列：

| 列名           | 必填 | 说明                                                    |
| -------------- | ---- | ------------------------------------------------------- |
| 表名           | 是   | 原始表名                                                |
| 表中文名       | 是   | 表的中文描述                                            |
| 字段名         | 是   | 字段名称                                                |
| 字段注释       | 是   | 字段中文描述                                            |
| 业务系统标识   | 否   | 业务系统简称，缺失时使用'业务数据库名称'列或默认值'mes' |
| 业务数据库名称 | 否   | 当'业务系统标识'缺失时作为备选                          |
| 主键           | 否   | 标记主键字段（值为'YES'或'是'）                         |
| 外键           | 否   | 标记外键字段（值为'YES'或'是'）                         |
| 数据类型       | 否   | 原始数据类型，用于智能映射                              |
| 长度           | 否   | 字段长度信息                                            |

## 输出结果

### 1. Excel文件

包含以下信息：

- 原表名
- 表中文名
- 新表名（格式：`ods_{业务系统}_{原表名}_df`）
- 主键字段列表
- 外键字段列表
- HiveSQL DDL语句

### 2. Hive SQL文件

包含可直接执行的DDL语句，特点：

- 表名格式：`ods_{业务系统}_{原表名}_df`
- 所有字段使用标准化命名
- 自动添加`etl_time`字段记录数据加载时间
- 按`pt`字段分区（STRING类型，格式YYYYMMDD）
- 使用ORC格式存储，提升查询性能
- 包含表和字段的COMMENT注释

## 使用步骤

1. **准备输入文件**：将包含表结构信息的Excel文件放入 `output/metadata_parse/` 目录
2. **调用技能**：skill 会自动从 `output/metadata_parse/` 读取输入文件，并将结果输出到 `output/ods_generator/` 目录
3. **查看结果**：检查 `output/ods_generator/` 目录下生成的 Excel 和 SQL 文件

## 实现脚本

### 主脚本：generate_ods.py

```python
import pandas as pd
import os
import logging
import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 数据类型映射表
DATA_TYPE_MAPPING = {
    # 字符串类型
    'varchar': 'STRING',
    'varchar2': 'STRING',
    'char': 'STRING',
    'nvarchar': 'STRING',
    'nvarchar2': 'STRING',
    'text': 'STRING',
    'clob': 'STRING',
    'string': 'STRING',
    # 数值类型
    'int': 'INT',
    'integer': 'INT',
    'bigint': 'BIGINT',
    'smallint': 'SMALLINT',
    'tinyint': 'TINYINT',
    'number': 'BIGINT',
    'numeric': 'DECIMAL',
    'decimal': 'DECIMAL',
    'float': 'FLOAT',
    'double': 'DOUBLE',
    'real': 'DOUBLE',
    # 日期时间类型
    'date': 'STRING',
    'datetime': 'STRING',
    'timestamp': 'STRING',
    'time': 'STRING',
    # 二进制类型
    'blob': 'STRING',
    'binary': 'STRING',
    'varbinary': 'STRING',
}

def map_data_type(original_type: str, length: Optional[str] = None) -> str:
    """
    将原始数据类型映射为Hive数据类型

    Args:
        original_type: 原始数据类型
        length: 字段长度信息

    Returns:
        映射后的Hive数据类型
    """
    if pd.isna(original_type) or not original_type:
        return 'STRING'

    # 标准化类型名
    type_lower = str(original_type).lower().strip()

    # 提取基础类型（去除长度信息）
    base_type = re.split(r'[\(\s]', type_lower)[0]

    # 查找映射
    hive_type = DATA_TYPE_MAPPING.get(base_type, 'STRING')

    # 对于DECIMAL类型，保留精度信息
    if hive_type == 'DECIMAL' and length:
        return f'DECIMAL({length})'

    return hive_type

def normalize_identifier(name: str, is_table: bool = False) -> str:
    """
    标准化标识符（表名或字段名）

    Args:
        name: 原始名称
        is_table: 是否为表名

    Returns:
        标准化后的名称
    """
    if pd.isna(name) or not name:
        return '_unknown'

    name = str(name).strip()

    # 替换特殊字符为下划线
    name = re.sub(r'[^a-zA-Z0-9_\u4e00-\u9fff]', '_', name)

    # 移除连续的下划线
    name = re.sub(r'_+', '_', name)

    # 移除首尾下划线
    name = name.strip('_')

    # 确保以字母或下划线开头
    if name and not (name[0].isalpha() or name[0] == '_'):
        name = '_' + name

    # 转换为小写（表名规范）
    if is_table:
        name = name.lower()

    # 如果为空，返回默认值
    if not name:
        return '_unknown'

    return name

def escape_comment(comment: str) -> str:
    """
    转义注释中的特殊字符

    Args:
        comment: 原始注释

    Returns:
        转义后的注释
    """
    if pd.isna(comment) or not comment:
        return ''

    comment = str(comment)

    # 转义单引号
    comment = comment.replace("'", "\\'")

    # 移除换行符
    comment = comment.replace('\n', ' ').replace('\r', ' ')

    # 去除多余空格
    comment = ' '.join(comment.split())

    return comment.strip()

def generate_ods_from_excel(
    input_file: str,
    output_excel: str,
    output_sql: str,
    default_system: str = 'mes'
) -> Tuple[str, str]:
    """
    从Excel文件生成ODS层表结构

    Args:
        input_file: 输入Excel文件路径
        output_excel: 输出Excel文件路径
        output_sql: 输出SQL文件路径
        default_system: 默认业务系统标识

    Returns:
        (输出Excel路径, 输出SQL路径)
    """
    logger.info(f"开始处理: {input_file}")

    # 验证输入文件
    input_path = Path(input_file)
    if not input_path.exists():
        raise FileNotFoundError(f"输入文件不存在: {input_file}")

    # 确保输出目录存在
    Path(output_excel).parent.mkdir(parents=True, exist_ok=True)
    Path(output_sql).parent.mkdir(parents=True, exist_ok=True)

    # 读取Excel
    logger.info("读取Excel文件...")
    try:
        df = pd.read_excel(input_file)
    except Exception as e:
        raise ValueError(f"读取Excel文件失败: {e}")

    if df.empty:
        raise ValueError("Excel文件为空")

    logger.info(f"读取到 {len(df)} 行数据")

    # 检查必要列
    required_cols = ['表名', '表中文名', '字段名', '字段注释']
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        raise ValueError(f"缺少必要列: {', '.join(missing_cols)}")

    # 确定业务系统标识列
    system_col = _get_system_column(df, default_system)

    # 按表分组处理
    grouped = df.groupby('表名', sort=False)
    logger.info(f"发现 {len(grouped)} 个表")

    output_data = []
    ddl_statements = []

    for table_name, group in grouped:
        try:
            result = _process_single_table(
                table_name, group, system_col, default_system
            )
            output_data.append(result['metadata'])
            ddl_statements.append(result['ddl'])
            logger.info(f"✓ 处理完成: {table_name} -> {result['metadata']['新表名']}")
        except Exception as e:
            logger.error(f"✗ 处理表 {table_name} 失败: {e}")
            continue

    if not output_data:
        raise ValueError("没有成功处理任何表")

    # 生成输出文件
    _generate_output_files(output_data, ddl_statements, output_excel, output_sql)

    logger.info(f"全部完成！成功处理 {len(output_data)} 个表")
    return output_excel, output_sql

def _get_system_column(df: pd.DataFrame, default_system: str) -> str:
    """确定业务系统标识列"""
    if '业务系统标识' in df.columns:
        return '业务系统标识'
    elif '业务数据库名称' in df.columns:
        logger.info("使用'业务数据库名称'作为业务系统标识")
        return '业务数据库名称'
    else:
        logger.warning(f"使用默认业务系统标识: {default_system}")
        df['业务系统标识'] = default_system
        return '业务系统标识'

def _process_single_table(
    table_name: str,
    group: pd.DataFrame,
    system_col: str,
    default_system: str
) -> Dict:
    """处理单个表"""
    # 获取业务系统标识
    business_system = group[system_col].iloc[0]
    if pd.isna(business_system) or not str(business_system).strip():
        business_system = default_system

    business_system = normalize_identifier(str(business_system), is_table=True)
    normalized_table = normalize_identifier(str(table_name), is_table=True)

    # 生成新表名
    new_table_name = f"ods_{business_system}_{normalized_table}_df"

    # 获取表中文名
    table_name_cn = group['表中文名'].iloc[0]
    if pd.isna(table_name_cn):
        table_name_cn = table_name

    # 提取主键和外键
    primary_keys = _extract_keys(group, '主键')
    foreign_keys = _extract_keys(group, '外键')

    # 生成DDL
    ddl = _generate_ddl(new_table_name, table_name_cn, group)

    return {
        'metadata': {
            '原表名': table_name,
            '表中文名': table_name_cn,
            '新表名': new_table_name,
            '主键': ', '.join(primary_keys) if primary_keys else '',
            '外键': ', '.join(foreign_keys) if foreign_keys else '',
            'HiveSQL DDL语句': ddl
        },
        'ddl': ddl
    }

def _extract_keys(group: pd.DataFrame, key_column: str) -> List[str]:
    """提取主键或外键字段"""
    keys = []
    if key_column in group.columns:
        for _, row in group.iterrows():
            key_value = str(row.get(key_column, '')).strip().upper()
            if key_value in ('YES', '是', 'Y', 'TRUE', '1'):
                field_name = normalize_identifier(row['字段名'])
                keys.append(field_name)
    return keys

def _generate_ddl(table_name: str, table_name_cn: str, group: pd.DataFrame) -> str:
    """生成Hive DDL语句"""
    columns = []

    for _, row in group.iterrows():
        field_name = normalize_identifier(row['字段名'])
        comment = escape_comment(row['字段注释'])

        # 数据类型映射
        original_type = row.get('数据类型', '')
        length = row.get('长度', '')
        hive_type = map_data_type(original_type, length)

        columns.append(f"  `{field_name}` {hive_type} COMMENT '{comment}'")

    # 添加etl_time字段
    columns.append("  `etl_time` STRING COMMENT 'ETL加载时间'")

    # 构建DDL
    table_comment = escape_comment(table_name_cn)
    ddl = f"CREATE TABLE IF NOT EXISTS {table_name} (\n"
    ddl += ',\n'.join(columns)
    ddl += f"\n) COMMENT '{table_comment}'\n"
    ddl += "PARTITIONED BY (pt STRING COMMENT '分区日期')\n"
    ddl += "ROW FORMAT DELIMITED FIELDS TERMINATED BY '\\t'\n"
    ddl += "STORED AS ORC;"

    return ddl

def _generate_output_files(
    output_data: List[Dict],
    ddl_statements: List[str],
    output_excel: str,
    output_sql: str
):
    """生成输出文件"""
    # 生成Excel
    logger.info(f"生成Excel文件: {output_excel}")
    output_df = pd.DataFrame(output_data)
    output_df.to_excel(output_excel, index=False, engine='openpyxl')

    # 生成SQL文件
    logger.info(f"生成SQL文件: {output_sql}")
    with open(output_sql, 'w', encoding='utf-8') as f:
        f.write("-- Hive ODS层表结构定义\n")
        f.write(f"-- 生成时间: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"-- 共 {len(ddl_statements)} 个表\n\n")
        f.write('\n\n'.join(ddl_statements))

def find_input_file(input_dir: str = 'output/metadata_parse') -> str:
    """
    在指定目录下查找Excel输入文件

    Args:
        input_dir: 输入目录路径

    Returns:
        找到的Excel文件路径

    Raises:
        FileNotFoundError: 如果没有找到Excel文件
    """
    input_path = Path(input_dir)

    if not input_path.exists():
        raise FileNotFoundError(f"输入目录不存在: {input_dir}")

    # 查找Excel文件 (.xlsx, .xls)
    excel_files = list(input_path.glob('*.xlsx')) + list(input_path.glob('*.xls'))

    if not excel_files:
        raise FileNotFoundError(f"在 {input_dir} 目录下未找到Excel文件(.xlsx或.xls)")

    # 如果找到多个，按修改时间排序选择最新的
    excel_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    selected_file = excel_files[0]

    logger.info(f"找到输入文件: {selected_file}")
    if len(excel_files) > 1:
        logger.info(f"(该目录下共有 {len(excel_files)} 个Excel文件，使用最新的: {selected_file.name})")

    return str(selected_file)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='从Excel生成Hive ODS表结构')
    parser.add_argument('--input-file', default=None,
                        help='输入Excel文件路径（默认: 自动从 output/metadata_parse/ 查找）')
    parser.add_argument('--output-dir', default='output/ods_generator',
                        help='输出目录路径（默认: output/ods_generator）')
    parser.add_argument('--default-system', default='mes',
                        help='默认业务系统标识（默认: mes）')

    args = parser.parse_args()

    try:
        # 确定输入文件
        if args.input_file:
            input_file = args.input_file
        else:
            input_file = find_input_file('output/metadata_parse')

        # 确定输出文件路径
        output_dir = Path(args.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        # 使用输入文件名作为输出文件名基础
        input_name = Path(input_file).stem
        output_excel = str(output_dir / f"{input_name}_ods.xlsx")
        output_sql = str(output_dir / f"{input_name}_ods.sql")

        # 生成ODS表结构
        output_excel, output_sql = generate_ods_from_excel(
            input_file,
            output_excel,
            output_sql,
            args.default_system
        )
        print(f"\n✓ 生成完成！")
        print(f"  Excel文件: {output_excel}")
        print(f"  SQL文件: {output_sql}")
    except Exception as e:
        logger.error(f"生成失败: {e}")
        raise
```

## 使用示例

### 示例1：基本用法

**输入**：

```
请生成ODS层表结构
```

**处理流程**：
- 自动从 `output/metadata_parse/` 目录读取 Excel 文件
- 自动生成结果到 `output/ods_generator/` 目录

**输出**：

```
✓ 生成完成！
  Excel文件: output/ods_generator/ods_tables.xlsx
  SQL文件: output/ods_generator/ods_tables.sql
```

### 示例2：指定默认业务系统

**输入**：

```
从Excel生成ODS表结构，使用'crm'作为默认业务系统
```

**说明**：
- 从 `output/metadata_parse/` 读取 crm_tables.xlsx
- 输出到 `output/ods_generator/` 目录

### 示例3：处理包含数据类型的元数据

**输入**：

```
请根据包含数据类型的Excel生成Hive ODS表结构
```

**说明**：
- 从 `output/metadata_parse/` 读取包含'数据类型'和'长度'列的 detailed_metadata.xlsx
- 输出到 `output/ods_generator/` 目录

## 生成的DDL示例

```sql
CREATE TABLE IF NOT EXISTS ods_mes_user_info_df (
  `user_id` BIGINT COMMENT '用户ID',
  `user_name` STRING COMMENT '用户名称',
  `email` STRING COMMENT '邮箱地址',
  `create_time` STRING COMMENT '创建时间',
  `etl_time` STRING COMMENT 'ETL加载时间'
) COMMENT '用户信息表'
PARTITIONED BY (pt STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS ORC;
```

## 注意事项

1. **输入文件要求**：
   - 必须包含：表名、表中文名、字段名、字段注释
   - 建议包含：业务系统标识、数据类型、长度

2. **数据类型映射规则**：
   - VARCHAR/VARCHAR2/CHAR → STRING
   - INT/INTEGER/BIGINT → INT/BIGINT
   - DECIMAL/NUMERIC → DECIMAL(保留精度)
   - DATE/DATETIME/TIMESTAMP → STRING
   - 未识别类型 → STRING

3. **命名规范**：
   - 新表名格式：`ods_{业务系统}_{原表名}_df`
   - 所有标识符自动转为小写
   - 特殊字符替换为下划线

4. **错误处理**：
   - 输入文件不存在时会抛出FileNotFoundError
   - 缺少必要列时会抛出ValueError
   - 单个表处理失败会记录错误但继续处理其他表

5. **性能建议**：
   - 建议单次处理不超过1000个表
   - 大型Excel文件（>10万行）建议分批处理
