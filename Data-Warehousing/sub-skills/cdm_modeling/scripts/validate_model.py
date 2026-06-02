#!/usr/bin/env python3
"""
validate_model.py - CDM 生成产物校验工具
========================================
检查 output/cdm-modeling 下的 SQL 和 docs 产物是否满足基本门禁。
"""

import argparse
import csv
import sys
from pathlib import Path
from typing import List, Dict


REQUIRED_DOCS = [
    "dim_list.csv",
    "dwd_list.csv",
    "field_mapping.csv",
    "dependency.csv",
    "model_design.md",
    "validation_report.md",
]


def read_csv(path: Path) -> List[Dict[str, str]]:
    if not path.exists():
        return []
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def read_field_catalog(path: Path) -> List[Dict[str, object]]:
    if not path.exists():
        return []

    text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    sections = [section for section in text.split("\n\n") if section.strip()]
    models: List[Dict[str, object]] = []

    for section in sections:
        rows = list(csv.reader(section.strip().splitlines()))
        if not rows or len(rows[0]) < 2 or rows[0][0].strip() != "模型名":
            continue

        meta: Dict[str, str] = {"模型名": rows[0][1].strip()}
        fields: List[Dict[str, str]] = []
        header: List[str] | None = None

        for row in rows[1:]:
            if not row or not any(cell.strip() for cell in row):
                continue
            key = row[0].strip()
            if key == "字段":
                header = [cell.strip() for cell in row]
                continue
            if header is None:
                if len(row) >= 2 and key:
                    meta[key] = row[1].strip()
                continue
            padded = [cell.strip() for cell in row] + [""] * max(0, len(header) - len(row))
            field = {header[i]: padded[i] for i in range(len(header))}
            if field.get("字段名"):
                fields.append(field)

        models.append({"meta": meta, "fields": fields})

    return models


def validate_output_dir(output_dir: Path) -> tuple[List[str], List[str]]:
    errors: List[str] = []
    warnings: List[str] = []

    docs_dir = output_dir / "docs"
    ddl_dir = output_dir / "ddl"
    etl_dir = output_dir / "etl"

    for directory in [docs_dir, ddl_dir, etl_dir]:
        if not directory.exists():
            errors.append(f"missing directory: {directory}")

    for filename in REQUIRED_DOCS:
        path = docs_dir / filename
        if not path.exists():
            errors.append(f"missing docs file: {path}")

    dim_models = read_field_catalog(docs_dir / "dim_list.csv")
    dwd_models = read_field_catalog(docs_dir / "dwd_list.csv")
    field_rows = read_csv(docs_dir / "field_mapping.csv")
    dependency_rows = read_csv(docs_dir / "dependency.csv")

    if not dim_models:
        errors.append("dim_list.csv has no field-level model sections")
    if not dwd_models:
        warnings.append("dwd_list.csv has no field-level model sections")
    if not field_rows:
        warnings.append("field_mapping.csv has no rows")
    if not dependency_rows:
        warnings.append("dependency.csv has no rows")

    dim_tables = {str(model["meta"].get("模型名", "")) for model in dim_models}
    for model in dwd_models:
        meta = model["meta"]
        fields = model["fields"]
        table_name = str(meta.get("模型名", ""))
        dimension_fields = [field for field in fields if field.get("维度", "").strip().upper() == "Y"]
        measure_fields = [field for field in fields if field.get("度量", "").strip().upper() == "Y"]

        for field in dimension_fields:
            field_name = field.get("字段名", "")
            if field_name.endswith("_sk"):
                dim_table = f"dim_{field_name[:-3]}"
                if dim_table not in dim_tables:
                    errors.append(f"DWD {table_name} references missing DIM: {dim_table}")
        if meta.get("事实类型") != "factless" and not measure_fields:
            errors.append(f"DWD {table_name} has no measure fields")
        if not meta.get("粒度"):
            errors.append(f"DWD {table_name} has no grain")

    sql_files = list((ddl_dir).glob("**/*.sql")) + list((etl_dir).glob("**/*.sql"))
    if not sql_files:
        errors.append("no SQL files generated under ddl/ or etl/")

    for sql_file in sql_files:
        text = sql_file.read_text(encoding="utf-8")
        if "{{" in text or "}}" in text:
            errors.append(f"unrendered template placeholder in {sql_file}")

    return errors, warnings


def write_report(report_file: Path, errors: List[str], warnings: List[str]) -> None:
    status = "FAIL" if errors else ("WARN" if warnings else "PASS")
    lines = ["# Validation Report", "", f"Status: {status}", ""]
    if errors:
        lines.extend(["## Errors", ""])
        lines.extend(f"- {error}" for error in errors)
        lines.append("")
    if warnings:
        lines.extend(["## Warnings", ""])
        lines.extend(f"- {warning}" for warning in warnings)
        lines.append("")
    if not errors and not warnings:
        lines.append("No validation issues.")
    report_file.parent.mkdir(parents=True, exist_ok=True)
    report_file.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate generated CDM artifacts.")
    parser.add_argument("output_dir", help="Path to output/cdm-modeling")
    parser.add_argument("--write-report", action="store_true", help="Rewrite docs/validation_report.md")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    errors, warnings = validate_output_dir(output_dir)
    if args.write_report:
        write_report(output_dir / "docs" / "validation_report.md", errors, warnings)

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    for warning in warnings:
        print(f"WARN: {warning}", file=sys.stderr)

    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
