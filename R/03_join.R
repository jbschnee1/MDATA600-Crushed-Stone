# Approved analytical panel; original 80-column panel remains unchanged.
source('R/lib/common.R')
source_manifest<-verify_manifest()
panel<-crossing(state_fips=state_fips_lookup$state_fips,year=analysis_years) |>
 left_join(state_fips_lookup,by='state_fips',relationship='many-to-one')
joins<-list()
for(id in c('usgs','census_bps','fhwa','bea','bls','eia','census_construction','msha')) {
 data<-read_csv(file.path('data/clean/approved',paste0(id,'.csv')),col_types=cols(state_fips=col_character()),show_col_types=FALSE)
 check_keys(data,id,complete=id!='bls');before<-nrow(panel);panel<-safe_join(panel,data)
 joins[[id]]<-tibble(source=id,input_rows=nrow(data),before_rows=before,after_rows=nrow(panel),join='left one-to-one state_fips/year')
}
fred<-read_csv('data/clean/approved/fred.csv',show_col_types=FALSE) |> filter(year %in% analysis_years)
panel<-safe_join(panel,fred,keys='year',relationship='many-to-one') |>
 mutate(highway_capital_outlays_2017_million_usd=if_else(fhwa_year_matches,highway_capital_outlays_nominal_thousand_usd/1000*cpi_2017_multiplier,NA_real_),
 highway_preservation_2017_million_usd=if_else(fhwa_year_matches,highway_construction_preservation_nominal_thousand_usd/1000*cpi_2017_multiplier,NA_real_),
 private_nonresidential_2017_million_usd=private_nonresidential_nominal_million_usd*cpi_2017_multiplier,
 state_local_construction_2017_million_usd=state_local_construction_nominal_million_usd*cpi_2017_multiplier,
 industrial_energy_2017_usd_per_mmbtu=industrial_energy_price_per_mmbtu*cpi_2017_multiplier) |>
 arrange(state_fips,year)
lag_columns<-c('crushed_stone_sold_used_metric_tons','housing_units_authorized','highway_capital_outlays_2017_million_usd',
 'construction_gdp_chained_2017_million_usd','heavy_civil_employment_thousands','industrial_energy_2017_usd_per_mmbtu',
 'active_stone_mines','stone_mine_employee_hours','private_nonresidential_2017_million_usd','state_local_construction_2017_million_usd')
previous<-panel |> select(state_fips,year,all_of(lag_columns)) |> rename_with(~paste0('lag1_',.x),all_of(lag_columns)) |>
 mutate(lag1_source_year=year,year=year+1L)
panel<-safe_join(panel,previous)
stopifnot(all(panel$year[!is.na(panel$lag1_source_year)]-panel$lag1_source_year[!is.na(panel$lag1_source_year)]==1))
for(v in lag_columns) {
 expected<-panel[[v]][match(paste(panel$state_fips,panel$year-1),paste(panel$state_fips,panel$year))]
 stopifnot(isTRUE(all.equal(panel[[paste0('lag1_',v)]],expected)))
}
primary<-c('housing_units_authorized','highway_capital_outlays_2017_million_usd','construction_gdp_chained_2017_million_usd')
panel<-panel |> mutate(target_observed=!is.na(crushed_stone_sold_used_metric_tons),
 eligible_explanation=target_observed & if_all(all_of(primary),~!is.na(.x)),
 eligible_prediction=target_observed & if_all(all_of(paste0('lag1_',c('crushed_stone_sold_used_metric_tons',primary))),~!is.na(.x)),
 dataset_stage='approved_gate1_design; model_choice_pending_gate2')
check_keys(panel,'approved panel')
stopifnot(nrow(panel)==450,sum(panel$target_observed)==427,sum(panel$eligible_explanation)==419,
 sum(panel$eligible_prediction)==371,sum(panel$eligible_prediction & panel$year %in% test_years)==94)
for(v in c('crushed_stone_sold_used_metric_tons',primary))stopifnot(all(panel[[v]]>0,na.rm=TRUE))
write_csv(panel,'data/processed/approved/crushed_stone_state_year.csv',na='')
write_table(bind_rows(joins),'join_audit.csv')
coverage<-panel |> select(state_fips,state,year,target_observed,target_withheld,fhwa_year_matches,bls_months,msha_no_qualifying_activity,eligible_explanation,eligible_prediction)
write_table(coverage,'state_year_coverage.csv')
write_table(coverage |> group_by(year) |> summarise(backbone=n(),observed_target=sum(target_observed),explanation=sum(eligible_explanation),prediction=sum(eligible_prediction),bls_present=sum(!is.na(bls_months))), 'coverage_by_year.csv')
write_table(map_dfr(names(panel),function(v)tibble(variable=v,type=class(panel[[v]])[1],missing=sum(is.na(panel[[v]])),unique_values=n_distinct(panel[[v]],na.rm=TRUE))),'approved_variable_profile.csv')
anomalies<-panel |> select(state_fips,state,year,all_of(c('crushed_stone_sold_used_metric_tons',primary))) |>
 pivot_longer(-c(state_fips,state,year),names_to='variable',values_to='value') |>
 group_by(state_fips,variable) |> arrange(year,.by_group=TRUE) |> mutate(previous=lag(value),change_pct=100*(value/previous-1)) |>
 ungroup() |> filter(!is.na(change_pct),abs(change_pct)>50)
write_table(anomalies,'annual_change_review.csv')
write_lines(c('# Data quality report - approved pipeline','',
 'PASS: 450 unique state-years, exact 50-state/2015-2023 coverage, nonnegative observed target and positive primary inputs.',
 'PASS: joins preserve row counts; keys unique; CPI has 12 months in every year 2014-2023.',
 'PASS: 23 withheld outcomes stay missing; 8 misdated FHWA values masked; no interpolation.',
 'PASS: explicit previous-year joins; each lag reconciled to exact state/year-1 input including missingness.',
 'Eligible: 419 contemporaneous, 371 lagged; 94 in final 2022-2023 prediction years.',
 'BLS: 324 complete annual observations; not a primary eligibility requirement.',
 paste(nrow(anomalies),'annual changes above 50% flagged in annual_change_review.csv; no automatic deletion.'),
 'All source inputs checksum-pinned. FHWA 2015-2022 uses preserved parsed data; live originals fail certificate validation.',
 'MSHA zero aggregates explicitly flagged; current commodity classification and USGS estimation dependence retained as limitations.',
 'USGS target uses first-sale/use geography. Read source_register.md for revision and historical-release limitations.'),'docs/data_quality_report.md')
message('Approved panel complete: 450 rows; 419 explanation / 371 lagged prediction eligible.')
