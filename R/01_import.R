# Pin original source bytes. No overwrite of original parsed data or pinned snapshots.
source('R/lib/common.R')
manifest<-read_csv('docs/source_manifest.csv',show_col_types=FALSE)
for(i in seq_len(nrow(manifest))) {
 row<-manifest[i,]
 if(file.exists(row$path)) {
  if(sha256(row$path)!=row$sha256) stop('Refusing changed snapshot: ',row$source_id)
  next
 }
 temporary<-tempfile(fileext=paste0('.',tools::file_ext(row$path)))
 if(file.exists(row$bootstrap_path)) {
  file.copy(row$bootstrap_path,temporary)
 } else if(row$kind=='public_original') {
  response<-httr::RETRY('GET',row$url,httr::write_disk(temporary,overwrite=TRUE),httr::timeout(60),times=3,terminate_on=c(400,401,403,404))
  httr::stop_for_status(response)
 } else stop('Pinned source missing: ',row$source_id,'. Restore archived snapshot or reacquire with R/00_verify_apis.R and review changed version before repinning.')
 if(sha256(temporary)!=row$sha256) stop('Source version changed: ',row$source_id,'; review before repinning')
 dir.create(dirname(row$path),recursive=TRUE,showWarnings=FALSE)
 stopifnot(file.copy(temporary,row$path,overwrite=FALSE));unlink(temporary)
}
source_manifest<-verify_manifest()
write_table(source_manifest,'input_manifest_used.csv')
message('Verified ',nrow(source_manifest),' immutable inputs; original parsed CSVs preserved.')
