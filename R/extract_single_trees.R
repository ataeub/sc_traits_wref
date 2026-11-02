extract_single_trees <- function(
  input_ctg,
  x,
  y,
  out_path
) {
  ctg <- lidR::readLAScatalog(input_ctg)

  pts <- sf::st_as_sf(
    data.frame(x = x, y = y),
    coords = c("x", "y"),
    crs = sf::st_crs(ctg)
  )

  opt_output_files(ctg) <- out_path
  opt_laz_compression(ctg) <- TRUE

  out <- clip_roi(ctg, pts, radius = 20)
  out$filename
}
