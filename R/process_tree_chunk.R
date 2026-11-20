process_tree_chunk <- function(
  trees,
  chm_dir,
  chm_radius,
  chm_gap_height,
  vox_res,
  boxdim_t,
  enl_layer_size,
  plot_dir
) {
  trees <- dplyr::select(trees, -dplyr::any_of(c("chunk", "tar_group")))

  # CHM metrics (incl. plots) are computed per chunk so that plots for the
  # full census are never held in memory at once
  chm_chunk <- calculate_chm_metrics(
    trees = trees,
    chm_dir = chm_dir,
    radius = chm_radius,
    gap_height = chm_gap_height
  ) |>
    dplyr::select(single_tree_path, dplyr::starts_with("chm_"), -chm_dir)

  lapply(seq_len(nrow(trees)), function(i) {
    tree <- trees[i, ]

    chm_row <- dplyr::filter(
      chm_chunk,
      single_tree_path == tree$single_tree_path
    )

    metrics <- calculate_cloud_metrics(
      cloud_path = tree$single_tree_path,
      plot_title = fs::path_ext_remove(fs::path_file(tree$single_tree_path)),
      vox_res = vox_res,
      boxdim_t = boxdim_t,
      enl_layer_size = enl_layer_size
    )

    plot_path <- save_plt(
      tree |>
        dplyr::bind_cols(metrics) |>
        dplyr::left_join(chm_row, by = "single_tree_path"),
      plot_dir
    )

    tree |>
      dplyr::bind_cols(
        dplyr::select(metrics, -cloud_path, -boxdim_plot, -enl_plot)
      ) |>
      dplyr::left_join(
        dplyr::select(chm_row, -chm_plot),
        by = "single_tree_path"
      ) |>
      dplyr::mutate(plot_path = as.character(plot_path))
  }) |>
    dplyr::bind_rows()
}
