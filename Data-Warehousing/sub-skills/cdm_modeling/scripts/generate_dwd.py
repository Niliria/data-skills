"""
generate_dwd.py - DWD事实表生成模块
========================================
根据上游总线矩阵解析结果生成 DWD 事实表设计和 DDL。
"""

import re
from pathlib import Path
from typing import Dict, Any, List

from jinja2 import Environment, FileSystemLoader, TemplateNotFound


class FactTableGenerator:
    """事实表生成器。"""

    def __init__(
        self,
        upstream_model: Dict[str, Any],
        dim_designs: Dict[str, Dict],
        modeling_config: Dict[str, Any],
        rules_dir: Path,
        templates_dir: Path,
        output_dir: Path = None,
        logger=None,
    ):
        self.upstream_model = upstream_model
        self.dim_designs = dim_designs
        self.modeling_config = modeling_config
        self.rules_dir = Path(rules_dir)
        self.templates_dir = Path(templates_dir)
        self.output_dir = Path(output_dir) if output_dir else None
        self.logger = logger

    def generate(self) -> Dict[str, Dict]:
        dwd_designs: Dict[str, Dict] = {}
        for process in self.upstream_model.get("processes", []):
            domain = self._normalize_name(process.get("domain", "default"))
            process_name = self._normalize_name(process.get("business_process", "process"))
            table_name = process.get("table_name") or f"dwd_{domain}_{process_name}_di"
            if process.get("dimensions_authoritative"):
                dimensions = [self._normalize_name(dim) for dim in process.get("dimensions", [])]
            elif process.get("dimension_refs"):
                dimensions = [self._normalize_name(dim) for dim in process.get("dimensions", [])]
            else:
                dimensions = self._normalize_dimensions(process.get("dimensions", []))
            dimension_refs = process.get("dimension_refs") or [
                {"entity": dim, "business_key": self._dimension_business_key(dim)}
                for dim in dimensions
            ]
            dimension_refs = [self._enrich_dimension_ref(dim) for dim in dimension_refs]
            measures = self._normalize_measures(process.get("measures", []))

            dwd_designs[table_name] = {
                "table_name": table_name,
                "domain": domain,
                "business_process": process_name,
                "display_process": process.get("business_process", process_name),
                "business_key": process.get("business_key") or self._derive_business_key(process_name, process.get("grain", "")),
                "dimensions": dimensions,
                "dimension_refs": dimension_refs,
                "measures": measures,
                "grain": process.get("grain") or self._derive_business_key(process_name, ""),
                "fact_type": process.get("fact_type") or self.modeling_config.get("default_fact_type", "transaction"),
                "source_tables": process.get("source_tables", []),
                "estimated_size": "large",
            }
            if self.logger:
                self.logger.success(f"  {table_name} (measures={len(measures)}, dims={len(dimensions)})")

        if self.output_dir:
            self._generate_ddl(dwd_designs)
        return dwd_designs

    def _generate_ddl(self, dwd_designs: Dict[str, Dict]) -> None:
        output_dir = self.output_dir / "ddl" / "dwd"
        output_dir.mkdir(parents=True, exist_ok=True)
        env = Environment(loader=FileSystemLoader(str(self.templates_dir)))

        try:
            template = env.get_template("dwd_ddl.tpl")
        except TemplateNotFound:
            if self.logger:
                self.logger.warning("Template file not found: dwd_ddl.tpl")
            return

        for table_name, dwd_info in dwd_designs.items():
            context = {
                "table_name": table_name,
                "entity": dwd_info["business_process"],
                "domain": dwd_info["domain"],
                "business_process": dwd_info["business_process"],
                "business_key": dwd_info["business_key"],
                "grain": dwd_info["grain"],
                "dimensions": dwd_info["dimension_refs"],
                "measures": dwd_info["measures"],
                "table_comment": f"事实表: {dwd_info['domain']}-{dwd_info['display_process']}",
            }
            sql = template.render(context)
            output_file = output_dir / f"{table_name}.sql"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(sql)
            if self.logger:
                self.logger.success(f"  Generated DDL: {output_file.name}")

    def _normalize_dimensions(self, dimensions: List[str]) -> List[str]:
        normalized = [self._normalize_name(dim) for dim in dimensions]
        if "date" not in normalized:
            normalized.append("date")
        return normalized

    def _dimension_business_key(self, entity: str) -> str:
        table_name = f"dim_{entity}"
        if table_name in self.dim_designs:
            return self.dim_designs[table_name].get("business_key", f"{entity}_id")
        return f"{entity}_id"

    def _enrich_dimension_ref(self, dim: Dict[str, Any]) -> Dict[str, Any]:
        result = dict(dim)
        table_name = result.get("table_name") or f"dim_{result['entity']}"
        result["table_name"] = table_name
        if table_name in self.dim_designs:
            result["scd_type"] = self.dim_designs[table_name].get("scd_type", 1)
        else:
            result["scd_type"] = result.get("scd_type", 1)
        return result

    def _normalize_measures(self, measures: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        result = []
        for measure in measures:
            result.append({
                "name": measure.get("name") or self._normalize_name(measure.get("description", "measure")),
                "source_field": measure.get("source_field") or measure.get("name"),
                "type": measure.get("type") or "DECIMAL(18,2)",
                "description": measure.get("description") or measure.get("name", ""),
                "aggregation": measure.get("aggregation") or "SUM",
            })
        return result

    def _derive_business_key(self, process_name: str, grain: str) -> str:
        grain_en = self._normalize_name(grain)
        if grain_en and grain_en != "default":
            return f"{grain_en}_id"
        return f"{process_name}_id"

    def _normalize_name(self, name: str) -> str:
        name_map = {
            "销售": "sales",
            "库存": "inventory",
            "门店销售": "shop_sales",
            "订单明细": "order_detail",
            "订单": "order",
            "退货": "return",
            "客户": "customer",
            "商品": "product",
            "店铺": "shop",
            "门店": "shop",
            "日期": "date",
            "地区": "region",
        }
        raw = str(name).strip()
        return name_map.get(raw, re.sub(r"[^a-zA-Z0-9_]+", "_", raw.lower()).strip("_") or "default")
