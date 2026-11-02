filter_veg_ctg <- function(norm_dir, norm_veg_dir) {
  fs::dir_create(norm_veg_dir)
  ctg <- lidR::readLAScatalog(norm_dir)
  lidR::opt_filter(ctg) <- "-keep_class 3 4 5"
  lidR::opt_chunk_buffer(ctg) <- 0
  lidR::opt_laz_compression(ctg) <- TRUE
  lidR::opt_output_files(ctg) <- file.path(norm_veg_dir, "{*}_veg")

  select_veg <- function(cluster) {
    las <- lidR::readLAS(cluster)
    if (lidR::is.empty(las)) {
      return(NULL)
    }
    las
  }

  opt <- options(lidR.progress = FALSE)
  on.exit(options(opt))
  out <- lidR::catalog_apply(ctg, select_veg, .options = list(automerge = TRUE))
  # `rlas::writelax` makes the later `lidR::clip_roi` extremely fast compared to
  # without it.
  # Per writelax() handles one file at a time
  invisible(lapply(out$filename, rlas::writelax))
  out$filename
}
