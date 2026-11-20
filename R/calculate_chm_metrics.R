# Canopy height metrics from the CHM tiles in `chm_dir` within a circle around
# each tree: mean, SD, max, CV, Gini and openness (share of circle pixels with
# height <= `gap_height`), plus a plot of the CHM pixels per tree (list column
# `chm_plot`). `trees` needs UTM_X/UTM_Y, STEM_TAG, TREE_TAG and CTFS_CENSUS
# columns; coordinates must be in the CRS of the CHM. Trees without a CHM (NA
# `chm_dir`) get NA metrics and no plot.
calculate_chm_metrics <- function(
  trees,
  chm_dir,
  radius,
  gap_height = 2,
  make_plots = TRUE
) {
  if (is.na(chm_dir)) {
    return(dplyr::mutate(
      trees,
      chm_mean = NA_real_,
      chm_sd = NA_real_,
      chm_max = NA_real_,
      chm_cv = NA_real_,
      chm_gini = NA_real_,
      chm_openness = NA_real_,
      chm_n_pixels = NA_integer_,
      chm_plot = list(NULL)
    ))
  }

  chm <- terra::vrt(fs::dir_ls(chm_dir, glob = "*.tif"))

  circles <- terra::buffer(
    terra::vect(
      as.data.frame(trees[, c("UTM_X", "UTM_Y")]),
      geom = c("UTM_X", "UTM_Y"),
      crs = terra::crs(chm)
    ),
    width = radius
  )

  # One call for all trees; ID is the row index of `trees`
  vals <- terra::extract(chm, circles, xy = TRUE)
  names(vals)[2] <- "z"
  vals <- dplyr::filter(vals, !is.na(z))

  metrics <- dplyr::reframe(vals, chm_stats(z, gap_height), .by = ID)

  tree_titles <- paste0(
    "s", trees$STEM_TAG, "_t", trees$TREE_TAG, "_c", trees$CTFS_CENSUS
  )
  pixels_by_tree <- split(vals, factor(vals$ID, levels = seq_len(nrow(trees))))

  plots <- lapply(seq_len(nrow(trees)), function(i) {
    if (!make_plots) {
      return(NULL)
    }
    plot_chm(pixels_by_tree[[i]], tree_titles[i], gap_height)
  })

  trees |>
    dplyr::mutate(ID = dplyr::row_number()) |>
    dplyr::left_join(metrics, by = "ID") |>
    dplyr::select(-ID) |>
    dplyr::mutate(chm_plot = plots)
}

# Summary statistics of the CHM heights `z` (all valid pixels of one circle).
# Mean, SD, max, CV and Gini use pixels with z >= 0; openness is the share of
# all pixels with z <= gap_height.
chm_stats <- function(z, gap_height) {
  zv <- z[z >= 0]
  z_mean <- mean(zv)
  z_sd <- if (length(zv) > 1) stats::sd(zv) else NA_real_

  tibble::tibble(
    chm_mean = z_mean,
    chm_sd = z_sd,
    chm_max = max(zv),
    chm_cv = z_sd / z_mean,
    chm_gini = gini(zv),
    chm_openness = mean(z <= gap_height),
    chm_n_pixels = length(zv)
  )
}

gini <- function(x) {
  x <- sort(x)
  n <- length(x)
  if (n < 2 || sum(x) == 0) {
    return(NA_real_)
  }
  2 * sum(seq_len(n) * x) / (n * sum(x)) - (n + 1) / n
}

# CHM pixels (columns x, y, z) of one tree, annotated with summary statistics
plot_chm <- function(pixels, plot_title, gap_height) {
  if (nrow(pixels) == 0) {
    return(NULL)
  }

  s <- chm_stats(pixels$z, gap_height)
  stat_label <- paste0(
    "<b>Max:</b> ", round(s$chm_max, 2), "<br>",
    "<b>Mean:</b> ", round(s$chm_mean, 2), "<br>",
    "<b>SD:</b> ", round(s$chm_sd, 2), "<br>",
    "<b>CV:</b> ", round(s$chm_cv, 2), "<br>",
    "<b>Gini:</b> ", round(s$chm_gini, 2), "<br>",
    "<b>Openness (&le; ", gap_height, " m):</b> ",
    round(s$chm_openness * 100, 1), "%<br><br>",
    "<span style='font-size:12pt'><b>Canopy Height (m)</b></span>"
  )

  ggplot2::ggplot(pixels, ggplot2::aes(x = x, y = y, fill = z)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_gradientn(
      colours = grDevices::hcl.colors(100, "viridis"),
      name = stat_label
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(title = plot_title, x = "X", y = "Y") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.title = ggtext::element_markdown(size = 11, lineheight = 1.5)
    )
}
