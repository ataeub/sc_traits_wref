process_tree_chunk <- function(
  trees,
  chm_metrics,
  vox_res,
  boxdim_t,
  enl_layer_size,
  plot_dir
) {
  trees <- dplyr::select(trees, -dplyr::any_of(c("chunk", "tar_group")))

  # Only the CHM rows for this chunk are needed
  chm_chunk <- dplyr::semi_join(chm_metrics, trees, by = "single_tree_path")

  lapply(seq_len(nrow(trees)), function(i) {
    tree <- trees[i, ]

    chm_row <- chm_chunk |>
      dplyr::filter(single_tree_path == tree$single_tree_path) |>
      dplyr::select(single_tree_path, dplyr::starts_with("chm_"), -chm_dir)

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
