# Project status — 2026-09-06

**Gate 1 approved; Phases 2–4 completed. Decision Gate 2 awaits investigator approval of the final model and interpretation framework.** Review the [Gate 2 packet](docs/decision_gate_2.md). The governing brief requires approval before report/presentation production; submission remains a separate Gate 3 decision.

The supplied **MDATA 600 Capstone Course Guide.docx** was read completely, including tables. Its requirements agree with the governing brief. No proposal, professor feedback or prior HTML was found in the project. The current course meeting and deadlines remain undocumented. Meeting 1 requires exactly 3–5 slides and at most five minutes; Meeting 2 locks scope; Meeting 3 requires a fully written report.

## Approved scope and completed work

The scope remains 2015–2023, 50 states, excluding DC/territories. The USGS target is crushed stone **sold or used, in metric tons**, attributed to first-sale/use geography. It is not a direct measure of demand or necessarily extraction in the same state. Gate 1 approved the three research questions, primary permits/highway/construction-GDP indicators, secondary-source sensitivities and temporal validation in [the design packet](docs/decision_gate_1.md).

- Built a reproducible R pipeline from 27 checksum-pinned inputs to a 450-row, 65-column [analytical dataset](data/processed/approved/crushed_stone_state_year.csv), with explicit coverage, source flags, unit checks and exact prior-year joins.
- Recovered the missing 2014 CPI support year, implemented constant-2017 monetary adjustments and masked eight FHWA reference-year discrepancies with corresponding lag exclusions.
- Corrected the inherited MSHA quote parser: 92,000 unique mine IDs now parse without errors; secondary activity measures changed in 256 state-years. [Correction evidence](docs/evidence/phase2_parser_correction.md) supersedes the earlier partial MSHA reconciliation.
- Completed development-only EDA, a model ladder, temporal final evaluation, empirical intervals, paired state bootstrap, explanatory diagnostics, influential-state checks and feature/coverage/functional-form sensitivities.
- Prepared the [model-results register](output/tables/model_results_register.csv), six figures, [data-quality report](docs/data_quality_report.md), [variable dictionary](docs/approved_variable_dictionary.csv), [forecast feasibility](docs/forecast_feasibility.md) and [reproduction instructions](docs/reproducibility.md).

## Results requiring review

Development used rolling target years 2019–2021. The selected procedure was frozen before sequential evaluation of 2022 and 2023, with 94 final observations across 47 states. Features and tuning were not changed after final scores were observed.

| Final 2022–2023 comparison | R² | RMSE, million metric tons | MAE, million metric tons |
|---|---:|---:|---:|
| Prior-year quantity baseline | 0.996854 | 2.005 | 1.204 |
| Frozen log autoregression + prior highway outlays | 0.996937 | 1.979 | 1.239 |

The aspirational R² > 0.70 target is met, but the baseline already exceeds it. The candidate improves pooled RMSE by only 1.33%, worsens MAE by 2.88%, and reverses from improvement in 2022 to deterioration in 2023. Its change-prediction R² is negative; the paired uncertainty interval for incremental RMSE spans zero. The evidence does not establish a reliable practical improvement over persistence.

The proposed explanatory log model includes state/year effects and state-clustered uncertainty. Construction GDP has a positive conditional association (coefficient 0.518; 95% interval 0.182–0.854), but the untransformed specification changes that conclusion. Interpretation must identify the functional form, residual dependence and noncausal design. No unconditional two-/three-year forecast is recommended.

## Reproducibility and remaining limitations

Run `Rscript --vanilla R/run_pipeline.R all`, then `Rscript --vanilla tests/check_pipeline.R`. Dependencies are pinned to 59 packages in `renv.lock`; additional packages were installed only into the ignored project-local library. The full rerun and Gate 2 checks are recorded in [gate_2_checks.txt](docs/evidence/gate_2_checks.txt). Reproduction on a second machine has not been tested.

The approved sample has 427 numeric targets, 419 explanatory cases and 371 lagged eligible cases. Suppressed outcomes remain missing. BLS employment covers only 36 states and remains secondary. MSHA commodity classification and its role in USGS nonrespondent estimation limit independent interpretation. National macro variables are absorbed by year effects. Source revisions and publication delays preclude claiming historically available real-time inputs.

FHWA 2015–2022 original workbook downloads still fail certificate validation. The pinned parsed archive and verified reference-year flags support offline reproduction; only the 2023 workbook was independently reconciled to its original. Fresh reacquisition of every workbook is therefore incomplete. See the [source register](docs/source_register.md).

Original parsed raw/clean/processed CSVs and report scaffolds are preserved. Prior numbered R scripts and Gate 1 README/status/dictionary are archived in `docs/evidence/`. No commits, branches, index changes, remotes, submissions or global package changes were made. The inherited `api-keys.R` remains Git-tracked; its values were not exposed in new artifacts. The owner should address it before sharing the repository, as documented in reproduction instructions.

## Decision and next authorized stage

Approve or modify the explanatory log model, the frozen predictive candidate with the naive benchmark, the no-unconditional-forecast recommendation and the bounded claims in [Decision Gate 2](docs/decision_gate_2.md). Approval authorizes report/presentation drafts and the final reproducibility review. The course milestone determines the presentation format; Meeting 1 materials must still meet its 3–5-slide/five-minute limits. Final submission requires Gate 3 approval.

Historical baseline findings, including the original CPI cleaning failure, remain in [PROJECT_STATUS_gate1.md](docs/evidence/PROJECT_STATUS_gate1.md). They describe the prior state, not the repaired pipeline.
