"""
parse_upstream_outputs.py - 上游 DWM 建设规格解析模块
====================================================
读取 DWM DIM/DWD 建设规格 CSV/XLSX，合并为 CDM 生成所需的统一上下文。
"""

import csv
import re
from pathlib import Path
from typing import Any, Dict, List


class UpstreamOutputParser:
    """解析 DWM DIM/DWD 建设规格 CSV/XLSX。"""

    def __init__(
        self,
        dim_spec_file: str = "",
        dwd_fact_spec_file: str = "",
        base_dir: Path = Path(""),
        logger=None,
    ):
        self.base_dir = Path(base_dir)
        self.dim_spec_file = self._resolve_path(dim_spec_file) if dim_spec_file else None
        self.dwd_fact_spec_file = self._resolve_path(dwd_fact_spec_file) if dwd_fact_spec_file else None
        self.logger = logger
        self.warnings: List[str] = []

    def parse(self) -> Dict[str, Any]:
        if not self.dim_spec_file or not self.dwd_fact_spec_file:
            self._warn("DWM spec 输入不完整，需要同时提供 dim_spec_file 和 dwd_fact_spec_file")
            dim_rows: List[Dict[str, str]] = []
            dwd_rows: List[Dict[str, str]] = []
        else:
            dim_rows = self._load_table(self.dim_spec_file)
            dwd_rows = self._load_table(self.dwd_fact_spec_file)

        model = {
            "processes": self._extract_processes_from_dwd_spec(dwd_rows),
            "dimensions": self._extract_dimensions_from_dim_spec(dim_rows),
            "ods_tables": self._extract_lineage_tables(dim_rows, dwd_rows),
            "warnings": self.warnings,
        }
        self._validate(model)
        return model

    def _resolve_path(self, raw_path: str) -> Path:
        path = Path(raw_path)
        if path.is_absolute():
            return path
        return self.base_dir / path

    def _load_table(self, path: Path) -> List[Dict[str, str]]:
        if not path.exists():
            self._warn(f"输入文件不存在: {path}")
            return []

        suffix = path.suffix.lower()
        if suffix == ".csv":
            return self._load_csv(path)
        if suffix == ".xlsx":
            return self._load_xlsx(path)

        self._warn(f"不支持的输入格式: {path}，仅支持 .csv 和 .xlsx")
        return []

    def _load_csv(self, path: Path) -> List[Dict[str, str]]:
        with open(path, "r", encoding="utf-8-sig", newline="") as f:
            return [self._clean_row(row) for row in csv.DictReader(f)]

    def _load_xlsx(self, path: Path) -> List[Dict[str, str]]:
        try:
            from openpyxl import load_workbook
        except ImportError:
            self._warn("读取 XLSX 需要安装 openpyxl")
            return []

        workbook = load_workbook(path, read_only=True, data_only=True)
        sheet = workbook.active
        rows = sheet.iter_rows(values_only=True)
        try:
            headers = [self._stringify(value) for value in next(rows)]
        except StopIteration:
            return []

        result: List[Dict[str, str]] = []
        for values in rows:
            if not any(value is not None and str(value).strip() for value in values):
                continue
            row = {
                headers[idx]: self._stringify(value)
                for idx, value in enumerate(values)
                if idx < len(headers) and headers[idx]
            }
            result.append(self._clean_row(row))
        return result

    def _extract_dimensions_from_dim_spec(self, rows: List[Dict[str, str]]) -> List[Dict[str, Any]]:
        grouped: Dict[str, List[Dict[str, str]]] = {}
        for row in rows:
            table_name = self._pick(row, ["DIM表名", "dim_table_name"]).strip()
            if table_name:
                grouped.setdefault(table_name, []).append(row)

        dimensions: List[Dict[str, Any]] = []
        for table_name, table_rows in grouped.items():
            entity = self._entity_from_dim_table(table_name)
            display_name = self._pick(table_rows[0], ["维度中文名", "dimension_name"]) or table_name
            business_key = ""
            attributes: List[Dict[str, Any]] = []
            scd_types: List[int] = []

            for row in sorted(table_rows, key=self._sort_order):
                field_name = self._pick(row, ["DIM字段名", "dim_column_name"]).strip()
                if not field_name:
                    continue
                role = self._pick(row, ["字段角色", "column_role"]).strip().lower()
                scd_types.append(self._parse_scd_type(self._pick(row, ["SCD类型", "scd_type"])))
                if role in {"bk", "business_key", "pk"}:
                    business_key = business_key or field_name
                    continue
                if role == "attribute":
                    attributes.append({
                        "name": field_name,
                        "source_field": self._pick(row, ["来源ODS字段", "ods_column_name"]) or field_name,
                        "type": self._normalize_data_type(self._pick(row, ["ODS字段数据类型", "ods_data_type"])),
                        "description": self._pick(row, ["字段中文说明", "dim_column_comment"]) or field_name,
                        "scd_type": self._parse_scd_type(self._pick(row, ["SCD类型", "scd_type"])),
                    })

            if not business_key:
                business_key = f"{entity}_id"
                self._warn(f"DIM {table_name} 未找到 bk 字段，使用默认业务键: {business_key}")

            dimensions.append({
                "table_name": table_name,
                "name": display_name,
                "entity": entity,
                "business_key": business_key,
                "attributes": self._dedupe_fields(attributes),
                "source_tables": self._unique_values(table_rows, ["来源ODS表", "ods_table_name"]),
                "scd_type": max(scd_types) if scd_types else 1,
            })
        return dimensions

    def _extract_processes_from_dwd_spec(self, rows: List[Dict[str, str]]) -> List[Dict[str, Any]]:
        grouped: Dict[str, List[Dict[str, str]]] = {}
        for row in rows:
            table_name = self._pick(row, ["DWD表名", "dwd_table_name"]).strip()
            if table_name:
                grouped.setdefault(table_name, []).append(row)

        processes: List[Dict[str, Any]] = []
        for table_name, table_rows in grouped.items():
            first = table_rows[0]
            dimensions: List[str] = []
            dimension_refs: List[Dict[str, str]] = []
            measures: List[Dict[str, Any]] = []
            grain_key = ""

            for row in sorted(table_rows, key=self._sort_order):
                role = self._pick(row, ["字段角色", "column_role"]).strip().lower()
                field_name = self._pick(row, ["DWD字段名", "dwd_column_name"]).strip()
                source_field = self._pick(row, ["来源ODS字段", "ods_column_name"]) or field_name
                dim_table = self._pick(row, ["关联DIM表", "ref_dim_table"]).strip()
                if role == "grain_key" and field_name:
                    grain_key = grain_key or field_name
                if dim_table:
                    entity = self._entity_from_dim_table(dim_table)
                    if entity not in dimensions:
                        dimensions.append(entity)
                    dim_business_key = (
                        self._pick(row, ["关联DIM业务键", "ref_dim_business_key", "dim_business_key"])
                        or field_name
                        or source_field
                        or f"{entity}_id"
                    )
                    dimension_refs.append({
                        "entity": entity,
                        "table_name": dim_table,
                        "source_field": source_field,
                        "business_key": dim_business_key,
                        "target_field": field_name or source_field,
                    })
                elif role == "measure":
                    measures.append({
                        "name": field_name,
                        "source_field": source_field,
                        "type": self._normalize_data_type(
                            self._pick(row, ["ODS字段数据类型", "ods_data_type"]),
                            default_type="DECIMAL(18,2)",
                        ),
                        "description": self._pick(row, ["字段中文说明", "dwd_column_comment"]) or field_name,
                        "aggregation": (self._pick(row, ["聚合建议", "agg_suggest"]) or "SUM").upper(),
                        "unit": self._pick(row, ["度量单位", "unit"]),
                        "is_derived": self._pick(row, ["是否派生", "is_derived"]),
                        "derived_logic": self._pick(row, ["派生逻辑", "derived_logic"]),
                    })

            processes.append({
                "table_name": table_name,
                "domain": self._pick(first, ["主题域编码", "subject_area_code"]),
                "business_process": self._pick(first, ["业务过程标准名", "bp_standard_name"]),
                "grain": self._pick(first, ["粒度声明", "grain_statement"]),
                "business_key": grain_key,
                "fact_type": self._pick(first, ["事实表类型", "fact_type"]) or "transaction",
                "dimensions": dimensions,
                "dimensions_authoritative": True,
                "dimension_refs": dimension_refs,
                "measures": measures,
                "source_tables": self._unique_values(table_rows, ["来源ODS表", "ods_table_name"]),
            })
        return processes

    def _extract_lineage_tables(self, *row_groups: List[Dict[str, str]]) -> Dict[str, Dict[str, Any]]:
        tables: Dict[str, Dict[str, Any]] = {}
        for rows in row_groups:
            for row in rows:
                table_name = self._pick(row, ["来源ODS表", "ods_table_name"]).strip()
                field_name = self._pick(row, ["来源ODS字段", "ods_column_name"]).strip()
                if not table_name or not field_name:
                    continue
                tables.setdefault(table_name, {"table_name": table_name, "domain": "", "description": "", "fields": []})
                tables[table_name]["fields"].append(self._normalize_field({
                    "name": field_name,
                    "type": self._normalize_data_type(self._pick(row, ["ODS字段数据类型", "ods_data_type"])),
                    "description": self._pick(row, ["字段中文说明", "dwd_column_comment", "dim_column_comment"]),
                    "classification": self._pick(row, ["字段角色", "column_role"]),
                }))
        for table in tables.values():
            table["fields"] = self._dedupe_fields(table["fields"])
        return tables

    def _normalize_field(self, field: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "name": field.get("name") or field.get("field_name") or "",
            "type": field.get("type") or field.get("字段类型") or "STRING",
            "description": field.get("description") or field.get("comment") or field.get("字段说明") or "",
            "classification": field.get("classification") or field.get("字段分类") or "",
            "dimension": field.get("dimension") or field.get("维度") or "",
        }

    def _validate(self, model: Dict[str, Any]) -> None:
        if not model["processes"]:
            self._warn("未解析到任何业务过程")
        for process in model["processes"]:
            name = process.get("business_process") or "<unknown>"
            if not process.get("grain"):
                self._warn(f"业务过程缺少粒度: {name}")
            if not process.get("dimensions"):
                self._warn(f"业务过程缺少维度: {name}")
            if process.get("fact_type") != "factless" and not process.get("measures"):
                self._warn(f"业务过程缺少度量: {name}")
        for dim in model["dimensions"]:
            if not dim.get("business_key"):
                self._warn(f"维度缺少业务键: {dim.get('name')}")

    def _entity_from_dim_table(self, table_name: str) -> str:
        raw = str(table_name).strip()
        if raw.startswith("dim_"):
            return raw[4:]
        return self._normalize_name(raw)

    def _parse_scd_type(self, value: str) -> int:
        text = str(value or "").strip().upper()
        if text in {"SCD3", "3"}:
            return 3
        if text in {"SCD2", "2"}:
            return 2
        return 1

    def _normalize_data_type(self, value: str, default_type: str = "STRING") -> str:
        raw = str(value or "").strip()
        if not raw:
            return default_type
        text = raw.lower()
        base = re.split(r"[\(\s]", text, maxsplit=1)[0]
        precision_match = re.search(r"\(([^)]+)\)", raw)

        if base in {"varchar", "varchar2", "char", "nvarchar", "nvarchar2", "text", "clob"}:
            return "STRING"
        if base in {"datetime", "timestamp", "date", "time"}:
            return "STRING"
        if base == "bigint":
            return "BIGINT"
        if base in {"int", "integer"}:
            return "INT"
        if base == "smallint":
            return "SMALLINT"
        if base == "tinyint":
            return "TINYINT"
        if base in {"decimal", "numeric", "number"}:
            return f"DECIMAL({precision_match.group(1)})" if precision_match else "DECIMAL(18,2)"
        if base in {"double", "float"}:
            return base.upper()
        if base == "string":
            return "STRING"
        return raw.upper()

    def _sort_order(self, row: Dict[str, str]) -> int:
        value = self._pick(row, ["字段排序", "sort_order"])
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return 0

    def _unique_values(self, rows: List[Dict[str, str]], keys: List[str]) -> List[str]:
        values: List[str] = []
        seen = set()
        for row in rows:
            value = self._pick(row, keys).strip()
            if value and value not in seen:
                seen.add(value)
                values.append(value)
        return values

    def _normalize_name(self, name: str) -> str:
        name_map = {
            "销售": "sales",
            "库存": "inventory",
            "客户": "customer",
            "商品": "product",
            "店铺": "shop",
            "门店": "shop",
            "日期": "date",
            "时间": "time",
            "地区": "region",
            "供应商": "supplier",
        }
        raw = str(name).strip()
        return name_map.get(raw, re.sub(r"[^a-zA-Z0-9_]+", "_", raw.lower()).strip("_"))

    def _dedupe_fields(self, fields: List[Dict[str, str]]) -> List[Dict[str, str]]:
        seen = set()
        result = []
        for field in fields:
            if field["name"] in seen:
                continue
            seen.add(field["name"])
            result.append(field)
        return result

    def _pick(self, row: Dict[str, str], keys: List[str]) -> str:
        for key in keys:
            if key in row and row[key]:
                return row[key]
        return ""

    def _clean_row(self, row: Dict[str, Any]) -> Dict[str, str]:
        return {self._stringify(key): self._stringify(value) for key, value in row.items() if key}

    def _stringify(self, value: Any) -> str:
        if value is None:
            return ""
        return str(value).strip()

    def _warn(self, message: str) -> None:
        self.warnings.append(message)
        if self.logger:
            self.logger.warning(message)
