extract_single_trees <- function(
  input_ctg,
  trees,
  out_template,
  radius = 20
) {
  ctg <- lidR::readLAScatalog(input_ctg)

  # Columns of `trees` are kept as attributes so that `out_template`
  # placeholders like {STEM_TAG} resolve per tree
  pts <- sf::st_as_sf(
    trees,
    coords = c("UTM_X", "UTM_Y"),
    crs = sf::st_crs(ctg)
  )

  lidR::opt_output_files(ctg) <- out_template
  lidR::opt_laz_compression(ctg) <- TRUE

  out <- lidR::clip_roi(ctg, pts, radius = radius)
  out$filename
}
