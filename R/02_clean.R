# Deterministic source parsing into approved/; no raw-data changes.
source('R/lib/common.R')
source_manifest<-verify_manifest()
save_clean<-function(x,name,complete=TRUE) {
 check_keys(x,name,complete)
 write_csv(arrange(x,state_fips,year),file.path('data/clean/approved',paste0(name,'.csv')),na='')
}
u<-read_excel(source_path('usgs'),sheet='Data_1971_2023',col_types='text')
usgs<-u |> filter(Commodity=='Stone, crushed',`Data Description`=='State totals',Year %in% analysis_years) |>
 transmute(state=`State Coverage`,year=as.integer(Year),target_source_token=Quantity,
 crushed_stone_sold_used_metric_tons=number_tokens(Quantity),target_withheld=Quantity=='W',target_includes_agency_estimates=TRUE) |>
 left_join(state_fips_lookup,by='state',relationship='many-to-one') |> select(-state)
stopifnot(sum(usgs$target_withheld)==23,all(usgs$crushed_stone_sold_used_metric_tons>=0,na.rm=TRUE));save_clean(usgs,'usgs')
national<-u |> filter(Commodity=='Stone, crushed',`Data Description`=='National total or average',Year %in% analysis_years) |>
 transmute(year=as.integer(Year),national_sold_used_metric_tons=number_tokens(Quantity))
stopifnot(nrow(national)==9,!anyDuplicated(national$year));write_csv(national,'data/clean/approved/usgs_national_context.csv')
bps<-map_dfr(analysis_years,function(y) {
 x<-read_csv(source_path(paste0('bps_',y)),skip=2,col_names=bps_state_col_names,col_types=cols(.default='c'),show_col_types=FALSE) |>
 filter(state_fips %in% state_fips_lookup$state_fips)
 stopifnot(all(substr(x$time,1,4)==as.character(y)))
 x |> transmute(state_fips,year=y,housing_units_authorized=number_tokens(units_1unit)+number_tokens(units_2unit)+number_tokens(units_34unit)+number_tokens(units_5punit),
 housing_units_reported=number_tokens(units_1unit_rep)+number_tokens(units_2unit_rep)+number_tokens(units_34unit_rep)+number_tokens(units_5punit_rep),
 permits_include_census_imputation=TRUE,permits_universe_change=y==2023)
})
stopifnot(all(bps$housing_units_authorized>0));save_clean(bps,'census_bps')
f<-read_csv(source_path('fhwa_legacy'),col_types=cols(state_fips=col_character()),show_col_types=FALSE)
fhwa<-f |> transmute(fhwa_state_token=state,state=normalize_fhwa_state(state),year=as.integer(year),
 highway_capital_outlays_nominal_thousand_usd=capital_outlay_total,highway_construction_preservation_nominal_thousand_usd=capital_construction_preservation) |>
 left_join(state_fips_lookup,by='state',relationship='many-to-one') |> select(-state)
flags<-read_csv(source_path('fhwa_flags'),col_types=cols(state_fips=col_character()),show_col_types=FALSE) |>
 transmute(state_fips,year=table_year,fhwa_reported_year=reported_year,fhwa_footnote=as.character(footnote))
fhwa<-safe_join(fhwa,flags) |> mutate(fhwa_reported_year=coalesce(fhwa_reported_year,year),fhwa_year_matches=fhwa_reported_year==year,
 fhwa_provenance='legacy_parsed_archive; HTML footnotes verified; 2023 original reconciled')
stopifnot(sum(!fhwa$fhwa_year_matches)==8)
f23<-read_excel(source_path('fhwa_2023'),range='A15:S65',col_names=fhwa_col_names) |> mutate(state=normalize_fhwa_state(state)) |>
 inner_join(state_fips_lookup,by='state',relationship='one-to-one')
paired<-inner_join(filter(fhwa,year==2023),select(f23,state_fips,capital_outlay_total),by='state_fips',relationship='one-to-one')
stopifnot(nrow(paired)==50,all(paired$highway_capital_outlays_nominal_thousand_usd==paired$capital_outlay_total));save_clean(fhwa,'fhwa')
bea<-read_bea('bea_construction','SAGDP9-11','Millions of chained 2017 dollars','construction_gdp_chained_2017_million_usd')
bea<-safe_join(bea,read_bea('bea_gdp','SAGDP9-1','Millions of chained 2017 dollars','total_gdp_chained_2017_million_usd'))
bea<-safe_join(bea,read_bea('bea_income','SAINC1-1','Millions of dollars','personal_income_nominal_million_usd'));save_clean(bea,'bea')
fred_annual<-function(id,name,monthly=FALSE) {
 x<-as_tibble(fromJSON(source_path(id))) |> transmute(date=as.Date(date),value=number_tokens(value))
 stopifnot(!anyDuplicated(x$date),!anyNA(x$value))
 d<-x |> mutate(year=as.integer(format(date,'%Y'))) |> group_by(year) |> summarise(value=mean(value),observations=n())
 stopifnot(setequal(d$year,2014:2023));if(monthly)stopifnot(all(d$observations==12))
 names(d)[2:3]<-c(name,paste0(name,'_observations'));d
}
fred<-safe_join(fred_annual('fred_CPIAUCSL','cpi_index',TRUE),fred_annual('fred_MORTGAGE30US','mortgage_rate_pct'),keys='year') |>
 arrange(year) |> mutate(inflation_pct=100*(cpi_index/lag(cpi_index)-1),cpi_2017_multiplier=cpi_index[year==2017]/cpi_index)
stopifnot(!anyNA(filter(fred,year %in% analysis_years)$inflation_pct));write_csv(fred,'data/clean/approved/fred.csv',na='')
b<-fromJSON(source_path('bls_heavy_civil'),simplifyVector=FALSE)
monthly<-map_dfr(b$Results$series,function(s) {if(!length(s$data))return(tibble());bind_rows(s$data) |> mutate(state_fips=substr(s$seriesID,4,5),series_id=s$seriesID)}) |>
 filter(period %in% sprintf('M%02d',1:12)) |> mutate(year=as.integer(year),value=number_tokens(value))
stopifnot(!anyDuplicated(monthly[c('state_fips','year','period')]))
bls<-monthly |> group_by(state_fips,year,series_id) |> summarise(heavy_civil_employment_thousands=mean(value),bls_months=sum(!is.na(value))) |>
 mutate(heavy_civil_employment_thousands=if_else(bls_months==12,heavy_civil_employment_thousands,NA_real_))
stopifnot(nrow(bls)==324,all(bls$bls_months==12));save_clean(bls,'bls',FALSE)
eia<-read_csv(source_path('eia_prices'),show_col_types=FALSE) |> filter(State %in% state.abb,MSN %in% names(eia_price_series)) |>
 select(State,MSN,all_of(as.character(analysis_years))) |> pivot_longer(all_of(as.character(analysis_years)),names_to='year',values_to='value') |>
 transmute(state=state.name[match(State,state.abb)],year=as.integer(year),variable=unname(eia_price_series[MSN]),value=number_tokens(value)) |>
 pivot_wider(names_from=variable,values_from=value) |> left_join(state_fips_lookup,by='state') |> select(-state)
stopifnot(all(unlist(select(eia,-state_fips,-year))>0));save_clean(eia,'eia')
construction<-list()
for(pair in list(c('nrstatehs1','nrstate','private_nonresidential_nominal_million_usd'),c('slstatehs','slstate','state_local_construction_nominal_million_usd'))) {
 d<-map2_dfr(pair[1:2],1:2,function(id,priority) {
  raw<-read_excel(source_path(paste0('census_',id)),col_names=FALSE);header<-as.character(unlist(raw[4,]));columns<-which(header %in% as.character(analysis_years))
  states<-trimws(as.character(raw[[2]]));keep<-states %in% state.name
  map_dfr(columns,function(k)tibble(state=states[keep],year=as.integer(header[k]),value=number_tokens(raw[[k]][keep]),priority=priority,source_file=id))
 }) |> arrange(state,year,desc(priority)) |> distinct(state,year,.keep_all=TRUE) |> left_join(state_fips_lookup,by='state') |> select(state_fips,year,value,source_file)
 names(d)[3:4]<-c(pair[3],paste0(pair[3],'_source_file'));construction[[pair[3]]]<-d
}
save_clean(safe_join(construction[[1]],construction[[2]]),'census_construction')
read_msha_zip_table<-function(url,expected_file) {
 id<-if(expected_file=='Mines.txt')'msha_mines' else 'msha_employment';tmp<-tempfile();dir.create(tmp);on.exit(unlink(tmp,recursive=TRUE))
 unzip(source_path(id),files=expected_file,exdir=tmp)
 result<-read_delim(file.path(tmp,expected_file),delim='|',quote='',col_types=cols(.default='c'),show_col_types=FALSE,trim_ws=TRUE)
 stopifnot(nrow(problems(result))==0)
 result<-result |> mutate(across(any_of(c('MINE_ID','PRIMARY_CANVASS_CD','STATE_ABBR','SUBUNIT_CD','CALENDAR_YR','ANNUAL_HRS','AVG_ANNUAL_EMPL','C_M_IND')),~if_else(!is.na(.x) & startsWith(.x, '"') & endsWith(.x, '"'),substr(.x,2,nchar(.x)-1),.x)))
 stopifnot(all(grepl('^[0-9]{7}$',result$MINE_ID)))
 if(expected_file=='Mines.txt')stopifnot(!anyDuplicated(result$MINE_ID))
 result
}
msha_urls<-c(employment='cached',mines='cached')
msha<-get_msha_stone_capacity(analysis_years) |> select(-state) |>
 mutate(msha_no_qualifying_activity=active_stone_mines==0,msha_uses_current_commodity=TRUE,msha_activity_not_rated_capacity=TRUE)
stopifnot(all(msha$active_stone_mines==msha$stone_mine_operations),sum(msha$active_stone_mines)>0);save_clean(msha,'msha')
legacy_msha<-read_csv('data/raw/msha/msha_stone_capacity.csv',col_types=cols(state_fips=col_character()),show_col_types=FALSE)
comparison<-inner_join(msha,legacy_msha,by=c('state_fips','year'),suffix=c('_new','_legacy'),relationship='one-to-one')
write_table(comparison |> transmute(state_fips,year,active_new=active_stone_mines_new,active_legacy=active_stone_mines_legacy,hours_new=stone_mine_employee_hours_new,hours_legacy=stone_mine_employee_hours_legacy) |> filter(active_new!=active_legacy | hours_new!=hours_legacy),'msha_parser_correction.csv')
message('Parsed approved sources; CPI support year, literal-quote MSHA parsing and quality flags retained.')
