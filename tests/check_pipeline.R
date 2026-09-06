# Meaningful invariants: join failures, calendar alignment, and prediction target isolation.
source('R/lib/modeling.R')
p<-read_panel();d<-make_model_data(p)
expect_error<-function(expression)stopifnot(inherits(try(force(expression),silent=TRUE),'try-error'))
expect_error(check_keys(bind_rows(p,p[1,]),'duplicate'))
bad<-p;bad$state_fips[1]<-'99';expect_error(check_keys(bad,'invalid state'))
expect_error(safe_join(select(p,state_fips,year),bind_rows(select(p,state_fips,year),select(p[1,],state_fips,year))))
stopifnot(sum(is.na(p$inflation_pct))==0,all(p$year[!is.na(p$lag1_source_year)]-p$lag1_source_year[!is.na(p$lag1_source_year)]==1))
flags<-read_csv('docs/evidence/fhwa_reporting_year_flags.csv',col_types=cols(state_fips=col_character()),show_col_types=FALSE)
for(i in seq_len(nrow(flags))) {
 r<-filter(p,state_fips==flags$state_fips[i],year==flags$table_year[i]);stopifnot(is.na(r$highway_capital_outlays_2017_million_usd))
 r<-filter(p,state_fips==flags$state_fips[i],year==flags$table_year[i]+1);stopifnot(is.na(r$lag1_highway_capital_outlays_2017_million_usd))
}
train<-filter(d,eligible_prediction,year<2020);new<-filter(d,eligible_prediction,year==2020)
history<-filter(d,target_observed,year<2020)
for(spec in candidate_specs()) {
 if(spec$track!='lagged')next
 a<-fit_predict(train,new,spec,history)$prediction
 changed<-new;changed$y<-changed$y*100;changed$ly<-log(changed$y)
 b<-fit_predict(train,changed,spec,history)$prediction
 stopifnot(isTRUE(all.equal(a,b,tolerance=0)))
}
expect_error(fit_predict(bind_rows(train,new),new,candidate_specs()[['log_ar']],history))
# Ridge with zero penalty equals unpenalized pooled log regression, including smearing.
spec<-candidate_specs()[['ridge_0.01']];spec$lambda<-0
stopifnot(isTRUE(all.equal(fit_predict(train,new,spec,history)$prediction,
 fit_predict(train,new,candidate_specs()[['log_lag_all']],history)$prediction,tolerance=1e-8)))
cat('PASS: invalid/duplicate keys rejected; join expansion rejected; CPI support/lag masks verified.\n')
cat('PASS: forecasts invariant to held-out outcomes; future training rejected; zero-penalty ridge matches OLS.\n')
