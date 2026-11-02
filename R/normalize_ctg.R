normalize_ctg <- function(ctg_dir, norm_dir, dtm) {
  if (!fs::dir_exists(ctg_dir)) {
    stop(glue::glue("Cloud directory does not exist: {ctg_dir}"))
  }
  fs::dir_create(norm_dir)
  ctg <- lidR::readLAScatalog(ctg_dir)
  lidR::opt_chunk_buffer(ctg) <- 1
  lidR::opt_chunk_size(ctg) <- 0
  lidR::opt_laz_compression(ctg) <- TRUE
  lidR::opt_output_files(ctg) <- file.path(norm_dir, "{*}_norm")
  out <- lidR::normalize_height(ctg, dtm)
  out$filename
}