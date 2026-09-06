# Project status — 2026-09-06

**Stage: Phase 0 complete; Phase 1 source verification and Decision Gate 1 preparation complete, with explicit limitations below. Scope approval is pending. No models have been fitted.**

## Authority and current scope

The governing task is `astra_mdata_middle_approach.md`. The complete **MDATA 600 Capstone Course Guide.docx**, supplied in `docs/evidence/`, was read, including its tables. Its milestone requirements agree with the brief. The course guide takes priority in any future conflict. No proposal, professor feedback, previous source inventory, or HTML output was found in the project. No unrelated directories were searched. The actual meeting already reached and meeting dates are not documented; the artifact stage is acquisition/pre-analysis, which does not establish the course calendar stage.

The working data structure is 50 states × 2015–2023, excluding DC and territories (450 rows). The proposed analytical outcome is USGS crushed stone **sold or used**, in metric tons, attributed to the state of first sale/use; it is not necessarily extraction in that state or a direct measure of latent demand. Scope remains subject to [Gate 1](docs/decision_gate_1.md).

## Existing artifacts and preservation

| Artifact | Baseline finding |
|---|---|
| `R/01_import.R` | 1,278-line acquisition implementation covering ten import selections/eight publishers; all code read. |
| `R/02_clean.R`, `R/03_join.R` | Implemented; clean fails on stored inputs, join works from existing clean caches. |
| `data/raw/` | Ten parsed CSVs, not original source responses; some contain previously derived columns. |
| `data/clean/` | Three populated CSVs for BEA construction, FRED and MSHA. |
| `data/processed/crushed_stone_state_year.csv` | 450 unique state-years, 80 columns; an assembled panel, not an approved model-ready dataset. |
| `R/04_eda.R`, `R/05_models.R` | Empty (one newline each). |
| `report/final_report.qmd`, `report/presentation.qmd` | Empty (one newline each); no report or slides exist yet. |
| `renv.lock`, `.Rproj` | Empty (one newline each); no usable dependency lock/project configuration. |
| `README.md` | Existing workflow and AI-use description; now links to verified status. |
| `api-keys.R` | Git-tracked file containing three nonempty literal credential assignments; values were not printed or copied. |

Initial Git status: `main...origin/main`, with only the governing brief untracked. No pre-existing tracked changes were present. The subsequently supplied course guide is preserved. No commits, branches, index changes, or remote operations were made. Every original `data/**/*.csv` checksum is preserved. The directory layout is retained; new work uses `docs/`, `docs/evidence/`, `output/source_verification/`, and audit scripts in `R/`.

## What works, and what does not

- Installed R: 4.6.1. All packages used by the existing acquisition/clean/join scripts are installed. Versions and parse checks are recorded in `docs/evidence/baseline_checks.log`; no dependencies were installed. `renv` is absent and its lockfile is empty. Locale startup warnings are recorded.
- In a temporary copy, `R/02_clean.R` exits 1: the saved FRED input lacks 2014 CPI. A fresh authenticated probe retrieved 2014 CPI (12 monthly observations), archived as evidence; existing raw data were not replaced. The repair belongs in the post-approval pipeline work.
- Running `R/03_join.R` alone in that temporary copy exits 0 and recreates the stored panel exactly as CSV records. This uses pre-existing clean caches and **does not demonstrate end-to-end reproducibility**.
- Unique panel keys, 50-state coverage, year bounds, observed target nonnegativity, and stored capacity-lag alignment pass. Coverage and large annual changes are documented without deleting observations.
- Source probes obtained and inspected USGS, BPS (all nine years), BEA (all proposed tables), FRED, EIA, Census construction, MSHA, and the FHWA 2023 workbook. Compared measures match stored values within the stated numerical tolerance. All nine FHWA official HTML tables were inspected; repeat binary downloads encountered certificate-chain failures. Older FHWA binary inputs remain unarchived and unreconciled in this audit.

## Confirmed sources and quality limitations

See [source register](docs/source_register.md) for URLs, units, versions, availability, evidence and footnotes, and [data dictionary](docs/data_dictionary.md) for feature definitions.

1. **23 target values are withheld (`W`)**, confirmed in the original USGS workbook: Delaware and Louisiana in all nine years; Nebraska in 2019–2023. There are 427 usable target observations across 48 states, of which 47 have complete target histories. Never replace withheld tonnage with zero. The published national total includes concealed amounts and need not equal the observed-state sum.
2. **Eight FHWA observations carry earlier reporting years.** They are the same rows with missing raw FIPS. Repairing the state name alone does not repair timing. The [footnote ledger](docs/evidence/fhwa_reporting_year_flags.csv) documents the mismatch. Recommended strict FHWA eligibility reduces contemporaneous target/predictor coverage to 419; lagged target/predictor comparisons to 371 in 2016–2023.
3. **BLS heavy/civil employment covers only 36 states** (324 rows, each with 12 months); 310 rows also have a target. Missing series were confirmed by fresh API responses. Use as secondary analysis, not an all-state requirement.
4. **USGS uses MSHA worker hours to estimate nonrespondents.** Same-year mine hours are partly linked to target construction and are not independent evidence of a capacity effect. MSHA also uses current commodity classification; zero completion assumes no qualifying records means zero activity. Keep out of the primary specification.
5. **National FRED measures are repeated across states**, not 450 independent macro observations. They are exactly absorbed by year fixed effects. Mortgage methodology changed in November 2022; BPS geography/universe methodology changed in 2023.
6. Existing `raw/` files lose some source tokens, metadata, and vintage information. Download dates for these pre-existing files are unknown; modification dates are not download provenance. New snapshots have acquisition evidence and hashes.
7. Monetary measures mix nominal dollars, thousands, millions, and chained 2017 dollars. No common-price FHWA or Census construction feature is implemented yet. Some saved raw files include growth/lag/inflation calculations that the current importer no longer writes.
8. Tracked local credentials and hard-coded local credential paths are unresolved reproducibility/security defects. A new ignore rule prevents future untracked credentials from being added, but cannot remove an already tracked file. No credential values appear in the new artifacts. If these are live keys, the owner should rotate them and remove the file from tracking before any further repository sharing; no history rewrite was performed.

## Course gaps and next actions

| Course requirement | Current gap / prepared response |
|---|---|
| Meeting 1: exactly 3–5 slides, ≤5 minutes, no generic background | Current presentation is empty. Gate packet includes a four-slide, 4:30 outline for use after design approval. |
| Meeting 1: measurable objectives and existing data access | Three specific proposed questions and verified downloadable/source-cached data now documented; FHWA download limitation disclosed. |
| Meeting 2: accomplishments, roadblocks, final scope lock | This status and the decision log supply the progress/roadblock record. Scope not approved yet; confirm whether Meeting 2 has occurred before changing the proposal. |
| Meeting 3: complete, ready-to-submit written report | Report is empty; writing/results remain downstream of approved analysis. Course guide does not specify a report template, length, or dates. |

**Next:** investigator approves or modifies [Decision Gate 1](docs/decision_gate_1.md), including target wording, sample exclusions, three questions, predictors, temporal evaluation and optional forecasting. If an existing proposal or feedback imposes further constraints, reconcile it before scope lock. After approval, implement Phase 2 in R: immutable snapshots and manifest, relative credential paths/environment precedence, CPI support year, FHWA year flags, explicit unit names, key/lag/coverage checks, and a deterministic dataset. Then proceed to EDA/model comparison and Gate 2. Do not select models or write findings at Gate 1.

## Reproduce the completed audit

Run from the project root:

```sh
python3 R/00_baseline_audit.py
# Optional fresh public/API access checks; authenticated keys stay local:
SSL_CERT_FILE=/etc/ssl/cert.pem python3 R/00_verify_downloads.py
Rscript --vanilla R/00_verify_apis.R
# Offline reconciliation of the downloaded snapshots:
Rscript --vanilla R/00_inspect_source_snapshots.R
```

The baseline audit writes only its evidence and runs existing clean/join code in a disposable copy. Snapshot inspection requires the cached files, including the successful FHWA 2023 workbook. Its exact acquisition command and checksum are recorded in the source register. The source cache is ignored by Git; preserve it locally with the manifests. These commands reproduce the audit, not an end-to-end analytical pipeline.
