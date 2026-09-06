# Reproduce the approved analysis

Run all commands from the project root. The Gate 2 analysis uses R 4.6.1, the packages in `renv.lock`, and the exact 27 inputs in [source_manifest.csv](source_manifest.csv). The preserved original acquisition code is in `docs/evidence/baseline_code/`; it is historical evidence, not the active entry point.

## Run with the prepared local environment

```sh
Rscript --vanilla R/run_pipeline.R all > output/logs/full_pipeline.log 2>&1
Rscript --vanilla tests/check_pipeline.R > output/logs/pipeline_tests.log 2>&1
```

The default stage is `data`. Use `Rscript --vanilla R/run_pipeline.R data` for acquisition from the pinned cache, cleaning and joins; `development` also runs EDA, development comparisons and diagnostics; `all` additionally runs frozen final evaluation, explanatory sensitivities and Gate 2 document generation. No API keys, network connection, Quarto or Pandoc are needed when the pinned snapshots and R packages are present. Commands write derived files under `approved/`, tables, figures, models, logs and generated review documents. Original parsed raw/clean/processed CSVs remain unchanged.

`all` regenerates the review packet but does not create the final course report or slides. Those require Gate 2 approval. Do not hand-edit generated numerical tables or the Gate 2 packet: change the generating code only for a documented correction. Model choices cannot be reconsidered using the final results.

## Restore dependencies on another machine

Use R 4.6.1 to match the recorded environment. Dependencies are pinned to 59 packages; `.R-library/` and `.renv-cache/` are project-local and ignored. On a fresh machine with internet access, bootstrap renv locally, then restore the lockfile:

```sh
Rscript --vanilla -e 'dir.create(".R-library", showWarnings=FALSE); install.packages("renv", lib=".R-library", repos="https://cloud.r-project.org")'
RENV_PATHS_ROOT="$PWD/.renv-cache" Rscript --vanilla -e '.libPaths(c(normalizePath(".R-library"), .libPaths())); renv::restore(project=getwd(), library=normalizePath(".R-library"), lockfile="renv.lock", prompt=FALSE)'
```

These commands do not install or upgrade global packages. Package compilation may require the platform's R build tools; availability of package repositories and build tools is an external requirement. The current machine's installed versions were snapshotted; restoration on a second machine has not been tested. [Session information](../output/logs/session_info.txt) records the successful run environment. The entry point loads `.R-library/` first and otherwise uses R's existing libraries; the tests fail if required packages are unavailable. Keep the lockfile with the project.

## Preserve the source vintage

The canonical inputs are immutable files under `data/raw/snapshots/`. Each manifest row supplies its source, URL, SHA-256 and a bootstrap path to the acquisition evidence. `R/01_import.R` validates existing snapshots, copies a missing snapshot from its matching bootstrap archive, or retries a public URL. A changed hash stops the run: it never silently accepts a new source vintage. API responses were saved without credential-bearing request envelopes. Copy the canonical snapshots and manifest together when transferring the project.

There is one disclosed source limitation: FHWA 2015-2022 original workbooks could not be reacquired because certificate validation repeatedly failed. The analysis uses the pinned pre-existing parsed FHWA CSV and independently verified reporting-year flags. FHWA 2023 was checked against its original workbook. No insecure TLS bypass was used. Thus the complete analysis is reproducible from the preserved inputs, but full fresh reacquisition of every original workbook is not established.

For audit-only fresh access checks:

```sh
SSL_CERT_FILE=/etc/ssl/cert.pem python3 R/00_verify_downloads.py
Rscript --vanilla R/00_verify_apis.R
```

API probes use `BEA_KEY`, `BLS_KEY`, `FRED_KEY` environment variables first, then an ignored local `api-keys.R` with the existing lowercase assignments. These checks create acquisition evidence; they do not refresh the approved analysis. Keep changed downloads separate. A new vintage requires a documented manifest update and a new analysis version; the existing frozen evaluation must remain identifiable. Do not delete the selection artifact to get around a hash failure.

The inherited `api-keys.R` is already Git-tracked. The ignore rule does not untrack it. Its actual keys were not printed, copied into outputs or committed by this work. The owner should rotate live keys and remove this file from tracking before repository sharing; no credential or Git-history mutation was made.

## Artifacts and checks

| Artifact | Purpose |
|---|---|
| `data/processed/approved/crushed_stone_state_year.csv` | 450 rows, 65 fields; flags and lag eligibility retained |
| `docs/approved_variable_dictionary.csv` | Definition, units, role and handling for every analytical field |
| `docs/data_quality_report.md` | Counts, exclusions, units, provenance and anomalies |
| `output/tables/state_year_coverage.csv`, `join_audit.csv` | Explicit coverage and join cardinality |
| `docs/validation_protocol.md` | Pre-evaluation selection, timing and uncertainty rules |
| `output/models/development_selection.rds` and `.json` | Frozen model specifications, calibration and source/data/code hashes |
| `output/tables/model_results_register.csv` | Features, hyperparameters, splits, metrics and evaluation code hash |
| `output/tables/` | Development/final scores, uncertainty, explanatory diagnostics and sensitivities |
| `output/figures/` | Six figures generated from analysis outputs |
| `docs/decision_gate_2.md`, `forecast_feasibility.md` | Generated model/interpretation decision evidence |
| `docs/evidence/gate_2_checks.txt` | Final Gate 2 checks and preservation/reproduction results |

Assertions cover state/year uniqueness, valid keys, unit metadata, exact calendar lags, FHWA masks, CPI support, nonnegative targets, expected coverage, and unchanged raw CSV hashes. Tests deliberately reject duplicate/invalid keys and expanding joins, confirm predictions cannot access held-out outcomes, reject future training rows, and check the zero-penalty ridge identity against OLS. Hash guards prevent replacing a frozen selection with a changed model/data/code configuration.

The final evaluation was already observed. Re-running the same procedure verifies reproducibility; it does not create an independent test set. Current-vintage source revisions mean these are retrospective temporal comparisons, not reconstructed real-time forecasts. Random seeds and single-thread forests stabilize calculations; another R/platform/BLAS combination may differ at floating-point precision. Saved hashes and numerical tables permit explicit comparison.
