# Decision Gate 2 - model and interpretation review

**Prepared after the approved Gate 1 design. Final model and substantive interpretation await investigator approval. No submission or final report has been produced.**

The development-selected model achieved final R^2 = **0.9969**, exceeding the aspirational 0.70 target. But the prior-year baseline achieved **0.9969**. The selected model improved pooled RMSE by only **1.33%**, while MAE was **2.88% worse**. This is strong prediction of state production levels, not convincing evidence of a reliable improvement over persistence.

## Recommendations for approval

1. **Primary explanatory specification:** log quantity on log permits, log correctly dated highway outlays and log construction GDP, with state and year fixed effects and state-clustered uncertainty. Interpret the construction-GDP result as a model-specific within-state association. Retain the raw-level and influential-state sensitivities prominently; do not describe the association as causal or universally robust.
2. **Primary evaluated predictive candidate:** retain the frozen log autoregression plus prior-year highway outlays as the prespecified research result, with the naive prior-year forecast as the central benchmark. Its incremental benefit is inconclusive. For practical forecasting, the evidence does not justify replacing the simpler naive benchmark. Do not promote the levels model merely because it had the lowest final-year RMSE.
3. **Forecasting:** do not produce or promise an unconditional two-/three-year state forecast from this dataset. Only nine years, two final evaluation years, unstable incremental skill, current-vintage revisions, publication delays and unknown future predictors make that claim premature. No national forecasting model or expanded years were added.
4. **Interpretation framework:** distinguish sold/used quantities from extraction or latent demand, association from causation, and annual prior-year information from a six-month effect. State-scale persistence explains much of the apparently excellent predictive R^2.

## Dataset and reproducibility

- 2015-2023, 50-state backbone (450 rows), no DC/territories. There are 427 published numeric targets, 419 eligible contemporaneous explanatory observations and 371 eligible lagged prediction observations. The final evaluation contains 94 observations across 47 states.
- Suppressed targets remain missing. Eight FHWA older-year values are excluded from strict time-aligned features and propagate into the corresponding lag masks. CPI inflation includes the newly recovered 2014 source year.
- The approved dataset has 65 columns and lives in `data/processed/approved/crushed_stone_state_year.csv`; the original 80-column panel and every original raw CSV are preserved.
- All inputs are checksum-pinned. The workflow runs offline from the pinned originals and the explicitly disclosed FHWA parsed archive. Live 2015-2022 FHWA workbook retrieval still fails certificate validation; only 2023 was independently reconciled to its original workbook. This is a source-reacquisition limitation, not a hidden missing pipeline step.
- The inherited MSHA quote parser merged records. The corrected parser reads all 92,000 unique mine IDs with zero parse problems; corrected activity aggregates differ in 256 state-years. These remain secondary, because MSHA hours also contribute to USGS nonrespondent estimation. See the parser correction ledger.

## Validation and model-selection record

Development used expanding training histories and target years 2019, 2020 and 2021 (137 primary validation observations). The rule selected the simplest candidate within 2% of the best pooled development RMSE. Log AR + highway reduced development RMSE by 7.69%; plain log AR was only about 2.01% worse than that best score, so the 2% threshold distinction is narrow and should not be overstated.
A frozen RDS/JSON records model IDs, hyperparameters, source/data/code hashes and interval calibration. Final 2022 forecasts used training through 2021; 2023 used an unchanged refit through 2022. Features and tuning were not changed after final scores were seen. All comparison candidates below were frozen first. Same-year models are labeled separately and were not eligible to win the lagged comparison.
Random forest used 500 trees and a small predeclared grid; ridge used training-standardized features and a fixed penalty grid. Log-model retransformation used training residuals only. No random row split, target imputation, test-set tuning or outcome-driven exclusion was used.
These are retrospective current-vintage evaluations. They do not establish which source values were actually published at a historical forecast issue date.

## Final predictive comparison

Errors are in **million metric tons**; all lagged models use the same 94 final observations. Positive RMSE skill means improvement over the naive baseline.

| Model | R^2 | RMSE | MAE | RMSE skill |
|---|---:|---:|---:|---:|
| Random forest (mtry 4, node 5) | 0.9910 | 3.392 | 1.663 | -69.2% |
| Levels AR + all three prior indicators | 0.9975 | 1.787 | 1.200 | 10.9% |
| Log autoregression | 0.9970 | 1.967 | 1.192 | 1.9% |
| Log AR + prior construction GDP | 0.9969 | 1.974 | 1.174 | 1.5% |
| Log AR + prior highway outlays **selected in development** | 0.9969 | 1.979 | 1.239 | 1.3% |
| Log AR + prior permits | 0.9963 | 2.186 | 1.235 | -9.0% |
| Log AR + all three prior indicators | 0.9961 | 2.222 | 1.307 | -10.8% |
| Prior-year quantity (naive) | 0.9969 | 2.005 | 1.204 | 0.0% |
| Ridge (lambda 0.01) | 0.9961 | 2.221 | 1.307 | -10.8% |
| Historical state mean | 0.9749 | 5.665 | 3.109 | -182.5% |
| State-intercept log AR + all indicators | 0.9964 | 2.156 | 1.311 | -7.5% |

[Final RMSE comparison](../output/figures/final_model_rmse.png) | [Observed/predicted plot](../output/figures/final_observed_predicted.png) | [Complete model results register](../output/tables/model_results_register.csv)

The levels model scored better in the final years but was not the development choice. This is useful evidence of ranking instability, not a license to choose a new model using the test set. A future comparison would require new validation data or an explicitly exploratory label.

### Performance differs by year

| Year | Model | n | RMSE | MAE | RMSE skill |
|---|---|---:|---:|---:|---:|
| 2022 | Log AR + prior highway outlays | 47 | 1.818 | 1.148 | 23.7% |
| 2023 | Log AR + prior highway outlays | 47 | 2.127 | 1.330 | -38.3% |
| 2022 | Prior-year quantity (naive) | 47 | 2.383 | 1.322 | 0.0% |
| 2023 | Prior-year quantity (naive) | 47 | 1.538 | 1.087 | 0.0% |

The selected model's change-prediction R^2 is **-0.030**. High pooled level R^2 therefore does not imply accurate year-to-year changes.

A paired state-cluster bootstrap gives selected-minus-naive RMSE difference -0.027 million tons, with an approximate 95% interval [-0.468, 0.561]. The interval spans zero; the improvement is not established. This resamples 47 states while retaining both final years and cannot quantify future national-shock uncertainty.
Development-calibrated empirical 90% prediction intervals cover 92.6% of final observations, with mean width 9.005 million tons. These are approximate empirical intervals, not a formal coverage guarantee under panel dependence or future covariate change.

## Explanatory results

The candidate uses 419 state-years across 48 states. Coefficients are log-log associations; for small changes, a 1% predictor increase corresponds to the coefficient percent difference in quantity, conditional on the other covariates and fixed effects. This interpretation is not causal.

| Predictor | Coefficient | 95% state-clustered interval | p-value |
|---|---:|---:|---:|
| Permitted housing units | 0.192 | [-0.061, 0.444] | 0.1335 |
| Highway capital outlays | 0.039 | [-0.047, 0.125] | 0.3634 |
| Construction real GDP | 0.518 | [0.182, 0.854] | 0.0032 |

The three indicators explain 28.6% of the residual log-target variation left after state/year effects, in sample. This is not held-out explanatory performance. The overall fit of 0.9946 includes the large contribution of the fixed effects.
Construction GDP has the clearest positive association in the log specification. The permits and highway intervals include zero; lack of precision is not evidence of zero effect. In the untransformed level specification the GDP association is not supported, and permits become more prominent. Thus the substantive finding depends on whether proportional changes or absolute tonnage is the estimand.
[Coefficient intervals](../output/figures/explanatory_coefficients.png) | [All explanatory sensitivities](../output/tables/explanatory_sensitivities.csv)

### Diagnostics and robustness

- Adjacent-year residual correlation is 0.477. Heteroskedasticity is also evident (nominal Breusch-Pagan p=2.29e-18); its textbook p-value is only a diagnostic under panel dependence. State-clustered standard errors address within-state dependence, but nine years limit assessment of common shocks.
- Maximum within-state/year residualized VIF is 1.28; severe multicollinearity among the three primary within-panel regressors is not indicated.
- Log construction-GDP coefficients remain positive in balanced-state, through-2021, excluding-2020, highway-component, no-highway and secondary-feature checks. Leaving one state out gives a GDP coefficient range of 0.410-0.588. The raw-level alternative changes the conclusion, so this is robustness within the log framework, not across all plausible functional forms.
- Wyoming 2015 and several Alaska observations have the largest influence diagnostics. The leave-one-state-out results and development refits without the five largest production states are retained; no influential state was silently deleted.
- Secondary energy, employment and mine counts did not improve development prediction over their matched naive baselines when added to the full lagged model. Additional state/local spending improved development RMSE modestly but added overlapping predictors; it was not used to retune the frozen final comparison.
- Forest permutation diagnostics used held-out development years, not training impurity. Prior production dominated predictive information. Correlated features and shuffled implausible combinations limit this diagnostic; no causal importance is claimed.
- Balanced-target coverage and no-FHWA alternatives are documented. No imputation sensitivity is necessary to hide missing targets: the primary policy remains no target imputation. Logs versus levels, source timing and subset coverage are explicitly compared.

## Claims supported and unsupported

**Supported for review:** state sold/used quantities are strongly persistent; a simple lagged model achieves high retrospective level R^2; highway information provides unstable and small final incremental benefit; construction GDP is positively associated with proportional within-state quantity changes in the log fixed-effects specification.
**Not supported:** highway spending causes more stone production; the model directly measures latent demand or local extraction; a six-month lag is identified; the forest is superior; R^2 > 0.70 alone demonstrates useful forecast gains; a reliable unconditional 2-3-year state/national forecast is established.
[AUTHOR DECISION REQUIRED] Approve or revise this interpretation in your own voice. No personal judgment, course reflection or final conclusion has been fabricated.

## Reproduce and review

```sh
Rscript --vanilla R/run_pipeline.R all
Rscript --vanilla tests/check_pipeline.R
```

Dependencies are pinned in `renv.lock`; installation/restore commands and source-cache handling are in `docs/reproducibility.md`. The all-stage command checks that an existing development selection is identical and refuses to overwrite a changed selection. This is a reproducibility rerun, not a second opportunity to tune against final results.
Review [data quality](data_quality_report.md), [validation protocol](validation_protocol.md), [source register](source_register.md), [parser correction](evidence/phase2_parser_correction.md) and the generated tables/figures. Report/presentation production remains after Gate 2. The full report must be ready before Meeting 3.

## Decision requested

**Approve or modify the explanatory model, the frozen predictive candidate with its naive benchmark, the no-unconditional-forecast recommendation, and the bounded interpretation above.** Approval authorizes evidence-grounded report/presentation drafts and the final reproducibility review, not submission. If you prefer the simpler naive model as the practical primary forecast, retain the frozen candidate comparison transparently; do not claim that a post-test choice was independently validated.
