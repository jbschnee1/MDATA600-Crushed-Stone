# Generate the review packet directly from model outputs; no new model selection.
source('R/lib/common.R')
read_out<-function(name)read_csv(file.path('output/tables',name),show_col_types=FALSE)
selection<-readRDS('output/models/development_selection.rds')
scores<-read_out('final_model_scores.csv');dev<-read_out('development_model_scores.csv')
chosen<-filter(scores,model==selection$selected_model);naive<-filter(scores,model=='naive_prior_year')
uncertainty<-read_out('final_paired_uncertainty.csv');diagnostics<-read_out('explanatory_diagnostics.csv')
coef<-read_out('explanatory_coefficients.csv');interval<-read_out('final_interval_diagnostics.csv') |> filter(model==selection$selected_model)
years<-read_out('final_scores_by_year.csv') |> filter(model %in% c(selection$selected_model,'naive_prior_year'))
loo<-read_out('explanatory_leave_one_state_out.csv') |> group_by(term) |> summarise(minimum=min(estimate),maximum=max(estimate))
fmt<-function(x,digits=3)formatC(x,format='f',digits=digits)
model_names<-c(naive_prior_year='Prior-year quantity (naive)',state_historical_mean='Historical state mean',log_ar='Log autoregression',
 log_ar_l_permits='Log AR + prior permits',log_ar_l_highway='Log AR + prior highway outlays',log_ar_l_gdp='Log AR + prior construction GDP',
 log_lag_all='Log AR + all three prior indicators',levels_lag_all='Levels AR + all three prior indicators',state_log_lag_all='State-intercept log AR + all indicators',
 forest_m4_n5='Random forest (mtry 4, node 5)',ridge_0.01='Ridge (lambda 0.01)',sameyear_pooled_log='Same-year pooled log model',sameyear_state_log='Same-year state-intercept log model')
rows<-scores |> filter(track=='lagged')
table<-vapply(seq_len(nrow(rows)),function(i) {
 r<-rows[i,];paste0('| ',unname(model_names[r$model]),if(r$selected_before_test)' **selected in development**'else'',
 ' | ',fmt(r$r_squared,4),' | ',fmt(r$rmse/1e6),' | ',fmt(r$mae/1e6),' | ',fmt(100*r$rmse_skill,1),'% |')
},character(1))
coefficient_rows<-vapply(seq_len(nrow(coef)),function(i) {
 r<-coef[i,];label<-c(l_permits_t='Permitted housing units',l_highway_t='Highway capital outlays',l_gdp_t='Construction real GDP')[r$term]
 paste0('| ',label,' | ',fmt(r$estimate),' | [',fmt(r$lower),', ',fmt(r$upper),'] | ',fmt(r$p_value,4),' |')
},character(1))
year_rows<-vapply(seq_len(nrow(years)),function(i) {
 r<-years[i,];paste0('| ',r$year,' | ',model_names[r$model],' | ',r$n,' | ',fmt(r$rmse/1e6),' | ',fmt(r$mae/1e6),' | ',fmt(100*r$rmse_skill,1),'% |')
},character(1))
text<-c('# Decision Gate 2 - model and interpretation review','',
 '**Prepared after the approved Gate 1 design. Final model and substantive interpretation await investigator approval. No submission or final report has been produced.**','',
 paste0('The development-selected model achieved final R^2 = **',fmt(chosen$r_squared,4),'**, exceeding the aspirational 0.70 target. But the prior-year baseline achieved **',fmt(naive$r_squared,4),'**. The selected model improved pooled RMSE by only **',fmt(100*chosen$rmse_skill,2),'%**, while MAE was **',fmt(100*(chosen$mae/naive$mae-1),2),'% worse**. This is strong prediction of state production levels, not convincing evidence of a reliable improvement over persistence.'),'',
 '## Recommendations for approval','',
 '1. **Primary explanatory specification:** log quantity on log permits, log correctly dated highway outlays and log construction GDP, with state and year fixed effects and state-clustered uncertainty. Interpret the construction-GDP result as a model-specific within-state association. Retain the raw-level and influential-state sensitivities prominently; do not describe the association as causal or universally robust.',
 '2. **Primary evaluated predictive candidate:** retain the frozen log autoregression plus prior-year highway outlays as the prespecified research result, with the naive prior-year forecast as the central benchmark. Its incremental benefit is inconclusive. For practical forecasting, the evidence does not justify replacing the simpler naive benchmark. Do not promote the levels model merely because it had the lowest final-year RMSE.',
 '3. **Forecasting:** do not produce or promise an unconditional two-/three-year state forecast from this dataset. Only nine years, two final evaluation years, unstable incremental skill, current-vintage revisions, publication delays and unknown future predictors make that claim premature. No national forecasting model or expanded years were added.',
 '4. **Interpretation framework:** distinguish sold/used quantities from extraction or latent demand, association from causation, and annual prior-year information from a six-month effect. State-scale persistence explains much of the apparently excellent predictive R^2.','',
 '## Dataset and reproducibility','',
 '- 2015-2023, 50-state backbone (450 rows), no DC/territories. There are 427 published numeric targets, 419 eligible contemporaneous explanatory observations and 371 eligible lagged prediction observations. The final evaluation contains 94 observations across 47 states.',
 '- Suppressed targets remain missing. Eight FHWA older-year values are excluded from strict time-aligned features and propagate into the corresponding lag masks. CPI inflation includes the newly recovered 2014 source year.',
 '- The approved dataset has 65 columns and lives in `data/processed/approved/crushed_stone_state_year.csv`; the original 80-column panel and every original raw CSV are preserved.',
 '- All inputs are checksum-pinned. The workflow runs offline from the pinned originals and the explicitly disclosed FHWA parsed archive. Live 2015-2022 FHWA workbook retrieval still fails certificate validation; only 2023 was independently reconciled to its original workbook. This is a source-reacquisition limitation, not a hidden missing pipeline step.',
 '- The inherited MSHA quote parser merged records. The corrected parser reads all 92,000 unique mine IDs with zero parse problems; corrected activity aggregates differ in 256 state-years. These remain secondary, because MSHA hours also contribute to USGS nonrespondent estimation. See the parser correction ledger.','',
 '## Validation and model-selection record','',
 'Development used expanding training histories and target years 2019, 2020 and 2021 (137 primary validation observations). The rule selected the simplest candidate within 2% of the best pooled development RMSE. Log AR + highway reduced development RMSE by 7.69%; plain log AR was only about 2.01% worse than that best score, so the 2% threshold distinction is narrow and should not be overstated.',
 'A frozen RDS/JSON records model IDs, hyperparameters, source/data/code hashes and interval calibration. Final 2022 forecasts used training through 2021; 2023 used an unchanged refit through 2022. Features and tuning were not changed after final scores were seen. All comparison candidates below were frozen first. Same-year models are labeled separately and were not eligible to win the lagged comparison.',
 'Random forest used 500 trees and a small predeclared grid; ridge used training-standardized features and a fixed penalty grid. Log-model retransformation used training residuals only. No random row split, target imputation, test-set tuning or outcome-driven exclusion was used.',
 'These are retrospective current-vintage evaluations. They do not establish which source values were actually published at a historical forecast issue date.','',
 '## Final predictive comparison','',
 'Errors are in **million metric tons**; all lagged models use the same 94 final observations. Positive RMSE skill means improvement over the naive baseline.','',
 '| Model | R^2 | RMSE | MAE | RMSE skill |','|---|---:|---:|---:|---:|',table,'',
 '[Final RMSE comparison](../output/figures/final_model_rmse.png) | [Observed/predicted plot](../output/figures/final_observed_predicted.png) | [Complete model results register](../output/tables/model_results_register.csv)','',
 'The levels model scored better in the final years but was not the development choice. This is useful evidence of ranking instability, not a license to choose a new model using the test set. A future comparison would require new validation data or an explicitly exploratory label.','',
 '### Performance differs by year','',
 '| Year | Model | n | RMSE | MAE | RMSE skill |','|---|---|---:|---:|---:|---:|',year_rows,'',
 paste0('The selected model\'s change-prediction R^2 is **',fmt(chosen$change_r_squared),'**. High pooled level R^2 therefore does not imply accurate year-to-year changes.'),'',
 paste0('A paired state-cluster bootstrap gives selected-minus-naive RMSE difference ',fmt(uncertainty$rmse_difference/1e6),' million tons, with an approximate 95% interval [',fmt(uncertainty$rmse_difference_lower/1e6),', ',fmt(uncertainty$rmse_difference_upper/1e6),']. The interval spans zero; the improvement is not established. This resamples 47 states while retaining both final years and cannot quantify future national-shock uncertainty.'),
 paste0('Development-calibrated empirical 90% prediction intervals cover ',fmt(100*interval$coverage_90,1),'% of final observations, with mean width ',fmt(interval$mean_width/1e6),' million tons. These are approximate empirical intervals, not a formal coverage guarantee under panel dependence or future covariate change.'),'',
 '## Explanatory results','',
 'The candidate uses 419 state-years across 48 states. Coefficients are log-log associations; for small changes, a 1% predictor increase corresponds to the coefficient percent difference in quantity, conditional on the other covariates and fixed effects. This interpretation is not causal.','',
 '| Predictor | Coefficient | 95% state-clustered interval | p-value |','|---|---:|---:|---:|',coefficient_rows,'',
 paste0('The three indicators explain ',fmt(100*diagnostics$incremental_r_squared_over_state_year,1),'% of the residual log-target variation left after state/year effects, in sample. This is not held-out explanatory performance. The overall fit of ',fmt(diagnostics$overall_r_squared,4),' includes the large contribution of the fixed effects.'),
 'Construction GDP has the clearest positive association in the log specification. The permits and highway intervals include zero; lack of precision is not evidence of zero effect. In the untransformed level specification the GDP association is not supported, and permits become more prominent. Thus the substantive finding depends on whether proportional changes or absolute tonnage is the estimand.',
 '[Coefficient intervals](../output/figures/explanatory_coefficients.png) | [All explanatory sensitivities](../output/tables/explanatory_sensitivities.csv)','',
 '### Diagnostics and robustness','',
 paste0('- Adjacent-year residual correlation is ',fmt(diagnostics$adjacent_residual_correlation),'. Heteroskedasticity is also evident (nominal Breusch-Pagan p=',format(diagnostics$bp_nominal_p,scientific=TRUE,digits=3),'); its textbook p-value is only a diagnostic under panel dependence. State-clustered standard errors address within-state dependence, but nine years limit assessment of common shocks.'),
 paste0('- Maximum within-state/year residualized VIF is ',fmt(diagnostics$max_within_vif,2),'; severe multicollinearity among the three primary within-panel regressors is not indicated.'),
 '- Log construction-GDP coefficients remain positive in balanced-state, through-2021, excluding-2020, highway-component, no-highway and secondary-feature checks. Leaving one state out gives a GDP coefficient range of 0.410-0.588. The raw-level alternative changes the conclusion, so this is robustness within the log framework, not across all plausible functional forms.',
 '- Wyoming 2015 and several Alaska observations have the largest influence diagnostics. The leave-one-state-out results and development refits without the five largest production states are retained; no influential state was silently deleted.',
 '- Secondary energy, employment and mine counts did not improve development prediction over their matched naive baselines when added to the full lagged model. Additional state/local spending improved development RMSE modestly but added overlapping predictors; it was not used to retune the frozen final comparison.',
 '- Forest permutation diagnostics used held-out development years, not training impurity. Prior production dominated predictive information. Correlated features and shuffled implausible combinations limit this diagnostic; no causal importance is claimed.',
 '- Balanced-target coverage and no-FHWA alternatives are documented. No imputation sensitivity is necessary to hide missing targets: the primary policy remains no target imputation. Logs versus levels, source timing and subset coverage are explicitly compared.','',
 '## Claims supported and unsupported','',
 '**Supported for review:** state sold/used quantities are strongly persistent; a simple lagged model achieves high retrospective level R^2; highway information provides unstable and small final incremental benefit; construction GDP is positively associated with proportional within-state quantity changes in the log fixed-effects specification.',
 '**Not supported:** highway spending causes more stone production; the model directly measures latent demand or local extraction; a six-month lag is identified; the forest is superior; R^2 > 0.70 alone demonstrates useful forecast gains; a reliable unconditional 2-3-year state/national forecast is established.',
 '[AUTHOR DECISION REQUIRED] Approve or revise this interpretation in your own voice. No personal judgment, course reflection or final conclusion has been fabricated.','',
 '## Reproduce and review','',
 '```sh','Rscript --vanilla R/run_pipeline.R all','Rscript --vanilla tests/check_pipeline.R','```','',
 'Dependencies are pinned in `renv.lock`; installation/restore commands and source-cache handling are in `docs/reproducibility.md`. The all-stage command checks that an existing development selection is identical and refuses to overwrite a changed selection. This is a reproducibility rerun, not a second opportunity to tune against final results.',
 'Review [data quality](data_quality_report.md), [validation protocol](validation_protocol.md), [source register](source_register.md), [parser correction](evidence/phase2_parser_correction.md) and the generated tables/figures. Report/presentation production remains after Gate 2. The full report must be ready before Meeting 3.','',
 '## Decision requested','',
 '**Approve or modify the explanatory model, the frozen predictive candidate with its naive benchmark, the no-unconditional-forecast recommendation, and the bounded interpretation above.** Approval authorizes evidence-grounded report/presentation drafts and the final reproducibility review, not submission. If you prefer the simpler naive model as the practical primary forecast, retain the frozen candidate comparison transparently; do not claim that a post-test choice was independently validated.')
write_lines(text,'docs/decision_gate_2.md')
write_lines(c('# Forecast feasibility','',
 'Recommendation: do not produce an unconditional 2-3-year forecast from this analysis.',
 'Nine annual years and only two final evaluation years offer little evidence about multi-year performance.',
 'The frozen candidate has unstable improvement over the prior-year baseline and negative final change-prediction R^2.',
 'Future permits, expenditure, GDP and their release dates are unspecified. Current-vintage data do not recreate historical issue-date information.',
 'As of September 2026, projections for 2024-2026 from a 2023 cutoff would be historical exercises, not an unconditional future forecast.',
 'National forecasting would require a separately approved design using the published national target; observed-state sums omit withheld quantities.',
 'A scenario projection could be explored only with explicit predictor assumptions, horizon backtesting and scope approval. None was fabricated.'),'docs/forecast_feasibility.md')
message('Gate 2 review packet generated from completed model tables.')
