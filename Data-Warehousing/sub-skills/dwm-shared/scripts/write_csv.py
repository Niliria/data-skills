#!/usr/bin/env python3
"""
CSV writer for dwm sub-sub-skills outputs (shared tool).

Usage:
    # Write from JSON stdin
    echo '[{"col1":"v1","col2":"v2"}]' | python write_csv.py output/dwm-bus-matrix/dwm_bp_business_process.csv

    # Write from JSON file
    python write_csv.py output/dwm-bus-matrix/dwm_bp_subject_area.csv --input data.json

    # Specify column order (optional, default uses first row's key order)
    python write_csv.py output/dwm-bus-matrix/dwm_dim_spec.csv --columns "维度表名,维度中文名称,来源ODS表"
"""

import csv
import json
import sys
import os
import argparse
from pathlib import Path

BOM = "\ufeff"


def write_csv(filepath: str, rows: list[dict], columns: list[str] | None = None):
    """Write rows to CSV with UTF-8 BOM, auto-create directories."""
    if not rows:
        print(f"Warning: no data to write to {filepath}", file=sys.stderr)
        return

    Path(filepath).parent.mkdir(parents=True, exist_ok=True)

    if columns is None:
        columns = list(rows[0].keys())

    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.write(BOM)
        writer = csv.DictWriter(
            f,
            fieldnames=columns,
            quoting=csv.QUOTE_MINIMAL,
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            cleaned = {k: ("" if v is None else str(v)) for k, v in row.items()}
            writer.writerow(cleaned)

    print(f"Written {len(rows)} rows -> {filepath}")


def main():
    parser = argparse.ArgumentParser(description="Write CSV with UTF-8 BOM")
    parser.add_argument("filepath", help="Output CSV file path")
    parser.add_argument("--input", "-i", help="Input JSON file (default: stdin)")
    parser.add_argument("--columns", "-c", help="Comma-separated column order")
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = json.load(sys.stdin)

    if isinstance(data, dict):
        data = [data]

    columns = args.columns.split(",") if args.columns else None
    write_csv(args.filepath, data, columns)


if __name__ == "__main__":
    main()
