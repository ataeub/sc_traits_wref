# Box-counting (Minkowski-Bouligand) dimension of a point cloud.
#
# Differs from coi::boxdim() in three ways:
#   * The box grid is anchored at the cloud (not at the coordinate origin), so
#     N does not depend on where the cloud sits in the coordinate system. For
#     voxelized clouds (`vox_res` given) the anchor is half a voxel below the
#     minimum point, i.e. at the lower edge of the first voxel (assumes points
#     are voxel centres, as returned by lidR::voxelize_points()).
#   * Box sizes are nested multiples of the smallest box, r = min_box * 2^k, so
#     every box is an exact union of the finest boxes. Box sizes that are not
#     multiples of the voxel size let voxels straddle boxes and alias N.
#   * Points on the upper edge of a box are assigned to that box (not the next
#     one), so the longest axis does not get a spurious extra slab.
#
# Like coi::boxdim(), the scales start from the bounding box: the coarsest box
# is the largest nested size that does not exceed half the largest cloud
# extent. All scales down to `min_box` are fitted. R2 and local slopes are
# returned so the linearity can be checked.
#
# cloud: matrix / data.frame whose first three columns are x, y, z (or named
#   x, y, z), e.g. a coi::as_pt_cld() object.
# vox_res: voxel size of an already voxelized cloud, or NULL for raw points.
#   Sets min_box to vox_res when min_box is not given.
# min_box: smallest box size. With nested sizes, vox_res itself is valid.
boxdim_fit <- function(
  cloud,
  vox_res = NULL,
  min_box = vox_res,
  plot = FALSE,
  plot_title = NULL
) {
  if (is.null(min_box) || !is.numeric(min_box) || length(min_box) != 1 ||
      min_box <= 0) {
    stop("Supply a positive min_box (or vox_res).")
  }
  if (!is.null(vox_res)) {
    ratio <- min_box / vox_res
    if (ratio < 1 - 1e-8 || abs(ratio - round(ratio)) > 1e-8) {
      warning(
        "min_box (", min_box, ") is not a whole multiple of vox_res (",
        vox_res, "). Boxes will cut through voxels and N may be aliased; ",
        "use min_box = vox_res or a whole multiple of it."
      )
    }
  }

  xyz <- as.matrix(cloud)
  if (all(c("x", "y", "z") %in% tolower(colnames(xyz)))) {
    xyz <- xyz[, match(c("x", "y", "z"), tolower(colnames(xyz)))]
  } else {
    xyz <- xyz[, 1:3]
  }
  xyz <- xyz[stats::complete.cases(xyz), , drop = FALSE]
  if (nrow(xyz) < 2) {
    stop("cloud needs at least two points.")
  }

  origin <- apply(xyz, 2, min) - if (is.null(vox_res)) 0 else vox_res / 2
  xyz <- sweep(xyz, 2, origin)
  max_box <- max(apply(xyz, 2, max))

  # Nested sizes min_box * 2^k up to half the bounding box, coarsest first
  k_max <- floor(log2(max_box / 2 / min_box))
  r_list <- if (k_max >= 0) min_box * 2^(k_max:0) else numeric()
  n_list <- vapply(
    r_list,
    function(r) {
      idx <- pmax(ceiling(xyz / r) - 1, 0)
      nrow(unique(idx))
    },
    integer(1)
  )

  scales <- tibble::tibble(
    r = r_list,
    n = n_list,
    log_inv_r = log(1 / r_list),
    log_n = log(n_list)
  )
  local_slopes <- diff(scales$log_n) / diff(scales$log_inv_r)

  if (nrow(scales) < 3) {
    warning(
      "Fewer than 3 box sizes available for the fit; returning NA. ",
      "Lower min_box."
    )
    out <- list(
      boxdim = NA_real_,
      r2 = NA_real_,
      n_scales = nrow(scales),
      local_slopes = local_slopes,
      scales = scales
    )
  } else {
    fit <- stats::lm(log_n ~ log_inv_r, data = scales)
    out <- list(
      boxdim = unname(stats::coef(fit)[2]),
      r2 = summary(fit)$r.squared,
      n_scales = nrow(scales),
      local_slopes = local_slopes,
      scales = scales
    )
  }

  if (plot) {
    if (is.null(plot_title)) {
      plot_title <- "Box dimension log-log regression"
    }
    p <- ggplot2::ggplot(scales, ggplot2::aes(x = log_inv_r, y = log_n)) +
      ggplot2::geom_point(size = 2) +
      ggplot2::labs(
        x = "log(1 / box size)",
        y = "log(N boxes)",
        title = plot_title,
        subtitle = sprintf(
          "Slope (box dimension) = %.3f, R2 = %.3f (%d scales)",
          out$boxdim,
          out$r2,
          out$n_scales
        )
      ) +
      ggplot2::theme_minimal()
    if (!is.na(out$boxdim)) {
      p <- p +
        ggplot2::geom_smooth(
          method = "lm",
          formula = y ~ x,
          se = FALSE,
          color = "steelblue",
          linewidth = 1
        )
    }
    out$plot <- p
  }

  out
}
