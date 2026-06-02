# Merge Notes: cdm_modeling

## Breaking Change

This branch replaces the previous `.claude/skills/cdm_modeling` implementation with the renamed `cdm_modeling_skill` implementation.

Impacts:
- The old `cdm_modeling_skill` skill directory is removed and its maintained contents now live under `.claude/skills/cdm_modeling`.
- The CDM skill now reads upstream bus-matrix and ODS metadata analysis documents through `input.bus_matrix_doc` and `input.ods_metadata_doc`; old configs that use the previous direct bus-matrix CSV interface are not compatible without migration.
- The CDM default output path is `.claude/skills/cdm_modeling/output/cdm-modeling/` when running the default skill config.
- DWS defaults now read CDM outputs from `.claude/skills/cdm_modeling/output/cdm-modeling/docs/`.
- `dim_list.csv` and `dwd_list.csv` remain in the field-level sectioned CSV format expected by `dws-designer`.

Recommended validation before merge:
- Run `python3 .claude/skills/cdm_modeling/scripts/main.py`.
- Run `python3 .claude/skills/dws-designer/scripts/generate_dws.py` after CDM outputs are generated.
