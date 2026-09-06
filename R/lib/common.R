# Shared configuration. Run from project root; no global package changes.
if (dir.exists('.R-library')) .libPaths(c(normalizePath('.R-library'), .libPaths()))
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(purrr);library(tibble);library(readxl);library(jsonlite);library(digest)})
options(stringsAsFactors=FALSE,dplyr.summarise.inform=FALSE)
source('R/lib/source_definitions.R')
analysis_years<-2015L:2023L
development_years<-2019L:2021L
test_years<-2022L:2023L
seed<-6002026L
for(p in c('data/raw/snapshots','data/clean/approved','data/processed/approved','output/tables','output/figures','output/models','output/logs')) dir.create(p,recursive=TRUE,showWarnings=FALSE)
sha256<-function(path) digest::digest(file=path,algo='sha256')
write_table<-function(data,name) write_csv(data,file.path('output/tables',name),na='')
check_keys<-function(data,name,complete=TRUE,years=analysis_years) {
  stopifnot(all(c('state_fips','year') %in% names(data)))
  if(anyNA(data$state_fips)||anyNA(data$year)) stop(name,': missing keys')
  if(anyDuplicated(data[c('state_fips','year')])) stop(name,': duplicate keys')
  expected<-crossing(state_fips=state_fips_lookup$state_fips,year=years)
  if(nrow(anti_join(data,expected,by=c('state_fips','year')))) stop(name,': invalid keys')
  if(complete&&nrow(anti_join(expected,data,by=c('state_fips','year')))) stop(name,': incomplete backbone')
  invisible(data)
}
safe_join<-function(left,right,keys=c('state_fips','year'),relationship='one-to-one') {
  if(anyDuplicated(right[keys])) stop('Right join keys not unique')
  overlap<-intersect(setdiff(names(right),keys),names(left))
  if(length(overlap)) stop('Unplanned overlapping columns: ',paste(overlap,collapse=', '))
  result<-left_join(left,right,by=keys,relationship=relationship)
  stopifnot(nrow(result)==nrow(left));result
}
number_tokens<-function(x,allowed=c('','W','--','NA','(NA)','(D)','(L)','N/A','.')) {
  x<-trimws(as.character(x));value<-suppressWarnings(as.numeric(gsub(',','',x,fixed=TRUE)))
  unexpected<-unique(x[is.na(value)&!is.na(x)&!x %in% allowed])
  if(length(unexpected)) stop('Unrecognized numeric tokens: ',paste(unexpected,collapse=', '))
  value
}
read_panel<-function() read_csv('data/processed/approved/crushed_stone_state_year.csv',col_types=cols(state_fips=col_character()),show_col_types=FALSE)
verify_manifest<-function() {
  m<-read_csv('docs/source_manifest.csv',show_col_types=FALSE)
  stopifnot(!anyDuplicated(m$source_id))
  for(i in seq_len(nrow(m))) {
    if(!file.exists(m$path[i])) stop('Missing pinned input: ',m$path[i],'; run R/01_import.R')
    if(sha256(m$path[i])!=m$sha256[i]) stop('Pinned checksum changed: ',m$source_id[i])
  };m
}
source_path<-function(id) {
  row<-source_manifest |> filter(source_id==id)
  if(nrow(row)!=1) stop('Source not pinned uniquely: ',id)
  row$path
}
read_bea<-function(id,code,unit,name) {
  p<-fromJSON(source_path(id));d<-as_tibble(p$Data) |> mutate(state=trimws(gsub('\\*','',GeoName))) |> filter(state %in% state.name)
  stopifnot(all(d$Code==code),all(d$CL_UNIT==unit),all(d$UNIT_MULT=='6'))
  out<-d |> transmute(state_fips=substr(GeoFips,1,2),year=as.integer(TimePeriod),value=number_tokens(DataValue))
  names(out)[3]<-name;check_keys(out,id);out
}
