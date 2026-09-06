# Frozen final evaluation. No selection or tuning in this script.
source('R/lib/modeling.R')
selection<-readRDS('output/models/development_selection.rds')
stopifnot(selection$protocol_sha256==sha256('docs/validation_protocol.md'),
 selection$panel_sha256==sha256('data/processed/approved/crushed_stone_state_year.csv'),
 selection$modeling_code_sha256==sha256('R/lib/modeling.R'),selection$development_code_sha256==sha256('R/05_models.R'))
d<-make_model_data(read_panel())
predictions<-map_dfr(selection$specs,function(spec)rolling_predict(d,spec,test_years))
stopifnot(all(predictions$train_max_year==predictions$year-1),all(predictions$year %in% test_years))
counts<-count(predictions,model);stopifnot(all(counts$n==94))
predictions<-left_join(predictions,select(selection$calibration,-n),by='model',relationship='many-to-one') |>
 mutate(lower_90=predicted*exp(log_ratio_q05),upper_90=predicted*exp(log_ratio_q95),selected_before_test=model==selection$selected_model)
write_table(predictions,'final_predictions.csv')
scores<-score_predictions(predictions) |> mutate(selected_before_test=model==selection$selected_model)
write_table(scores,'final_model_scores.csv')
write_table(score_predictions(predictions,TRUE),'final_scores_by_year.csv')
intervals<-predictions |> group_by(model) |> summarise(n=n(),coverage_90=mean(actual>=lower_90 & actual<=upper_90),mean_width=mean(upper_90-lower_90))
write_table(intervals,'final_interval_diagnostics.csv')
centered<-predictions |> group_by(model) |> summarise(
 centered_r_squared=1-sum((actual-predicted)^2)/sum(((actual-training_state_mean)-mean(actual-training_state_mean))^2),
 mean_absolute_percentage_error=mean(abs((actual-predicted)/actual)),
 median_absolute_percentage_error=median(abs((actual-predicted)/actual)))
write_table(centered,'final_scale_diagnostics.csv')
write_table(predictions |> group_by(model,state_fips,state) |> summarise(n=n(),rmse=sqrt(mean((actual-predicted)^2)),mae=mean(abs(actual-predicted)),naive_rmse=sqrt(mean((actual-naive)^2))),'final_scores_by_state.csv')
selected<-filter(predictions,model==selection$selected_model)
# Paired state-cluster resampling preserves each state's two final years.
set.seed(seed)
states<-sort(unique(selected$state_fips))
boot<-map_dfr(seq_len(500),function(b) {
 sampled<-sample(states,length(states),replace=TRUE)
 rows<-unlist(lapply(sampled,function(s)which(selected$state_fips==s)))
 a<-selected[rows,]
 tibble(draw=b,rmse_difference=sqrt(mean((a$actual-a$predicted)^2))-sqrt(mean((a$actual-a$naive)^2)),
 mae_difference=mean(abs(a$actual-a$predicted))-mean(abs(a$actual-a$naive)))
})
write_table(boot,'final_paired_state_bootstrap.csv')
write_table(tibble(model=selection$selected_model,states=length(states),bootstrap_draws=500,
 rmse_difference=sqrt(mean((selected$actual-selected$predicted)^2))-sqrt(mean((selected$actual-selected$naive)^2)),
 rmse_difference_lower=quantile(boot$rmse_difference,.025),rmse_difference_upper=quantile(boot$rmse_difference,.975),
 mae_difference=mean(abs(selected$actual-selected$predicted))-mean(abs(selected$actual-selected$naive)),
 mae_difference_lower=quantile(boot$mae_difference,.025),mae_difference_upper=quantile(boot$mae_difference,.975)),
 'final_paired_uncertainty.csv')
# Save the selected candidate's exact final-fold fitted object for audit, not deployment.
spec<-selection$specs[[selection$selected_model]]
train<-filter(d,eligible_prediction,year<=2022);new<-filter(d,eligible_prediction,year==2023)
fit<-fit_predict(train,new,spec,history=filter(d,year<=2022,target_observed),return_model=TRUE)
saveRDS(list(spec=spec,fit=fit,training_years=sort(unique(train$year)),selection_sha256=sha256('output/models/development_selection.rds')),
 'output/models/selected_candidate_2023_fold.rds',version=3)
results_meta<-map_dfr(selection$specs,function(s)tibble(model=s$id,feature_set=paste(s$features,collapse=' + '),
 kind=s$kind,hyperparameters=as.character(toJSON(s,auto_unbox=TRUE)),split='development target 2019-2021; fixed sequential final 2022/2023',
 seed=seed,panel_sha256=selection$panel_sha256,selection_sha256=sha256('output/models/development_selection.rds'),evaluation_code_sha256=sha256('R/06_evaluate.R')))
write_table(left_join(scores,results_meta,by='model',relationship='one-to-one'),'model_results_register.csv')
library(ggplot2)
comparison<-scores |> filter(track=='lagged') |> mutate(model=reorder(model,rmse))
g<-ggplot(comparison,aes(rmse/1e6,model,color=selected_before_test))+geom_point(size=3)+
 scale_color_manual(values=c('FALSE'='#71818a','TRUE'='#146b8a'),labels=c('FALSE'='No','TRUE'='Yes'))+
 scale_y_discrete(labels=c(state_historical_mean='Historical state mean',forest_m4_n5='Random forest',log_lag_all='Log AR + all indicators',ridge_0.01='Ridge',log_ar_l_permits='Log AR + permits',state_log_lag_all='State log AR + all indicators',naive_prior_year='Prior-year quantity',log_ar_l_highway='Log AR + highway',log_ar_l_gdp='Log AR + construction GDP',log_ar='Log AR',levels_lag_all='Levels AR + all indicators'))+
 labs(title='Final-year error under the frozen evaluation procedure',subtitle='2022-2023; selected candidate identified before these scores were computed',x='RMSE, million metric tons',y=NULL,color='Selected')+theme_minimal(base_size=11)
ggsave('output/figures/final_model_rmse.png',g,width=8,height=5,dpi=160)
g<-ggplot(selected,aes(actual/1e6,predicted/1e6,color=factor(year)))+geom_abline(slope=1,intercept=0,linetype=2)+geom_point(alpha=.8)+
 coord_equal()+labs(title='Frozen candidate: log AR + prior highway outlays',x='Observed, million metric tons',y='Predicted, million metric tons',color='Year')+theme_minimal(base_size=11)
ggsave('output/figures/final_observed_predicted.png',g,width=6.5,height=5,dpi=160)
write_lines(c('Final evaluation completed with the previously frozen selection. No final-year tuning.',
 paste('Selected model:',selection$selected_model),paste('Selection SHA256:',sha256('output/models/development_selection.rds')),
 '2022 trained through 2021; 2023 refit unchanged through 2022. 94 scored observations per benchmark.',
 'Current-vintage retrospective evaluation does not establish historical real-time data availability.',
 'Empirical intervals and paired state bootstrap do not account for unidentified future aggregate shocks.'),'output/logs/final_evaluation_audit.txt')
