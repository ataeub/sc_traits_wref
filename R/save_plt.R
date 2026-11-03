save_plt <- function(
  result_row,
  out_dir
) {
  tree <- paste0(
    "s",
    dplyr::pull(result_row, "STEM_TAG"),
    "_t",
    dplyr::pull(result_row, "TREE_TAG")
  )

  boxdim_plt <- dplyr::pull(result_row, "boxdim_plot")[[1]]
  enl_plt <- dplyr::pull(result_row, "enl_plot")[[1]]

  plt <- patchwork::wrap_plots(
    boxdim_plt,
    enl_plt,
    ncol = 2
  )

  ggplot2::ggsave(
    filename = paste0(tree, ".png"),
    plot = plt,
    path = out_dir,
    width = 12,
    height = 6
  )
}
