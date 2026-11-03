calculate_cloud_metrics <- function(
  cloud_path,
  plot_title,
  boxdim_t,
  enl_layer_size,
  vox_res = NULL,
  verbose = TRUE
) {
  if (isTRUE(verbose)) {
    message("Processing: ", fs::path_file(cloud_path))
  }

  cloud <- rlas::read.las(cloud_path, "xyz") |>
    coi::as_pt_cld()

  # boxdim_t is the finest box size; with vox_res it should be a whole
  # multiple of the voxel size
  cloud_boxdim <- boxdim_fit(
    cloud,
    vox_res = vox_res,
    min_box = boxdim_t,
    plot = TRUE,
    plot_title = plot_title
  )

  cloud_enl <- coi::enl(
    cloud,
    layer_thickness = enl_layer_size,
    plot = TRUE,
    plot_title = plot_title,
    warnings = FALSE
  )

  tibble::tibble(
    cloud_path = cloud_path,
    boxdim = cloud_boxdim$boxdim,
    boxdim_r2 = cloud_boxdim$r2,
    boxdim_n_scales = cloud_boxdim$n_scales,
    enl0 = cloud_enl$ENL0,
    enl1 = cloud_enl$ENL1,
    enl2 = cloud_enl$ENL2
  ) |>
    dplyr::mutate(
      boxdim_plot = list(cloud_boxdim$plot),
      enl_plot = list(cloud_enl$plot)
    )
}
