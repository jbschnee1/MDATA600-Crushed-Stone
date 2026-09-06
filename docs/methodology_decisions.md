# Methodology and decision log

Updated 2026-09-06. Status terminology: **implemented** = completed work; **approved** = Gate 1 design authorization; **pending** = investigator decision or information required. Gate 1 research questions and recommended scope were approved on 2026-09-06; no final model, interpretation or submission is approved.

| ID | Status | Decision / evidence / implication |
|---|---|---|
| A01 | Implemented | Read full execution brief, all existing R/README/report scaffolds and data schemas/records; read supplied course guide including tables. No conflicting course requirement found. Proposal/feedback/meeting dates unavailable. |
| A02 | Implemented | Preserve original files and Git state; temporary-copy baseline only. Existing data hashes unchanged. No commits/branches/remotes/index mutations. Use existing layout, adding audit documentation and isolated source snapshots. |
| A03 | Implemented | Run parse/dependency checks and isolated clean/join. Clean fails for missing 2014 CPI; join succeeds from cached clean files and matches stored panel. Do not equate the latter with an end-to-end pass. |
| A04 | Implemented | Verify all candidate sources using originals/API responses where obtainable and official documentation. FHWA 2023 workbook obtained; older binaries fail TLS verification. Existing data preserved, no insecure TLS bypass, exact attempts retained. |
| A05 | Implemented | Source access probes use existing credentials only for their intended publishers, save no request envelopes, and sanitize error messages. Tracked literal credentials identified without disclosure. Ignore rules added but cannot untrack existing file; no history rewriting. |
| D01 | Approved at Gate 1 | Keep 2015–2023 50-state backbone. Available targets yield 427 cases/48 states; 47-state balanced sensitivity yields 423. No 2012/latest expansion. |
| D02 | Approved at Gate 1 | Specify target as metric tons sold/used by state of first sale/use, potentially including imports/interstate receipts; exclude stockpiles. Exact USGS metadata corrects ambiguous `tons`/extraction language. Do not relabel as demand. |
| D03 | Approved at Gate 1 | Adopt three questions in Gate packet, separating state/year-adjusted association, incremental prior-year prediction and held-out-year accuracy. No causal claim or six-month lag claim. |
| D04 | Approved at Gate 1 | Primary permits + FHWA total + BEA construction GDP. No target-value/price predictors. Exclude eight FHWA older-year entries from strict timing, reducing contemporaneous sample to 419 and lagged sample to 371. These counts define eligibility; final model sample sizes are recorded separately in the results register. |
| D05 | Approved at Gate 1 | Preserve withholding (`W`), reported-year flags and Census imputation status; no zero-filling of suppressed outcomes. Zero-completed MSHA records receive explicit provenance. No outcome-driven exclusions or interpolation. |
| D06 | Approved at Gate 1 | BLS secondary due to 36-state availability. MSHA secondary due to classification/coverage assumptions and USGS estimation dependence. EIA/Census macro alternatives should earn inclusion without redundant measures. National time-only variables cannot be identified alongside complete year effects. |
| D07 | Approved at Gate 1 | Log-level explanatory design with state/year effects and state-clustered uncertainty approved; implemented with diagnostics. Development selection and final model recommendation are recorded below. Do not include unseen future-year dummy levels in prediction. |
| D08 | Approved at Gate 1 | Develop with rolling target years 2019–2021; freeze procedure; evaluate 2022 then 2023 by a predeclared sequential refit. Compare R²/RMSE/MAE and naive-baseline skill on identical rows. Do not tune on final years. |
| D09 | Approved at Gate 1 | At Gate 1, all-data QC inspected target availability/source equality, not fitted-model performance. Subsequent model selection used development years only and final temporal evaluation followed a frozen procedure. No random row split was used. All source revisions are current-vintage; historical timing alone does not make real-time forecasting valid. |
| D10 | Approved at Gate 1 | Prior-year effects only; exact-year lag assertions. Historical source publication delays and FHWA reference-year mismatch explicitly matter. CPI support year can repair inflation without adding a new target year. No 2014 target/predictor extension has been assumed. |
| D11 | Approved at Gate 1 | General CPI constant-2017 monetary adjustment may be used with proper label; construction GDP is already chained real. Common annual log deflation is absorbed in a year-effects model. A highway-specific deflator would be a separately documented feature choice. |
| D12 | Approved at Gate 1 | Forecasting optional feasibility only. Nine years plus unavailable future covariates do not justify promising a 2–3-year state forecast. As of September 2026, 2024–2026 from a 2023 cutoff is historical projection work; future scope requires approval. |
| D13 | Documented alternative; not selected | Strong alternative uses permits/construction GDP as primary, FHWA secondary: 427 contemporaneous /379 lagged eligible cases; simpler but weaker highway-specific coverage. Do not choose alternative based on test scores. |
| D14 | Pending investigator information | Course guide now supplied and reconciled. Actual current meeting milestone and any already-approved proposal/feedback remain unknown. If Meeting 2 passed, scope cannot be changed without addressing the course prohibition. |
| P01 | Implemented after Gate 1 | Built immutable source snapshots, relative paths, CPI support year, FHWA timing flags, canonical units, exact-year joins and a quality report in R. Local dependency library and valid 59-package lockfile added. Original scripts/data preserved. |
| P02 | Analysis completed; Gate 2 pending | EDA, modeling ladder, temporal evaluation, diagnostics and sensitivities completed. Gate 2 packet prepared. Report/presentation drafting follows approval; course presentation format still depends on the actual milestone. |

## Gate record

Gate 1: **approved 2026-09-06**, investigator reply: “i approve”. Proceed with the recommended three-predictor design (not the simpler alternative). No scope modifications requested. Current course-meeting stage remains undocumented; approval is sufficient to continue the authorized work. Gate 2 and Gate 3 remain pending.

## Post-approval implementation and analytical record

| ID | Status | Decision / evidence / implication |
|---|---|---|
| I01 | Implemented | Pin 27 inputs; retain older FHWA parsed archive with verified timing flags and explicit fresh-download limitation. No source-vintage change during modeling. |
| I02 | Implemented correction | Repair MSHA literal-pipe parsing and strip outer quotes from analytical fields. All 92,000 unique mine IDs parse; 256 state-year aggregates change. Preliminary development artifacts were archived and regenerated before final evaluation; this did not change primary predictors. See parser correction ledger. |
| I03 | Implemented | Use no project target imputation. Retain 450 backbone rows with eligibility flags, 419 explanatory/371 lagged cases, and 94 identical final observations per primary benchmark. |
| M01 | Implemented before final evaluation | Freeze candidate grid, temporal splits and simplest-within-2%-of-best-development-RMSE rule in validation protocol. Select log autoregression plus prior highway outlays using 2019–2021 only. Plain autoregression falls narrowly outside the threshold; acknowledge selection fragility. |
| M02 | Implemented | Sequential 2022/2023 evaluation uses training through each preceding year. All feature preparation/retransformation/calibration uses training or development data. Tests reject future training and confirm prediction invariance to held-out outcomes. |
| M03 | Implemented | Report original-ton R², RMSE, MAE, naive-baseline skill and change-prediction R². Approximate empirical intervals use development errors; paired state bootstrap retains both final years. Do not infer future national-shock coverage. |
| M04 | Implemented | Explanatory log state/year effects with state-clustered HC1 uncertainty; retain raw levels, balanced/no-FHWA coverage, alternate features, leave-state-out and diagnostic results. Common annual deflation equivalence checked for the log year-effects specification. |
| M05 | Recommendation pending Gate 2 | Retain the frozen candidate as the evaluated research model and prior-year quantity as the central practical benchmark. Final improvement is small, uncertain and unstable; do not promote the test-best levels model as independently validated. |
| M06 | Interpretation pending Gate 2 | Construction GDP has a positive conditional association within the log framework, but raw-level results differ. No causal, direct-demand or six-month-effect claim. High level R² does not establish accurate changes or incremental forecast value. |
| M07 | Recommendation pending Gate 2 | Do not produce an unconditional 2–3-year forecast; nine years, two final test years, future predictor requirements and current-vintage publication timing do not support it. |
| Q01 | Implemented presentation correction | Final visual review found locale-dependent punctuation artifacts. Generated documentation uses portable punctuation and charts use readable labels. No features, model selection or numerical calculations changed after final evaluation. |

Gate 2: **prepared; awaiting approval** of the model and interpretation framework in `docs/decision_gate_2.md`. Gate 3 remains pending. No report, presentation, upload or submission is represented as completed.
