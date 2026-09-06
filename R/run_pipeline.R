# Entry point: Rscript --vanilla R/run_pipeline.R [data|development|all]
arguments<-commandArgs(trailingOnly=TRUE)
stage<-if(length(arguments)) arguments[1] else 'data'
stopifnot(stage %in% c('data','development','all'))
if(!file.exists('astra_mdata_middle_approach.md')) stop('Run from the project root')
source('R/lib/common.R')
original_paths<-list.files('data/raw',recursive=TRUE,full.names=TRUE,pattern='[.]csv$')
raw_before<-setNames(vapply(original_paths,sha256,character(1)),original_paths)
for(script in c('R/01_import.R','R/02_clean.R','R/03_join.R')) source(script)
if(stage!='data') {source('R/04_eda.R');source('R/05_models.R');source('R/05_diagnostics.R')}
if(stage=='all') {source('R/06_evaluate.R');source('R/07_explanation.R');source('R/08_gate2.R')}
stopifnot(all(vapply(names(raw_before),sha256,character(1))==raw_before))
writeLines(capture.output(sessionInfo()),'output/logs/session_info.txt')
message('Pipeline stage ',stage,' completed; original raw CSV hashes unchanged.')
