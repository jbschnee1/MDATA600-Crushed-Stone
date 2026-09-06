# Offline source verification only; no data/ writes or model fitting.
suppressPackageStartupMessages({library(dplyr);library(readr);library(readxl);library(tidyr);library(purrr);library(tibble);library(jsonlite)})
cache <- "output/source_verification"
evidence <- "docs/evidence"
snapshot <- function(prefix, extension) {
  files <- list.files(cache,paste0("^",prefix,"_[0-9].*\\.",extension,"$"),full.names=TRUE)
  # Public content hashes can begin with a-f.
  if(!length(files)) files <- list.files(cache,paste0("^",prefix,"_[a-f0-9]+\\.",extension,"$"),full.names=TRUE)
  if(!length(files)) stop("Missing snapshot: ",prefix)
  files[which.max(file.info(files)$mtime)]
}
# Load definitions/configuration only; never evaluate import blocks or key loading.
allowed <- c("state_fips_lookup","bps_state_col_names","fhwa_col_names","eia_price_series")
for(expression in parse("docs/evidence/baseline_code/01_import.R")) {
  if(is.call(expression) && identical(expression[[1]],as.name("<-"))) {
    rhs <- expression[[3]]
    if((is.call(rhs) && identical(rhs[[1]],as.name("function"))) || as.character(expression[[2]]) %in% allowed) eval(expression)
  }
}
analysis_years <- 2015:2023
results <- list()
compare <- function(id, fresh, old_path, variables, keys=c("state_fips","year")) {
  old <- read_csv(old_path,col_types=cols(state_fips=col_character()),show_col_types=FALSE)
  stopifnot(!anyDuplicated(fresh[keys]))
  paired <- inner_join(fresh,old,by=keys,suffix=c("_new","_old"))
  for(v in variables) {
    a<-paired[[paste0(v,"_new")]]; b<-paired[[paste0(v,"_old")]]
    mismatch <- xor(is.na(a),is.na(b)) | (!is.na(a)&!is.na(b)&abs(a-b)>1e-7*pmax(1,abs(b)))
    results[[length(results)+1]] <<- tibble(source=id,variable=v,fresh_rows=nrow(fresh),paired_rows=nrow(paired),fresh_missing=sum(is.na(fresh[[v]])),different_values=sum(mismatch))
  }
}
usgs <- read_excel(snapshot("usgs","xlsx"),sheet="Data_1971_2023",col_types="text") |>
  filter(Commodity=="Stone, crushed",`Data Description`=="State totals",Year %in% analysis_years) |>
  transmute(state=`State Coverage`,year=as.integer(Year),quantity_token=Quantity,
    crushed_stone_tons=suppressWarnings(parse_number(Quantity,na=c("W","--","")))) |>
  left_join(state_fips_lookup,by="state")
write_csv(usgs |> select(state_fips,state,year,quantity_token),file.path(evidence,"usgs_target_tokens.csv"))
compare("usgs",usgs,"data/raw/usgs/usgs_crushed_stone_production.csv","crushed_stone_tons")
bps <- map_dfr(analysis_years,function(y) read_csv(snapshot(paste0("bps_",y),"txt"),skip=2,col_names=bps_state_col_names,col_types=cols(.default="c"),show_col_types=FALSE) |> mutate(year=y)) |>
  filter(state_fips %in% state_fips_lookup$state_fips) |>
  mutate(across(c(units_1unit,units_2unit,units_34unit,units_5punit),as.numeric))
compare("census_bps",bps,"data/raw/census/census_building_permits.csv",c("units_1unit","units_2unit","units_34unit","units_5punit"))
fhwa <- read_excel(snapshot("fhwa_2023","xlsx"),range="A15:S65",col_names=fhwa_col_names) |>
  mutate(state=normalize_fhwa_state(state),year=2023,capital_outlay_total=as.numeric(capital_outlay_total)) |>
  inner_join(state_fips_lookup,by="state")
compare("fhwa_2023",fhwa,"data/processed/crushed_stone_state_year.csv","capital_outlay_total")
full_fhwa <- read_excel(snapshot("fhwa_2023","xlsx"),col_names=FALSE,col_types="text")
write_lines(apply(tail(full_fhwa,10),1,paste,collapse=" | "),file.path(evidence,"fhwa_2023_footnotes.txt"))
for(item in list(c("bea_gdp","real_gdp","data/raw/bea/bea_state_gdp_personal_income.csv"),c("bea_income","personal_income","data/raw/bea/bea_state_gdp_personal_income.csv"),c("bea_construction","construction_real_gdp","data/raw/bea/bea_construction_gdp.csv"))) {
  j <- fromJSON(snapshot(item[1],"json"))
  d <- as_tibble(j$Data) |> mutate(GeoName=trimws(gsub("\\*","",GeoName))) |> filter(GeoName %in% state.name) |>
    transmute(state_fips=substr(GeoFips,1,2),year=as.integer(TimePeriod),value=parse_number(DataValue))
  names(d)[3] <- item[2]
  compare(item[1],d,item[3],item[2])
  write_lines(c(paste("Units:",paste(unique(j$Data$CL_UNIT),collapse="; ")),paste("Codes:",paste(unique(j$Data$Code),collapse="; ")),paste("Notes:",paste(j$Notes$NoteText,collapse="; "))),file.path(evidence,paste0(item[1],"_metadata.txt")))
}
eia <- read_csv(snapshot("eia_prices","csv"),show_col_types=FALSE) |>
  filter(State %in% state.abb,MSN %in% names(eia_price_series)) |>
  pivot_longer(all_of(as.character(analysis_years)),names_to="year",values_to="value") |>
  transmute(state=state.name[match(State,state.abb)],year=as.integer(year),variable=unname(eia_price_series[MSN]),value=as.numeric(value)) |>
  pivot_wider(names_from=variable,values_from=value) |> left_join(state_fips_lookup,by="state")
compare("eia",eia,"data/raw/eia/eia_energy_prices.csv",unname(eia_price_series))
for(pair in list(c("nrstatehs1","nrstate","private_nonresidential_spending_nominal_millions"),c("slstatehs","slstate","state_local_construction_spending_nominal_millions"))) {
  d <- map_dfr(pair[1:2],function(id) {
    raw <- read_excel(snapshot(paste0("census_",id),"xlsx"),col_names=FALSE)
    header <- as.character(unlist(raw[4,])); columns <- which(header %in% as.character(analysis_years))
    map_dfr(columns,function(k) tibble(state=trimws(as.character(raw[[2]])),year=as.integer(header[k]),value=suppressWarnings(parse_number(as.character(raw[[k]])))))
  }) |> filter(state %in% state.name) |> left_join(state_fips_lookup,by="state")
  names(d)[names(d)=="value"]<-pair[3]
  compare(paste0("census_",pair[2]),d,"data/raw/census/census_construction_spending.csv",pair[3])
}
# Reuse the existing aggregation on cached archives; no network calls.
read_msha_zip_table <- function(url,expected_file) {
  id <- if(expected_file=="Mines.txt") "msha_mines" else "msha_employment"
  tmp <- tempfile(); dir.create(tmp); on.exit(unlink(tmp,recursive=TRUE))
  unzip(snapshot(id,"zip"),files=expected_file,exdir=tmp)
  read_delim(file.path(tmp,expected_file),delim="|",col_types=cols(.default="c"),show_col_types=FALSE,trim_ws=TRUE)
}
msha_urls<-c(employment="cached",mines="cached")
msha<-get_msha_stone_capacity(analysis_years)
compare("msha",msha,"data/raw/msha/msha_stone_capacity.csv",c("active_stone_mines","stone_mine_employee_hours"))
fred <- fromJSON(snapshot("fred_CPIAUCSL","json")) |>
  as_tibble() |> mutate(year=as.integer(substr(date,1,4)),value=as.numeric(value)) |>
  group_by(year) |> summarise(cpi_index=mean(value),months=n(),.groups="drop")
write_csv(fred,file.path(evidence,"verified_cpi_annual.csv"))
compare("fred_cpi",fred,"data/raw/fred/fred_mortgage_rates_inflation.csv","cpi_index",keys="year")
mortgage<-fromJSON(snapshot("fred_MORTGAGE30US","json")) |>
  as_tibble() |> mutate(year=as.integer(substr(date,1,4)),value=as.numeric(value)) |>
  group_by(year) |> summarise(mortgage_rate_pct=mean(value),observations=n(),.groups="drop")
compare("fred_mortgage",mortgage,"data/raw/fred/fred_mortgage_rates_inflation.csv","mortgage_rate_pct",keys="year")
bls <- fromJSON(snapshot("bls_heavy_civil","json"),simplifyVector=FALSE)
monthly<-map_dfr(bls$Results$series,function(s) {
  if(!length(s$data)) return(tibble())
  bind_rows(s$data) |> mutate(state_fips=substr(s$seriesID,4,5))
}) |> filter(period %in% sprintf("M%02d",1:12)) |>
  mutate(year=as.integer(year),value=as.numeric(value))
annual<-monthly |> group_by(state_fips,year) |> summarise(construction_employment_thousands=mean(value),months=n(),.groups="drop")
stopifnot(all(annual$months==12))
compare("bls",annual,"data/raw/bls/bls_state_construction_employment.csv","construction_employment_thousands")
write_csv(bind_rows(results),file.path(evidence,"source_comparison.csv"))
print(bind_rows(results),n=30,width=180)
