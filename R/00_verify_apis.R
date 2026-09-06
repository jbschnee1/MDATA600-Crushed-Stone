# Gate 1 read-only source probes. Run from project root; no data/ writes.
# Saves response DATA and metadata, never authenticated request envelopes.
suppressPackageStartupMessages({library(httr); library(jsonlite)})
dir.create("output/source_verification", recursive=TRUE, showWarnings=FALSE)
local_keys <- new.env(parent=baseenv())
if (file.exists("api-keys.R")) sys.source("api-keys.R", local_keys)
keys <- vapply(c("bea", "bls", "fred"), function(provider) {
  value <- Sys.getenv(paste0(toupper(provider), "_KEY"))
  if (!nzchar(value)) value <- get0(paste0(provider,"_key"), local_keys, ifnotfound="")
  value
}, character(1))
stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz="UTC")
probe <- function(id, provider, request, extract) {
  requested <- commandArgs(trailingOnly=TRUE)
  if (length(requested) && !provider %in% requested) return(invisible(NULL))
  tryCatch({
    if (!nzchar(keys[[provider]])) stop("Missing provider credential")
    response <- request(); stop_for_status(response)
    parsed <- fromJSON(content(response, "text", encoding="UTF-8"), simplifyVector=FALSE)
    payload <- extract(parsed)
    write_json(payload, file.path("output/source_verification",paste0(id,"_",stamp,".json")), auto_unbox=TRUE, pretty=TRUE)
    cat(id, "HTTP", status_code(response), "saved data/metadata payload\n")
  }, error=function(e) {
    message <- conditionMessage(e)
    for (key in keys[nzchar(keys)]) message <- gsub(key,"[REDACTED]",message,fixed=TRUE)
    cat(id, "FAILED", message,"\n")
  })
}
bea_request <- function(table,line) GET("https://apps.bea.gov/api/data/", query=list(
  UserID=keys[["bea"]], method="GetData", DataSetName="Regional", TableName=table,
  LineCode=line, GeoFips="STATE", Year=paste(2015:2023,collapse=","), ResultFormat="JSON"),timeout(45))
bea_extract <- function(x) {
  if (is.null(x$BEAAPI$Results$Data)) stop("BEA response has no Data; API error or schema change")
  x$BEAAPI$Results
}
probe("bea_gdp","bea",function() bea_request("SAGDP9",1),bea_extract)
probe("bea_income","bea",function() bea_request("SAINC1",1),bea_extract)
probe("bea_construction_metadata","bea",function() GET("https://apps.bea.gov/api/data/",query=list(
  UserID=keys[["bea"]],method="GetParameterValuesFiltered",DataSetName="Regional",TargetParameter="LineCode",
  TableName="SAGDP9",ResultFormat="JSON"),timeout(45)),function(x) {
    values <- x$BEAAPI$Results$ParamValue
    matches <- Filter(function(v) tolower(trimws(v$Desc))=="construction",values)
    if (length(matches)!=1) matches <- Filter(function(v) grepl("construction",v$Desc,ignore.case=TRUE),values)
    if (length(matches)!=1) stop("Construction metadata not uniquely resolved")
    assign("construction_line",matches[[1]]$Key,envir=.GlobalEnv)
    matches
  })
if (exists("construction_line")) probe("bea_construction","bea",function() bea_request("SAGDP9",construction_line),bea_extract)
for (series in c("MORTGAGE30US","CPIAUCSL")) {
  probe(paste0("fred_",series),"fred",function() GET("https://api.stlouisfed.org/fred/series/observations",query=list(
    api_key=keys[["fred"]],series_id=series,file_type="json",observation_start="2014-01-01",observation_end="2023-12-31"),timeout(45)),
    function(x) {if (is.null(x$observations)) stop("FRED response has no observations"); x$observations})
}
states <- sprintf("%02d",c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56))
probe("bls_heavy_civil","bls",function() POST("https://api.bls.gov/publicAPI/v2/timeseries/data/",body=list(
  seriesid=as.list(paste0("SMU",states,"000002023700001")),startyear="2015",endyear="2023",registrationkey=keys[["bls"]]),
  encode="json",config(http_version=2L),timeout(45)),function(x) {
    if (!identical(x$status,"REQUEST_SUCCEEDED")) stop("BLS API did not report REQUEST_SUCCEEDED")
    list(status=x$status,message=x$message,Results=x$Results)
  })
