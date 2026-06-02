"""
generate_etl.py - ETL脚本生成模块
========================================
根据 DIM/DWD 设计生成对应的 ETL 加载脚本。
"""

from pathlib import Path
from typing import Dict

from jinja2 import Environment, FileSystemLoader, TemplateNotFound


class ETLScriptGenerator:
    """ETL脚本生成器。"""

    def __init__(self, dim_designs: Dict, dwd_designs: Dict, rules_dir: Path, templates_dir: Path, output_dir: Path, logger=None):
        self.dim_designs = dim_designs
        self.dwd_designs = dwd_designs
        self.rules_dir = Path(rules_dir)
        self.templates_dir = Path(templates_dir)
        self.output_dir = Path(output_dir)
        self.logger = logger

    def generate(self) -> None:
        self._generate_dim_etl()
        self._generate_dwd_etl()

    def _generate_dim_etl(self) -> None:
        output_dir = self.output_dir / "etl" / "dim"
        output_dir.mkdir(parents=True, exist_ok=True)
        env = Environment(loader=FileSystemLoader(str(self.templates_dir)))

        try:
            template = env.get_template("dim_etl.tpl")
        except TemplateNotFound:
            if self.logger:
                self.logger.warning("Template file not found: dim_etl.tpl")
            return

        for table_name, dim_info in self.dim_designs.items():
            source_table = dim_info.get("source_tables", [""])[0] if dim_info.get("source_tables") else f"dws_dim_{dim_info['entity']}_di"
            context = {
                "table_name": table_name,
                "entity": dim_info["entity"],
                "business_key": dim_info["business_key"],
                "scd_type": dim_info["scd_type"],
                "fields": dim_info.get("attributes", []),
                "scd_tracking_fields": dim_info.get("scd_tracking_fields", []),
                "source_table": source_table,
            }
            sql = template.render(context)
            output_file = output_dir / f"load_{table_name}.sql"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(sql)
            if self.logger:
                self.logger.success(f"  {output_file.name}")

    def _generate_dwd_etl(self) -> None:
        output_dir = self.output_dir / "etl" / "dwd"
        output_dir.mkdir(parents=True, exist_ok=True)
        env = Environment(loader=FileSystemLoader(str(self.templates_dir)))

        try:
            template = env.get_template("dwd_etl.tpl")
        except TemplateNotFound:
            if self.logger:
                self.logger.warning("Template file not found: dwd_etl.tpl")
            return

        for table_name, dwd_info in self.dwd_designs.items():
            source_table = dwd_info.get("source_tables", [""])[0] if dwd_info.get("source_tables") else f"dws_{dwd_info['domain']}_{dwd_info['business_process']}_di"
            context = {
                "table_name": table_name,
                "entity": dwd_info["business_process"],
                "business_key": dwd_info["business_key"],
                "domain": dwd_info["domain"],
                "source_table": source_table,
                "dimensions": dwd_info.get("dimension_refs", [{"entity": dim, "business_key": f"{dim}_id"} for dim in dwd_info.get("dimensions", [])]),
                "measures": dwd_info.get("measures", []),
                "table_comment": f"事实表: {dwd_info['domain']}-{dwd_info['business_process']}",
            }
            sql = template.render(context)
            output_file = output_dir / f"load_{table_name}.sql"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(sql)
            if self.logger:
                self.logger.success(f"  {output_file.name}")
