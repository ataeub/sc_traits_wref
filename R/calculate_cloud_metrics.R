calculate_cloud_metrics <- function(
  cloud_path,
  plot_title,
  boxdim_t = 0.1,
  enl_layer_size = 5,
  verbose = TRUE
) {
  if (isTRUE(verbose)) {
    message("Processing: ", fs::path_file(cloud_path))
  }

  cloud <- rlas::read.las(cloud_path, "xyz") |>
    coi::as_pt_cld()

  cloud_boxdim <- coi::boxdim(
    cloud,
    threshold = boxdim_t,
    plot = TRUE,
    plot_title = plot_title,
    warnings = FALSE
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
    enl0 = cloud_enl$ENL0,
    enl1 = cloud_enl$ENL1,
    enl2 = cloud_enl$ENL2
  ) |>
    dplyr::mutate(
      boxdim_plot = list(cloud_boxdim$plot),
      enl_plot = list(cloud_enl$plot)
    )
}
