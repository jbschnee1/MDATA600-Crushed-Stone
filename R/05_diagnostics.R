# Development-only stability and forest permutation checks; no final-year data used.
source('R/lib/modeling.R')
selection<-readRDS('output/models/development_selection.rds')
d<-make_model_data(read_panel()) |> filter(year<=2021)
spec<-selection$specs[[selection$selected_model]]
# Leave-one-large-state-out scoring of the same frozen procedure; do not retune.
state_sizes<-filter(d,target_observed) |> group_by(state) |> summarise(mean_y=mean(y)) |> arrange(desc(mean_y))
sensitivity<-map_dfr(head(state_sizes$state,5),function(s) {
 sub<-filter(d,state!=s);pr<-rolling_predict(sub,spec,development_years)
 bind_cols(tibble(excluded_state=s,model=spec$id),score(pr$actual,pr$predicted,pr$naive))
})
write_table(sensitivity,'development_large_state_sensitivity.csv')
# Permutations occur within each held-out development year across states.
forest_spec<-Filter(function(s)s$kind=='forest',selection$specs)[[1]]
permutations<-list()
for(yr in development_years) {
 train<-filter(d,eligible_prediction,year<yr);test<-filter(d,eligible_prediction,year==yr)
 fit<-fit_predict(train,test,forest_spec,history=filter(d,target_observed,year<yr),return_model=TRUE)
 base_mse<-mean((test$y-fit$prediction)^2)
 for(v in forest_spec$features)for(b in 1:10) {
  set.seed(seed+yr+b);changed<-test[forest_spec$features];changed[[v]]<-sample(changed[[v]])
  predicted<-exp(predict(fit$model,data=changed,num.threads=1)$predictions)*fit$smearing
  permutations[[length(permutations)+1]]<-tibble(year=yr,feature=v,repeat_id=b,mse_increase=mean((test$y-predicted)^2)-base_mse)
 }
}
write_table(bind_rows(permutations) |> group_by(feature) |> summarise(mean_mse_increase=mean(mse_increase),min_mse_increase=min(mse_increase),max_mse_increase=max(mse_increase)),
 'development_forest_permutation.csv')
write_lines(c('Forest permutation importance is measured on held-out development years, not training impurity.',
 'It describes loss of predictive information when one feature is shuffled across states within a year.',
 'Correlated predictors and implausible shuffled combinations limit interpretation; no causal claims.',
 'Large-state checks refit the unchanged selected procedure; they do not choose a different test model.'),'output/logs/development_diagnostics.txt')
