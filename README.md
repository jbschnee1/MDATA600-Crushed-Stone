# MDATA 600 Crushed Stone Project

This project studies U.S. state-level crushed stone sold or used and its relationship to construction, economic, capacity and cost indicators, using 2015–2023 annual data. Quantities are in metric tons; sold/used production is not a direct measure of latent demand.

**Current stage:** Gate 1 approved; data pipeline, EDA, model comparison and robustness work completed. [Decision Gate 2](docs/decision_gate_2.md) awaits approval of the model and interpretation framework. See [PROJECT_STATUS.md](PROJECT_STATUS.md) for results and limitations. Final report and presentation production follow Gate 2.

## Run the analysis

With the prepared local packages and pinned source snapshots, run from the project root:

```sh
Rscript --vanilla R/run_pipeline.R all
Rscript --vanilla tests/check_pipeline.R
```

Use `data` instead of `all` to build only the analytical data, or `development` to include development analyses. The pipeline verifies exact source hashes, preserves original data, and refuses to overwrite a changed frozen model selection. It does not silently refresh source vintages. No API keys or network access are needed for the cached run.

[Reproducibility instructions](docs/reproducibility.md) document local package restoration, source acquisition, manual requirements and the FHWA workbook limitation. Dependencies are pinned in `renv.lock`; added packages reside in ignored `.R-library/`. Original source vintages must accompany the project.

## Data and analysis

| Source | Measures and role |
|---|---|
| USGS | Target quantity sold/used; value and national totals for context |
| Census Building Permits Survey | Primary housing units authorized |
| FHWA | Primary highway capital outlays, with reporting-year flags |
| BEA | Primary construction real GDP; broader economic context |
| BLS | Secondary heavy/civil construction employment; 36-state coverage |
| FRED | CPI for monetary adjustment; national mortgage context |
| Census construction spending | Secondary private nonresidential and state/local spending |
| EIA | Secondary industrial energy prices |
| MSHA | Secondary stone-mine activity; measurement/classification caveats |

The approved backbone has 450 rows and 65 fields, with 427 numeric targets. Strict source-timing eligibility yields 419 explanatory and 371 lagged cases. Primary validation uses rolling development years 2019–2021 and a frozen sequential evaluation of 2022/2023. High level R² is accompanied by weak and unstable improvement over the prior-year baseline. Full definitions and source evidence appear in the [data dictionary](docs/data_dictionary.md), [source register](docs/source_register.md), [quality report](docs/data_quality_report.md) and [validation protocol](docs/validation_protocol.md).

## Project structure

| Location | Contents |
|---|---|
| `R/run_pipeline.R` | Single entry point |
| `R/01_import.R` through `R/03_join.R` | Immutable source staging, parsing, cleaning and panel assembly |
| `R/04_eda.R`, `R/05_models.R`, `R/05_diagnostics.R` | Development analysis, frozen selection and diagnostics |
| `R/06_evaluate.R`, `R/07_explanation.R`, `R/08_gate2.R` | Final evaluation, explanatory sensitivities and review packet |
| `data/raw/snapshots/` | Hash-pinned source inputs |
| `data/clean/approved/`, `data/processed/approved/` | New derived data; original files preserved |
| `output/tables/`, `output/figures/`, `output/models/`, `output/logs/` | Generated numerical results, visuals, model records and checks |
| `docs/`, `docs/evidence/` | Decisions, dictionaries, provenance, course guide and historical audit |
| `report/` | Preserved report/presentation scaffolds; drafting after Gate 2 |

## AI use log

**2026-09-06 addition:** Codex executed source verification, pipeline repairs, development and final model evaluation, diagnostics, figures and the Gate 2 review documents after design approval. The principal investigator must review the model and substantive interpretation at Gate 2. These additions are not represented as already reviewed or authored in the investigator's personal voice.


AI tools were used as assistants during this project. Their overarching uses are summarized below.

### Codex

- Helped organize and scaffold the project's R scripts and reporting files.
- Assisted with developing and refining code for importing data from public APIs and other government data sources.
- Assisted with implementing the cleaning and state-year join workflows, including validation checks, missing-data handling, and generation of the processed panel.
- Supported debugging, code review, refactoring, and documentation, including updates to this README and AI-use disclosure.
- Helped identify potential data-quality, reproducibility, and workflow issues.

### GitHub Copilot

- Provided inline code completions while writing R and Quarto files.
- Suggested routine syntax, data-transformation steps, comments, and repetitive boilerplate.
- Assisted with small edits and alternative implementations during development.

AI tools were used for assistance with code and prose, not as data sources or as substitutes for methodological judgment. The prior project log stated that earlier AI-generated suggestions and outputs were reviewed, adapted, and validated by the project author. The new analysis and Gate 2 interpretation remain pending author review; approval of the research design does not establish review of every subsequent output. The author remains responsible for the analysis, methodological choices, interpretation, and final submitted work.
