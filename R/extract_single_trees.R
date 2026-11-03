extract_single_trees <- function(
  input_ctg,
  trees,
  out_template,
  radius,
  voxel_res = NULL
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
  files <- out$filename

  # Voxelize each clipped tree in place when a resolution is supplied
  if (!is.null(voxel_res)) {
    for (f in files) {
      las <- lidR::readLAS(f)
      if (lidR::is.empty(las)) {
        next
      }
      lidR::writeLAS(lidR::voxelize_points(las, voxel_res), f)
    }
  }

  fs::path(files)
}
