# Explanatory associations and predeclared sensitivity/diagnostic review.
source('R/lib/modeling.R')
library(sandwich);library(lmtest)
d<-make_model_data(read_panel());x<-filter(d,eligible_explanation)
f<-ly~l_permits_t+l_highway_t+l_gdp_t+factor(state_fips)+factor(year)
fit<-lm(f,data=x)
stopifnot(!anyNA(coef(fit)))
robust_table<-function(model,data,label,terms=c('l_permits_t','l_highway_t','l_gdp_t')) {
 vc<-vcovCL(model,cluster=data$state_fips,type='HC1',cadjust=TRUE)
 se<-sqrt(pmax(0,diag(vc)));b<-coef(model);df<-n_distinct(data$state_fips)-1
 model_n<-nobs(model);model_r2<-summary(model)$r.squared
 out<-tibble(model=label,term=names(b),estimate=as.numeric(b),cluster_se=as.numeric(se),
 statistic=as.numeric(b/se),p_value=2*pt(-abs(b/se),df),lower=as.numeric(b-qt(.975,df)*se),upper=as.numeric(b+qt(.975,df)*se),
 n=model_n,states=n_distinct(data$state_fips),r_squared=model_r2)
 filter(out,term %in% terms)
}
coefficients<-robust_table(fit,x,'state_year_log')
write_table(coefficients,'explanatory_coefficients.csv')
saveRDS(fit,'output/models/explanatory_state_year_candidate.rds',version=3)
null_fe<-lm(ly~factor(state_fips)+factor(year),data=x)
within_r2<-1-sum(residuals(fit)^2)/sum(residuals(null_fe)^2)
# Diagnostics are descriptive where panel dependence invalidates textbook p-values.
bp<-bptest(fit)
residuals_data<-x |> transmute(state_fips,state,year,fitted_log=fitted(fit),residual_log=residuals(fit),
 standardized_residual=rstandard(fit),cooks_distance=cooks.distance(fit),leverage=hatvalues(fit))
residuals_data<-residuals_data |> group_by(state_fips) |> arrange(year,.by_group=TRUE) |>
 mutate(prior_residual=if_else(year-lag(year)==1,lag(residual_log),NA_real_)) |> ungroup()
serial_correlation<-with(filter(residuals_data,!is.na(prior_residual)),cor(residual_log,prior_residual))
# Residualize predictors on the same state/year effects before checking collinearity.
residualized<-sapply(c('l_permits_t','l_highway_t','l_gdp_t'),function(v)residuals(lm(reformulate(c('factor(state_fips)','factor(year)'),response=v),data=x)))
vif<-sapply(seq_len(ncol(residualized)),function(i)1/(1-summary(lm(residualized[,i]~residualized[,-i]))$r.squared))
write_table(tibble(term=colnames(residualized),within_vif=vif),'explanatory_within_vif.csv')
# Pairwise contemporaneous residual correlation among states: descriptive common-dependence check.
rwide<-residuals_data |> select(year,state_fips,residual_log) |> pivot_wider(names_from=state_fips,values_from=residual_log)
cm<-cor(as.matrix(select(rwide,-year)),use='pairwise.complete.obs')
write_table(tibble(n=nrow(x),states=n_distinct(x$state_fips),years=n_distinct(x$year),
 overall_r_squared=summary(fit)$r.squared,incremental_r_squared_over_state_year=within_r2,
 bp_statistic=unname(bp$statistic),bp_nominal_p=bp$p.value,adjacent_residual_correlation=serial_correlation,
 mean_pairwise_state_residual_correlation=mean(cm[upper.tri(cm)],na.rm=TRUE),
 max_cooks_distance=max(residuals_data$cooks_distance),max_within_vif=max(vif)), 'explanatory_diagnostics.csv')
write_table(arrange(residuals_data,desc(cooks_distance)),'explanatory_residuals_influence.csv')
sensitivity<-list(coefficients)
pooled<-lm(ly~l_permits_t+l_highway_t+l_gdp_t,data=x)
sensitivity[[length(sensitivity)+1]]<-robust_table(pooled,x,'pooled_log')
levels<-lm(y~housing_units_authorized+highway_capital_outlays_2017_million_usd+construction_gdp_chained_2017_million_usd+factor(state_fips)+factor(year),data=x)
sensitivity[[length(sensitivity)+1]]<-robust_table(levels,x,'state_year_levels',c('housing_units_authorized','highway_capital_outlays_2017_million_usd','construction_gdp_chained_2017_million_usd'))
for(label in c('balanced47','through2021','exclude2020')) {
 sub<-switch(label,balanced47=filter(x,!state %in% c('Delaware','Louisiana','Nebraska')),through2021=filter(x,year<=2021),exclude2020=filter(x,year!=2020))
 sensitivity[[length(sensitivity)+1]]<-robust_table(lm(f,data=sub),sub,label)
}
# Outlay-component definition sensitivity; do not combine component and total.
sub<-x |> mutate(l_preservation=log(highway_preservation_2017_million_usd)) |> filter(is.finite(l_preservation))
sensitivity[[length(sensitivity)+1]]<-robust_table(lm(ly~l_permits_t+l_preservation+l_gdp_t+factor(state_fips)+factor(year),data=sub),sub,'highway_preservation_component',c('l_permits_t','l_preservation','l_gdp_t'))
# Simple coverage alternative, not a replacement selected by final scores.
sub<-filter(d,target_observed)
sensitivity[[length(sensitivity)+1]]<-robust_table(lm(ly~l_permits_t+l_gdp_t+factor(state_fips)+factor(year),data=sub),sub,'without_highway_full_available',c('l_permits_t','l_gdp_t'))
for(extra in c('industrial_energy_2017_usd_per_mmbtu','heavy_civil_employment_thousands','active_stone_mines')) {
 sub<-x |> mutate(extra_log=if(extra=='active_stone_mines')log1p(.data[[extra]]) else log(.data[[extra]])) |> filter(is.finite(extra_log))
 sensitivity[[length(sensitivity)+1]]<-robust_table(lm(update(f,.~.+extra_log),data=sub),sub,paste0('secondary_',extra),c('l_permits_t','l_highway_t','l_gdp_t','extra_log'))
}
write_table(bind_rows(sensitivity),'explanatory_sensitivities.csv')
loo<-map_dfr(sort(unique(x$state)),function(s) {
 sub<-filter(x,state!=s);m<-lm(f,data=sub)
 tibble(excluded_state=s,term=c('l_permits_t','l_highway_t','l_gdp_t'),estimate=unname(coef(m)[c('l_permits_t','l_highway_t','l_gdp_t')]))
})
write_table(loo,'explanatory_leave_one_state_out.csv')
# Confirm nominal-vs-common-deflated log outlay coefficient equivalence with year effects.
nominal<-lm(ly~l_permits_t+log(highway_capital_outlays_nominal_thousand_usd)+l_gdp_t+factor(state_fips)+factor(year),data=x)
stopifnot(abs(coef(nominal)['log(highway_capital_outlays_nominal_thousand_usd)']-coef(fit)['l_highway_t'])<1e-8)
library(ggplot2)
g<-ggplot(coefficients,aes(estimate,term))+geom_vline(xintercept=0,linetype=2,color='grey50')+
 geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15)+geom_point(size=3,color='#146b8a')+
 scale_y_discrete(labels=c(l_permits_t='Housing permits',l_highway_t='Highway outlays',l_gdp_t='Construction GDP'))+
 labs(title='Within-state conditional associations',subtitle='State/year effects; 95% state-clustered intervals; no causal interpretation',x='Log-log coefficient',y=NULL)+theme_minimal(base_size=11)
ggsave('output/figures/explanatory_coefficients.png',g,width=8,height=4,dpi=160)
g<-ggplot(residuals_data,aes(fitted_log,residual_log))+geom_hline(yintercept=0,linetype=2)+geom_point(alpha=.5,color='#146b8a')+
 labs(title='Explanatory residuals against fitted log quantities',x='Fitted log metric tons',y='Log residual')+theme_minimal(base_size=11)
ggsave('output/figures/explanatory_residuals.png',g,width=7,height=4.5,dpi=160)
