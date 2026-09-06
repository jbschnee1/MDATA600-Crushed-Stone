# Development comparisons and an immutable selection record, before final evaluation.
source('R/lib/modeling.R')
d<-make_model_data(read_panel()) |> filter(year<=2021)
specs<-candidate_specs()
predictions<-map_dfr(specs,function(spec)rolling_predict(d,spec,development_years))
write_table(predictions,'development_predictions.csv')
scores<-score_predictions(predictions)
meta<-map_dfr(specs,function(s)tibble(model=s$id,complexity=s$complexity,kind=s$kind))
scores<-left_join(scores,meta,by='model')
write_table(arrange(scores,track,rmse),'development_model_scores.csv')
write_table(score_predictions(predictions,TRUE),'development_scores_by_year.csv')
primary_scores<-filter(scores,track=='lagged')
best_rmse<-min(primary_scores$rmse)
selected<-primary_scores |> filter(rmse<=best_rmse*1.02) |> arrange(complexity,rmse,model) |> slice(1)
family_winners<-primary_scores |> group_by(kind) |> arrange(rmse,model,.by_group=TRUE) |> slice(1) |> ungroup()
# All simple candidates plus one frozen setting for each tuned model family.
benchmark_ids<-c(names(Filter(function(s)!s$kind %in% c('forest','ridge'),specs)),filter(family_winners,kind %in% c('forest','ridge'))$model)
calibration<-predictions |> filter(model %in% benchmark_ids,predicted>0) |> group_by(model) |>
 summarise(log_ratio_q05=quantile(log(actual/predicted),.05),log_ratio_q95=quantile(log(actual/predicted),.95),n=n())
write_table(calibration,'development_interval_calibration.csv')
selection<-list(protocol_sha256=sha256('docs/validation_protocol.md'),source_manifest_sha256=sha256('docs/source_manifest.csv'),
 panel_sha256=sha256('data/processed/approved/crushed_stone_state_year.csv'),modeling_code_sha256=sha256('R/lib/modeling.R'),
 development_code_sha256=sha256('R/05_models.R'),selected_model=selected$model,best_development_rmse=best_rmse,
 selected_development_rmse=selected$rmse,selection_rule='simplest within 2 percent of minimum pooled development RMSE',
 development_target_years=development_years,final_target_years=test_years,seed=seed,
 benchmark_ids=benchmark_ids,specs=specs[benchmark_ids],calibration=calibration)
path<-'output/models/development_selection.rds'
if(file.exists(path)) {
 old<-readRDS(path)
 if(!identical(old,selection)) stop('Existing selection differs. Do not overwrite after final evaluation; review reason and preserve earlier record.')
} else saveRDS(selection,path,version=3)
write_json(selection,'output/models/development_selection.json',pretty=TRUE,auto_unbox=TRUE)
# Secondary analyses stay in development folds, with subset-specific baselines.
secondary<-list()
for(f in c('l_energy','l_bls','l_mines','l_private','l_public')) {
 spec<-list(id=paste0('secondary_',f),kind='log_lm',features=c(core_features,f),complexity=5,track='lagged')
 pr<-rolling_predict(d,spec,development_years)
 secondary[[f]]<-bind_cols(tibble(feature=f),score(pr$actual,pr$predicted,pr$naive),tibble(naive_rmse=sqrt(mean((pr$actual-pr$naive)^2)),states=n_distinct(pr$state_fips)))
}
write_table(bind_rows(secondary),'development_secondary_sensitivity.csv')
# Predeclared coverage sensitivity: remove FHWA requirement and predictor together.
alt<-d |> mutate(eligible_prediction=target_observed & !is.na(lag_y))
alt_spec<-list(id='alternative_without_highway',kind='log_lm',features=c('l_lag_y','l_permits','l_gdp'),complexity=4,track='lagged')
a<-rolling_predict(alt,alt_spec,development_years)
write_table(bind_cols(tibble(model=alt_spec$id),score(a$actual,a$predicted,a$naive)),'development_coverage_alternative.csv')
message('DEVELOPMENT FROZEN: ',selected$model,'; final years have not been scored by this stage.')
