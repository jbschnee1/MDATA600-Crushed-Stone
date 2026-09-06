source('R/lib/common.R')
make_model_data<-function(p) {
  p |> mutate(y=crushed_stone_sold_used_metric_tons,lag_y=lag1_crushed_stone_sold_used_metric_tons,
    ly=log(y),l_lag_y=log(lag_y),l_permits=log(lag1_housing_units_authorized),
    l_highway=log(lag1_highway_capital_outlays_2017_million_usd),l_gdp=log(lag1_construction_gdp_chained_2017_million_usd),
    l_permits_t=log(housing_units_authorized),l_highway_t=log(highway_capital_outlays_2017_million_usd),
    l_gdp_t=log(construction_gdp_chained_2017_million_usd),
    l_energy=log(lag1_industrial_energy_2017_usd_per_mmbtu),l_bls=log(lag1_heavy_civil_employment_thousands),
    l_mines=log1p(lag1_active_stone_mines),l_private=log(lag1_private_nonresidential_2017_million_usd),
    l_public=log(lag1_state_local_construction_2017_million_usd))
}
core_features<-c('l_lag_y','l_permits','l_highway','l_gdp')
score<-function(actual,predicted,naive=NULL) {
  stopifnot(length(actual)==length(predicted),all(is.finite(actual)),all(is.finite(predicted)))
  sse<-sum((actual-predicted)^2);sst<-sum((actual-mean(actual))^2)
  tibble(n=length(actual),r_squared=if(sst>0)1-sse/sst else NA_real_,rmse=sqrt(mean((actual-predicted)^2)),
    mae=mean(abs(actual-predicted)),rmse_skill=if(is.null(naive))NA_real_ else 1-sqrt(sse/sum((actual-naive)^2)),
    change_r_squared=if(is.null(naive))NA_real_ else 1-sse/sum(((actual-naive)-mean(actual-naive))^2))
}
candidate_specs<-function() {
  models<-list(
    list(id='naive_prior_year',kind='naive',features=character(),complexity=0,track='lagged'),
    list(id='state_historical_mean',kind='state_mean',features=character(),complexity=1,track='lagged'),
    list(id='log_ar',kind='log_lm',features='l_lag_y',complexity=2,track='lagged'))
  for(f in c('l_permits','l_highway','l_gdp')) models[[length(models)+1]]<-list(id=paste0('log_ar_',f),kind='log_lm',features=c('l_lag_y',f),complexity=3,track='lagged')
  models<-c(models,list(
    list(id='log_lag_all',kind='log_lm',features=core_features,complexity=4,track='lagged'),
    list(id='levels_lag_all',kind='levels_lm',features=core_features,complexity=4,track='lagged'),
    list(id='state_log_lag_all',kind='state_lm',features=core_features,complexity=6,track='lagged'),
    list(id='sameyear_pooled_log',kind='log_lm',features=c('l_permits_t','l_highway_t','l_gdp_t'),complexity=4,track='sameyear_conditional'),
    list(id='sameyear_state_log',kind='state_lm',features=c('l_permits_t','l_highway_t','l_gdp_t'),complexity=6,track='sameyear_conditional')))
  for(lambda in c(.01,.1,1,10,100))models[[length(models)+1]]<-list(id=paste0('ridge_',lambda),kind='ridge',features=core_features,lambda=lambda,complexity=5,track='lagged')
  for(m in c(2,4))for(node in c(5,15))models[[length(models)+1]]<-list(id=paste0('forest_m',m,'_n',node),kind='forest',features=core_features,mtry=m,min_node=node,trees=500,complexity=7,track='lagged')
  setNames(models,vapply(models,`[[`,character(1),'id'))
}
fit_predict<-function(train,new,spec,history=train,return_model=FALSE) {
  stopifnot(max(train$year)<min(new$year),max(history$year)<min(new$year))
  xvars<-spec$features
  if(length(xvars))stopifnot(all(is.finite(as.matrix(train[xvars]))),all(is.finite(as.matrix(new[xvars]))))
  fit<-NULL;smear<-1;clipped<-0L
  if(spec$kind=='naive') pred<-new$lag_y
  else if(spec$kind=='state_mean') {
    means<-tapply(history$y,history$state_fips,mean,na.rm=TRUE);pred<-unname(means[new$state_fips])
    stopifnot(!anyNA(pred))
  } else if(spec$kind=='ridge') {
    x<-as.matrix(train[xvars]);nx<-as.matrix(new[xvars]);center<-colMeans(x);scales<-apply(x,2,sd)
    stopifnot(all(scales>0));x<-scale(x,center,scales);nx<-scale(nx,center,scales)
    intercept<-mean(train$ly);beta<-solve(crossprod(x)+diag(spec$lambda,ncol(x)),crossprod(x,train$ly-intercept))
    fitted<-drop(intercept+x%*%beta);smear<-mean(exp(train$ly-fitted));pred<-exp(drop(intercept+nx%*%beta))*smear
    fit<-list(beta=beta,center=center,scale=scales,intercept=intercept,lambda=spec$lambda)
  } else if(spec$kind=='forest') {
    fit<-ranger::ranger(x=train[xvars],y=train$ly,num.trees=spec$trees,mtry=spec$mtry,min.node.size=spec$min_node,
      num.threads=1,seed=seed,importance='none',write.forest=TRUE)
    fitted<-predict(fit,data=train[xvars],num.threads=1)$predictions
    smear<-mean(exp(train$ly-fitted));pred<-exp(predict(fit,data=new[xvars],num.threads=1)$predictions)*smear
  } else {
    if(spec$kind=='levels_lm') {
      train[xvars]<-lapply(train[xvars],exp);new[xvars]<-lapply(new[xvars],exp)
      formula<-reformulate(xvars,response='y')
    } else formula<-reformulate(c(xvars,if(spec$kind=='state_lm')'factor(state_fips)'),response='ly')
    fit<-lm(formula,data=train)
    if(anyNA(coef(fit)))stop('Rank-deficient predictive fit: ',spec$id)
    if(spec$kind=='levels_lm') {raw<-as.numeric(predict(fit,new));clipped<-sum(raw<0);pred<-pmax(0,raw)}
    else {smear<-mean(exp(residuals(fit)));pred<-exp(as.numeric(predict(fit,new)))*smear}
  }
  stopifnot(all(is.finite(pred)),all(pred>=0))
  list(prediction=as.numeric(pred),model=if(return_model)fit else NULL,smearing=smear,clipped=clipped)
}
rolling_predict<-function(d,spec,years,history_data=d) {
  map_dfr(years,function(y) {
    eligible<-if(spec$track=='lagged')d$eligible_prediction else d$eligible_explanation & !is.na(d$lag_y)
    train<-d[eligible & d$year<y,];test<-d[eligible & d$year==y,]
    # Extra secondary features define a documented complete-case subset.
    if(length(spec$features)) {
      train<-train[apply(as.matrix(train[spec$features]),1,function(x)all(is.finite(x))),]
      test<-test[apply(as.matrix(test[spec$features]),1,function(x)all(is.finite(x))),]
    }
    h<-filter(history_data,year<.env$y,!is.na(crushed_stone_sold_used_metric_tons))
    result<-fit_predict(train,test,spec,history=h)
    state_mean<-tapply(h$y,h$state_fips,mean)
    tibble(model=spec$id,track=spec$track,state_fips=test$state_fips,state=test$state,year=y,actual=test$y,
      predicted=result$prediction,naive=test$lag_y,training_state_mean=as.numeric(state_mean[test$state_fips]),
      train_rows=nrow(train),train_max_year=max(train$year),train_min_year=min(train$year),
      feature_set=paste(spec$features,collapse=' + '),smearing=result$smearing,clipped_predictions=result$clipped)
  })
}
score_predictions<-function(predictions,by_year=FALSE) {
  groups<-if(by_year)c('model','track','year')else c('model','track')
  predictions |> group_by(across(all_of(groups))) |>
    group_modify(~score(.x$actual,.x$predicted,.x$naive)) |> ungroup()
}
