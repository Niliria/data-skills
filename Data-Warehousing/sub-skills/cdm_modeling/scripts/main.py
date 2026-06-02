"""
CDM建模 Skill - 主入口脚本
========================================
读取上游总线矩阵文档和 ODS 元数据解析文档，生成 CDM 层 DIM/DWD 设计产物。
"""

import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

import yaml

try:
    from parse_upstream_outputs import UpstreamOutputParser
    from generate_dim import DimensionGenerator
    from generate_dwd import FactTableGenerator
    from generate_etl import ETLScriptGenerator
    from validate_model import validate_output_dir, write_report
except ImportError as e:
    print(f"模块导入失败: {e}")
    print("请确保所有脚本都在同一目录下")
    sys.exit(1)


class Logger:
    """简单日志器。"""

    @staticmethod
    def info(msg):
        print(f"[INFO] {msg}")

    @staticmethod
    def success(msg):
        print(f"[OK] {msg}")

    @staticmethod
    def warning(msg):
        print(f"[WARN] {msg}")

    @staticmethod
    def error(msg):
        print(f"[ERROR] {msg}")


class CDMModelingSkill:
    """CDM建模 Skill 主流程。"""

    def __init__(self, config_file: Path):
        self.logger = Logger()
        self.config_file = Path(config_file)
        self.config_dir = self.config_file.parent
        self.skill_root = Path(__file__).parent.parent
        self.config = self._load_config(self.config_file)
        self.output_dir = self._resolve_path(self.config["output"]["target_dir"])

    def _load_config(self, config_file: Path) -> Dict[str, Any]:
        if not config_file.exists():
            self.logger.error(f"配置文件不存在: {config_file}")
            sys.exit(1)
        with open(config_file, "r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}

    def _resolve_path(self, raw_path: str) -> Path:
        path = Path(raw_path)
        if path.is_absolute():
            return path
        return self.config_dir / path

    def run(self) -> bool:
        self.logger.info("=" * 60)
        self.logger.info("CDM 建模 Skill v1.3")
        self.logger.info("=" * 60)

        start_time = datetime.now()

        try:
            upstream_model = self._parse_upstream_model()
            dim_designs = self._generate_dimensions(upstream_model)
            dwd_designs = self._generate_facts(upstream_model, dim_designs)
            self._generate_etl(dim_designs, dwd_designs)
            self._generate_docs(upstream_model, dim_designs, dwd_designs)

            elapsed_time = (datetime.now() - start_time).total_seconds()
            self.logger.success(f"全部完成，耗时 {elapsed_time:.2f} 秒")
            self._print_summary(dim_designs, dwd_designs)
            return True
        except Exception as e:
            self.logger.error(f"执行失败: {e}")
            return False

    def _parse_upstream_model(self) -> Dict[str, Any]:
        self.logger.info("Phase 1: 解析上游输入")
        input_config = self.config.get("input", {})
        self.logger.info("使用 DWM DIM/DWD spec CSV/XLSX 作为权威输入")
        parser = UpstreamOutputParser(
            dim_spec_file=input_config.get("dim_spec_file", ""),
            dwd_fact_spec_file=input_config.get("dwd_fact_spec_file", ""),
            base_dir=self.config_dir,
            logger=self.logger,
        )
        model = parser.parse()
        self.logger.success(
            f"解析完成: {len(model['processes'])} 个业务过程, {len(model['dimensions'])} 个维度"
        )
        return model

    def _generate_dimensions(self, upstream_model: Dict[str, Any]) -> Dict[str, Dict]:
        self.logger.info("Phase 2: 生成 DIM 维度表")
        generator = DimensionGenerator(
            upstream_model=upstream_model,
            modeling_config=self.config.get("modeling", {}),
            rules_dir=self.skill_root / "rules",
            templates_dir=self.skill_root / "templates",
            output_dir=self.output_dir if self.config.get("modeling", {}).get("generate_ddl", True) else None,
            logger=self.logger,
        )
        dim_designs = generator.generate()
        self.logger.success(f"生成完成: {len(dim_designs)} 个维度表")
        return dim_designs

    def _generate_facts(self, upstream_model: Dict[str, Any], dim_designs: Dict[str, Dict]) -> Dict[str, Dict]:
        self.logger.info("Phase 3: 生成 DWD 事实表")
        generator = FactTableGenerator(
            upstream_model=upstream_model,
            dim_designs=dim_designs,
            modeling_config=self.config.get("modeling", {}),
            rules_dir=self.skill_root / "rules",
            templates_dir=self.skill_root / "templates",
            output_dir=self.output_dir if self.config.get("modeling", {}).get("generate_ddl", True) else None,
            logger=self.logger,
        )
        dwd_designs = generator.generate()
        self.logger.success(f"生成完成: {len(dwd_designs)} 个事实表")
        return dwd_designs

    def _generate_etl(self, dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        if not self.config.get("modeling", {}).get("generate_etl", True):
            self.logger.info("Phase 4: 跳过 ETL 脚本生成")
            return
        self.logger.info("Phase 4: 生成 ETL 脚本")
        generator = ETLScriptGenerator(
            dim_designs=dim_designs,
            dwd_designs=dwd_designs,
            rules_dir=self.skill_root / "rules",
            templates_dir=self.skill_root / "templates",
            output_dir=self.output_dir,
            logger=self.logger,
        )
        generator.generate()
        self.logger.success("ETL脚本生成完成")

    def _generate_docs(self, upstream_model: Dict[str, Any], dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        self.logger.info("Phase 5: 生成模型清单和校验报告")
        doc_dir = self.output_dir / "docs"
        doc_dir.mkdir(parents=True, exist_ok=True)
        self._generate_dim_csv(doc_dir / "dim_list.csv", dim_designs)
        self._generate_dwd_csv(doc_dir / "dwd_list.csv", dwd_designs)
        self._generate_field_mapping_csv(doc_dir / "field_mapping.csv", dim_designs, dwd_designs)
        self._generate_dependency_csv(doc_dir / "dependency.csv", dim_designs, dwd_designs)
        self._generate_model_design(doc_dir / "model_design.md", dim_designs, dwd_designs)
        self._generate_validation_report(doc_dir / "validation_report.md", upstream_model, dim_designs, dwd_designs)
        artifact_errors, artifact_warnings = validate_output_dir(self.output_dir)
        upstream_errors, upstream_warnings = self._collect_model_validation(upstream_model, dim_designs, dwd_designs)
        write_report(
            doc_dir / "validation_report.md",
            upstream_errors + artifact_errors,
            upstream_warnings + artifact_warnings,
        )
        self.logger.success("设计文档生成完成")

    def _generate_dim_csv(self, csv_file: Path, dim_designs: Dict[str, Dict]) -> None:
        with open(csv_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for table_name, dim in sorted(dim_designs.items()):
                writer.writerow(["模型名", table_name])
                writer.writerow(["中文名", f"维度表-{dim.get('display_name', dim['entity'])}"])
                writer.writerow(["数据来源", "+".join(dim.get("source_tables", [])) or "ODS"])
                writer.writerow(["主题", dim["entity"]])
                writer.writerow(["层级", "DIM"])
                writer.writerow(["说明", f"维度表: {dim['entity']}, SCD Type {dim['scd_type']}"])
                writer.writerow(["分区字段", "pt"])
                writer.writerow(["字段", "字段名", "字段类型", "字段说明", "数据来源", "是否为空", "维度"])
                writer.writerow(["", dim["business_key"], "STRING", f"{dim['entity']}业务键", "首取", "N", "Y"])
                for attr in dim.get("attributes", []):
                    writer.writerow([
                        "",
                        attr["name"],
                        attr.get("type") or "STRING",
                        attr.get("description") or attr["name"],
                        attr.get("source_field", attr["name"]),
                        "Y",
                        "Y",
                    ])
                if dim.get("scd_type") == 2:
                    writer.writerow(["", "begin_date", "STRING", "生效日期", "系统生成", "N", ""])
                    writer.writerow(["", "end_date", "STRING", "失效日期", "系统生成", "Y", ""])
                    writer.writerow(["", "is_active", "INT", "是否当前记录", "系统生成", "N", ""])
                writer.writerow(["", "etl_insert_time", "TIMESTAMP", "ETL插入时间", "ETL", "N", ""])
                writer.writerow(["", "etl_update_time", "TIMESTAMP", "ETL更新时间", "ETL", "Y", ""])
                writer.writerow(["", "pt", "STRING", "分区日期", "ETL", "N", ""])
                writer.writerow([])
                writer.writerow([])

    def _generate_dwd_csv(self, csv_file: Path, dwd_designs: Dict[str, Dict]) -> None:
        with open(csv_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for table_name, fact in sorted(dwd_designs.items()):
                writer.writerow(["模型名", table_name])
                writer.writerow(["中文名", f"事实表-{fact.get('display_process', fact['business_process'])}"])
                writer.writerow(["数据来源", "+".join(fact.get("source_tables", [])) or "ODS"])
                writer.writerow(["主题", fact["domain"]])
                writer.writerow(["层级", "DWD"])
                writer.writerow(["说明", f"事实表: {fact['domain']}-{fact.get('display_process', fact['business_process'])}"])
                writer.writerow(["粒度", fact["grain"]])
                writer.writerow(["事实类型", fact["fact_type"]])
                writer.writerow(["分区字段", "pt"])
                writer.writerow(["字段", "字段名", "字段类型", "字段说明", "数据来源", "是否为空", "维度", "度量"])
                writer.writerow(["", fact["business_key"], "STRING", f"{fact['business_process']}业务键", "首取", "N", "", ""])
                for dim in fact.get("dimension_refs", []):
                    writer.writerow([
                        "",
                        f"{dim['entity']}_sk",
                        "BIGINT",
                        f"关联 dim_{dim['entity']} 的代理键",
                        dim["business_key"],
                        "N",
                        "Y",
                        "",
                    ])
                for measure in fact.get("measures", []):
                    writer.writerow([
                        "",
                        measure["name"],
                        measure.get("type") or "DECIMAL(18,2)",
                        measure.get("description") or measure["name"],
                        measure.get("source_field", measure["name"]),
                        "N",
                        "",
                        "Y",
                    ])
                writer.writerow(["", "is_valid", "INT", "是否有效记录", "ETL", "N", "", ""])
                writer.writerow(["", "etl_insert_time", "TIMESTAMP", "ETL插入时间", "ETL", "N", "", ""])
                writer.writerow(["", "etl_update_time", "TIMESTAMP", "ETL更新时间", "ETL", "Y", "", ""])
                writer.writerow(["", "source_system", "STRING", "来源系统", "ETL", "N", "", ""])
                writer.writerow(["", "pt", "STRING", "分区日期", "ETL", "N", "", ""])
                writer.writerow([])
                writer.writerow([])

    def _generate_field_mapping_csv(self, csv_file: Path, dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        with open(csv_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["target_table", "target_field", "source_table", "source_field", "field_role"])
            for table_name, dim in sorted(dim_designs.items()):
                source_table = dim.get("source_tables", [""])[0] if dim.get("source_tables") else ""
                writer.writerow([table_name, dim["business_key"], source_table, dim["business_key"], "business_key"])
                for attr in dim.get("attributes", []):
                    writer.writerow([table_name, attr["name"], source_table, attr.get("source_field", attr["name"]), "dimension_attribute"])
            for table_name, fact in sorted(dwd_designs.items()):
                source_table = fact.get("source_tables", [""])[0] if fact.get("source_tables") else ""
                for dim in fact.get("dimension_refs", []):
                    writer.writerow([table_name, f"{dim['entity']}_sk", source_table, dim["business_key"], "dimension_fk"])
                for measure in fact.get("measures", []):
                    writer.writerow([table_name, measure["name"], source_table, measure.get("source_field", measure["name"]), "measure"])

    def _generate_dependency_csv(self, csv_file: Path, dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        with open(csv_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["layer", "target_table", "depends_on", "load_order", "description"])
            for table_name, dim in sorted(dim_designs.items()):
                writer.writerow(["DIM", table_name, "+".join(dim.get("source_tables", [])), 1, "维度表依赖上游 ODS/DWS 源"])
            dim_tables = "+".join(sorted(dim_designs.keys()))
            for table_name, fact in sorted(dwd_designs.items()):
                depends_on = "+".join([*fact.get("source_tables", []), dim_tables])
                writer.writerow(["DWD", table_name, depends_on, 2, "事实表依赖源事实数据和维度表"])

    def _generate_model_design(self, md_file: Path, dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        lines = ["# CDM Model Design", "", "## DIM Tables", ""]
        for table_name, dim in sorted(dim_designs.items()):
            lines.append(f"- `{table_name}`: entity `{dim['entity']}`, SCD Type {dim['scd_type']}, business key `{dim['business_key']}`")
        lines.extend(["", "## DWD Tables", ""])
        for table_name, fact in sorted(dwd_designs.items()):
            lines.append(f"- `{table_name}`: process `{fact['business_process']}`, grain `{fact['grain']}`, fact type `{fact['fact_type']}`")
        md_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _generate_validation_report(
        self,
        report_file: Path,
        upstream_model: Dict[str, Any],
        dim_designs: Dict[str, Dict],
        dwd_designs: Dict[str, Dict],
    ) -> None:
        errors, warnings = self._collect_model_validation(upstream_model, dim_designs, dwd_designs)
        write_report(report_file, errors, warnings)

    def _collect_model_validation(
        self,
        upstream_model: Dict[str, Any],
        dim_designs: Dict[str, Dict],
        dwd_designs: Dict[str, Dict],
    ) -> tuple[list[str], list[str]]:
        errors: list[str] = []
        warnings: list[str] = list(upstream_model.get("warnings", []))

        if not upstream_model.get("processes"):
            errors.append("未解析到任何业务过程")

        for table_name, dim in sorted(dim_designs.items()):
            if not dim.get("business_key"):
                errors.append(f"DIM {table_name} 缺少业务键")
            if dim.get("entity") != "date" and not dim.get("attributes"):
                warnings.append(f"DIM {table_name} 缺少维度属性")
            if dim.get("scd_type") == 2:
                required = {"begin_date", "end_date", "is_active"}
                if not required.issubset(set(dim.get("scd_fields", []))):
                    errors.append(f"DIM {table_name} SCD Type II 字段不完整")

        dim_tables = set(dim_designs.keys())
        for table_name, fact in sorted(dwd_designs.items()):
            if not fact.get("grain"):
                errors.append(f"DWD {table_name} 缺少粒度")
            if fact.get("fact_type") != "factless" and not fact.get("measures"):
                errors.append(f"DWD {table_name} 缺少度量")
            for dim in fact.get("dimension_refs", []):
                dim_table = dim.get("table_name") or f"dim_{dim.get('entity')}"
                if dim_table not in dim_tables:
                    errors.append(f"DWD {table_name} 引用了不存在的 DIM: {dim_table}")

        return errors, warnings

    def _print_summary(self, dim_designs: Dict[str, Dict], dwd_designs: Dict[str, Dict]) -> None:
        print("\n设计总结:")
        print(f"  DIM维度表: {len(dim_designs)} 个")
        print(f"  DWD事实表: {len(dwd_designs)} 个")
        print("\n输出目录:")
        print(f"  DDL: {self.output_dir / 'ddl'}")
        print(f"  ETL: {self.output_dir / 'etl'}")
        print(f"  Docs: {self.output_dir / 'docs'}")


def default_config_file() -> Path:
    return Path(__file__).parent.parent / "skill_config.yaml"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate CDM DIM/DWD artifacts from upstream analysis documents.")
    parser.add_argument("--config", default=str(default_config_file()), help="Path to skill_config.yaml")
    args = parser.parse_args()

    skill = CDMModelingSkill(Path(args.config))
    success = skill.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
