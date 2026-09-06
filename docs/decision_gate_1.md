# Decision Gate 1 — scope and research design

Prepared 2026-09-06. **Approved by the investigator on 2026-09-06 (reply: “i approve”).** The recommended three-predictor design is authorized; final model and interpretation approval remain at Gate 2. The course guide was read completely and agrees with the execution brief. No model fitting or outcome-based model selection has taken place. Personal research ownership, interpretation and scope approval remain with the investigator.

## Recommended questions

1. **Explanation:** During 2015–2023, how is within-state variation in USGS crushed-stone quantities sold or used associated with residential units authorized, highway capital outlays and construction-sector real GDP, after controlling for persistent state differences and common year effects?
2. **Prior-year information:** For eligible 2016–2023 state-years, do the prior year's permits, correctly dated highway outlays and construction GDP improve prediction beyond prior-year crushed-stone quantities alone, and which additions show stable benefit in the predeclared development folds?
3. **Prediction:** How accurately do the selected models trained on earlier years predict observed state-level quantities in 2022 and 2023, measured by R², RMSE, MAE and improvement over prior-year production on identical eligible observations?

Question 1 concerns conditional associations. Questions 2–3 concern prediction. None measures latent demand directly or identifies a causal effect. The aspirational R² > 0.70 remains a target, not a promised result. High pooled R² may mostly reflect state scale; also report performance on changes/within-state deviations and by evaluation year.

## Scope, target and features

| Recommendation | Evidence and tradeoff | Consequence |
|---|---|---|
| Keep 2015–2023 and a 50-state backbone; no DC/territories | Current 450-row panel and verified source coverage; expansion to 2012/latest is not authorized | Retains project window; only nine annual observations per state |
| Use available published targets; no target imputation | USGS has 427 numeric targets; 23 `W` tokens, concentrated in three states | Analytical target coverage is 48 states, with 47 complete histories; no observed-target prediction claims for DE/LA |
| Target: USGS Table 2/state totals, Commodity `Stone, crushed`, Quantity, **metric tons sold or used** | Workbook and embedded instructions verified; stockpiles excluded, geography is first sale/use and may include incoming interstate/imported material | Rename derived target `crushed_stone_sold_used_metric_tons`; retain original field unchanged in raw archive. This is a definition correction requiring explicit approval, not a switch to demand |
| Primary predictors: total permitted housing units; FHWA capital outlay total; BEA construction real GDP | Complete numeric coverage; distinct residential, highway and sector-activity dimensions | Three substantive predictors limit redundancy; annual associations only |
| Treat FHWA's eight older-year entries as missing for strict timing analysis | Official year-table footnotes identify actual reported years; state-name repair hid the issue | Proposed contemporaneous sample: 419. Prior-year target/predictor sample: 371 in 2016–2023, before any later QC exclusions |
| Prior-year target is a predictive baseline/input, not a primary explanatory control | All 379 observed targets in 2016–2023 have an observed prior target; FHWA eligibility removes eight | Compare baseline and enhanced models on the same 371 rows; do not impose lagged-target dynamic-panel interpretation on the explanatory model |

Housing units = `units_1unit + units_2unit + units_34unit + units_5punit`, using Census estimates including imputation. Do not add reported-only (`_rep`) counts to these totals. FHWA total is thousands of nominal dollars before any deflation; BEA construction is millions of chained 2017 dollars (SAGDP9, LineCode 11). Proposed feature names and transformations are in the dictionary.

Recommend logs for positive target and primary level predictors, with metrics converted back to metric tons and retransformation handled from training data. This is a proposed transformation, to be checked in EDA after approval. Keep an untransformed sensitivity analysis. For cross-year monetary comparisons, use CPI-based constant 2017 dollars as a transparent general purchasing-power adjustment, clearly not a highway-specific construction volume index. With log predictors and year fixed effects, a common annual deflator is absorbed by the year effects. Predictive preprocessing and any transformation estimates must be fitted on training data only.

**Secondary feature set:** one EIA cost measure at a time (prefer total industrial energy price; distillate as substitution); Census private nonresidential or state/local spending as substitutions for overlapping activity measures; BLS heavy/civil employment on its documented subset; total real GDP or personal income as alternative scale controls. Lagged MSHA active-mine counts may enter a clearly labeled sensitivity analysis; hours require an explicit warning about USGS estimation dependence. National mortgage rates/inflation are contextual or predictive alternatives only, never alongside a complete year-effects set in an explanatory coefficient interpretation.

**Drop from candidate predictor inputs:** same-year USGS total value and unit value (linked arithmetically to the target); duplicate MSHA operations count (equals active-mine count in the existing construction); redundant permit totals/components/reported-only counts in a single specification; simultaneous total energy price and every energy component; geographic labels redundant with state effects. Retain these fields in documented source storage. Do not replace unavailable heavy/civil employment with broader construction employment without documenting a changed feature definition.

## Temporal design and forecasting

Annual data support an association with the **previous calendar/source year**. They cannot identify a six-month response. FHWA values with older reporting years do not become valid one-year lags merely because their table is labeled `t−1`.

- Development: expanding-window validation for target years **2019, 2020 and 2021**, using only earlier target years in each fit. Lagged models first have usable target years in 2016; contemporaneous explanation can start in 2015. Freeze features, tuning choices, preprocessing, missingness rules and scoring before final evaluation.
- Final evaluation: **2022 and 2023** (47 observed targets each, 94 total under currently documented strict eligibility). Use two predeclared one-year steps: train through 2021 for 2022, then refit the unchanged procedure through 2022 for 2023. Do not tune after inspecting 2022 results. This is sequential one-year evaluation, not a two-year fixed-origin forecast.
- Same-year covariates give retrospective conditional prediction/nowcasting after data publication. Prior-year variables improve chronological separation, but present-day revised series and release delays still make these **retrospective pseudo-out-of-time evaluations**, not proven real-time forecasts. Before operational claims, specify the prediction issue date and verify actual source release/vintage availability.
- Explanation: proposed state and year fixed effects, state-clustered uncertainty, with explicit residual/dependence and influential-state checks. Nine years make year-cluster inference fragile. Prediction: naive prior-year baseline, simple regression, then regularization/tree comparison only if honest development validation justifies complexity. Future year dummy coefficients cannot be extrapolated; the predictive specification must not require unseen year levels.
- Forecasting is **optional feasibility work**, not a promised fourth research question or deliverable. Two-/three-year projections need future predictor assumptions, release-aware inputs, temporal backtests and uncertainty. A 2024–2026 exercise based on a 2023 cutoff is historical/hindcast work as of September 2026, not an unconditional forecast of the future. Extending the data window for a genuinely future forecast requires approval. National projection would also require the independently published national target, not the sum of 47 observed states.

## Strongest credible alternative

**Use permits and construction GDP as the two primary indicators; make FHWA a secondary analysis.** This supports the same 2015–2023 backbone, 427 observed contemporaneous outcomes and 379 prior-target comparisons, avoids dependence on the eight misdated outlays and the unresolved older FHWA workbook downloads, and is simpler to reproduce. The cost is a less direct test of highway investment, an important motivation for crushed-stone activity. Choose this alternative if schedule pressure or unresolved FHWA source reconciliation makes the three-indicator design impractical. It is not a route to a better-looking score.

A balanced 47-state target panel (423 observations before FHWA exclusions) is an additional coverage sensitivity, not the recommended main sample: it discards Nebraska's four usable early observations and still does not represent all 50 states. Never choose the sample using model performance.

## Course preparation

For Meeting 1, after scope approval, use four slides totaling about **4:30**: (1) specific target and three questions, 0:55; (2) verified sources, units and actual coverage, 1:15; (3) explanatory/predictive methods and time split, 1:20; (4) deliverables, suppression/timing risks and next milestone, 1:00. Include no generic industry history. This is a content outline, not a finished slide deck. The brief places presentation production after the modeling gates; a Meeting 1 deck would need to be prepared earlier if that is the current milestone. No slide artifact was silently substituted for the report/presentation phase.

Scope changes must be settled at Meeting 2; a fully written report must exist before Meeting 3. The current proposal, professor feedback and actual meeting stage remain unavailable. If Meeting 2 has already locked scope, any proposed change here must first be reconciled with that approved scope.

## Investigator decision

**Approve or modify:** the three questions; 2015–2023 window and available-target coverage; precise sold/used target wording; three primary predictors and strict FHWA exclusion rule (or the two-predictor alternative); annual prior-year claims; temporal evaluation; secondary-feature limits; and optional-only forecasting. Please also identify whether scope has already been locked at Meeting 2. Approval authorizes Phase 2 pipeline implementation, not a final model or substantive conclusion.

Evidence: [status](../PROJECT_STATUS.md), [source register](source_register.md), [data dictionary](data_dictionary.md), [methodology decisions](methodology_decisions.md), [source comparison](evidence/source_comparison.csv), [coverage matrix](evidence/state_year_coverage.csv).
