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

  chm_plt <- dplyr::pull(result_row, "chm_plot")[[1]]

  # chm_plot is NULL for trees without a CHM
  plots <- Filter(Negate(is.null), list(boxdim_plt, enl_plt, chm_plt))

  plt <- patchwork::wrap_plots(plots, nrow = 1)

  ggplot2::ggsave(
    filename = paste0(tree, ".png"),
    plot = plt,
    path = out_dir,
    width = 6 * length(plots),
    height = 6
  )
}
