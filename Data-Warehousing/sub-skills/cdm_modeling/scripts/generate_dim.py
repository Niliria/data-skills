"""
generate_dim.py - DIM维度表生成模块
========================================
根据上游解析结果生成 DIM 维度表设计和 DDL。
"""

from pathlib import Path
from typing import Dict, Any

from jinja2 import Environment, FileSystemLoader, TemplateNotFound


class DimensionGenerator:
    """维度表生成器。"""

    def __init__(
        self,
        upstream_model: Dict[str, Any],
        modeling_config: Dict[str, Any],
        rules_dir: Path,
        templates_dir: Path,
        output_dir: Path = None,
        logger=None,
    ):
        self.upstream_model = upstream_model
        self.modeling_config = modeling_config
        self.rules_dir = Path(rules_dir)
        self.templates_dir = Path(templates_dir)
        self.output_dir = Path(output_dir) if output_dir else None
        self.logger = logger

    def generate(self) -> Dict[str, Dict]:
        dim_designs: Dict[str, Dict] = {}
        for dim in self.upstream_model.get("dimensions", []):
            entity = dim["entity"]
            table_name = dim.get("table_name") or f"dim_{entity}"
            scd_type = int(dim.get("scd_type") or self.modeling_config.get("default_scd_type", 1))
            attributes = dim.get("attributes", [])

            dim_designs[table_name] = {
                "table_name": table_name,
                "entity": entity,
                "display_name": dim.get("name", entity),
                "scd_type": scd_type,
                "business_key": dim.get("business_key") or f"{entity}_id",
                "attributes": attributes,
                "scd_tracking_fields": [attr for attr in attributes if int(attr.get("scd_type") or 1) == 2],
                "scd_fields": ["begin_date", "end_date", "is_active"] if scd_type == 2 else [],
                "source_tables": dim.get("source_tables", []),
                "estimated_size": dim.get("estimated_size", "small"),
            }
            if self.logger:
                self.logger.success(f"  {table_name} (SCD Type {scd_type}, attrs={len(attributes)})")

        if self.output_dir:
            self._generate_ddl(dim_designs)
        return dim_designs

    def _generate_ddl(self, dim_designs: Dict[str, Dict]) -> None:
        output_dir = self.output_dir / "ddl" / "dim"
        output_dir.mkdir(parents=True, exist_ok=True)
        env = Environment(loader=FileSystemLoader(str(self.templates_dir)))

        try:
            template = env.get_template("dim_ddl.tpl")
        except TemplateNotFound:
            if self.logger:
                self.logger.warning("Template file not found: dim_ddl.tpl")
            return

        for table_name, dim_info in dim_designs.items():
            context = {
                "table_name": table_name,
                "entity": dim_info["entity"],
                "scd_type": dim_info["scd_type"],
                "business_key": dim_info["business_key"],
                "attributes": dim_info["attributes"],
                "scd_tracking_fields": dim_info.get("scd_tracking_fields", []),
                "scd_fields": dim_info["scd_fields"],
                "table_comment": f"维度表: {dim_info.get('display_name', dim_info['entity'])}",
            }
            sql = template.render(context)
            output_file = output_dir / f"{table_name}_scd{dim_info['scd_type']}.sql"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(sql)
            if self.logger:
                self.logger.success(f"  Generated DDL: {output_file.name}")
