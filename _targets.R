library(targets)
library(geotargets)

tar_option_set(
  packages = c(
    "dplyr",
    "fs",
    "glue",
    "here",
    "readr",
    "tibble",
    "lidR",
    "terra",
    "sf"
  )
)

tar_source()


list(
  tar_target(
    name = data_dirs,
    command = {
      dirs <- here(c(
        "data/raw/als_clouds",
        "data/raw/dtm",
        "data/raw/tree_census",
        "data/processed/norm",
        "data/processed/norm_veg",
        "data/processed/single_trees",
        "data/results"
      ))
      as.character(fs::dir_create(dirs))
    }
  ),
  tar_target(
    name = parameters,
    command = {
      # Referenced so the directories exist before parameters is built
      data_dirs
      set_parameters(
        census_2011_path = here(
          "data/raw/tree_census/wfdp_Tree_CTFS_Census_1_20260416.csv"
        ),
        census_2016_path = here(
          "data/raw/tree_census/wfdp_Tree_CTFS_Census_2_20260416.csv"
        ),
        census_2021_path = here(
          "data/raw/tree_census/wfdp_Tree_CTFS_Census_3_20260416.csv"
        ),

        # These are not available on NEON (likely non-existing)
        clouds_2011_dir = NA_character_,
        clouds_2016_dir = NA_character_,
        clouds_2021_dir = here(
          "data/raw/als_clouds/NEON.D16.WREF.DP1.30003.001.2021-07.basic.20261026T180824Z.RELEASE-2026"
        ),
        dtm_dir = here(
          "data/raw/dtm/NEON.D16.WREF.DP3.30024.001.2023-06.basic.20261030T121746Z.RELEASE-2026"
        ),
        prep_dtm_path = here("data/processed/dtm.vrt"),
        norm_clouds_dir = here("data/processed/norm"),
        norm_clouds_path = here("data/processed/norm/{*}_norm"),
        norm_veg_clouds_dir = here("data/processed/norm_veg"),
        norm_veg_clouds_path = here("data/processed/norm_veg/{*}_veg"),
        single_tree_clouds_dir = here("data/processed/single_trees")
      )
    }
  ),
  tar_target(
    name = census_2011,
    command = read_census(parameters$census_2011_path)
  ),
  tar_target(
    name = census_2016,
    command = read_census(parameters$census_2016_path)
  ),
  tar_target(
    name = census_2021,
    command = read_census(parameters$census_2021_path)
  ),
  tar_target(
    name = census,
    command = {
      bind_rows(census_2011, census_2016, census_2021) |>
        mutate(
          single_tree_path = fs::path(
            parameters$single_tree_clouds_dir,
            glue("s{STEM_TAG}_t{TREE_TAG}_c{CTFS_CENSUS}")
          ),
          dtm_dir = parameters$dtm_dir
        ) |>
        rowwise() |>
        mutate(
          census_ctg_dir = {
            if (CTFS_CENSUS == 1) {
              parameters$clouds_2011_dir
            } else if (CTFS_CENSUS == 2) {
              parameters$clouds_2016_dir
            } else if (CTFS_CENSUS == 3) {
              parameters$clouds_2021_dir
            }
          }
        ) |>
        ungroup() |>
        filter(CTFS_CENSUS == 3)
    }
  ),
  tar_terra_rast(
    name = dtm,
    command = {
      dtm_files <- fs::dir_ls(
        parameters$dtm_dir,
        glob = "*.tif"
      )
      terra::vrt(dtm_files, parameters$prep_dtm_path, overwrite = TRUE)
    }
  ),
  tar_target(
    name = ctg_norm,
    format = "file",
    command = {
      ctg <- readLAScatalog(parameters$clouds_2021_dir)
      opt_chunk_buffer(ctg) <- 1
      opt_chunk_size(ctg) <- 0
      opt_laz_compression(ctg) <- TRUE
      opt_output_files(ctg) <- parameters$norm_clouds_path
      out <- normalize_height(ctg, dtm)
      out$filename
    }
  ),
  tar_target(
    name = ctg_norm_veg,
    format = "file",
    command = {
      ctg_norm <- readLAScatalog(parameters$norm_clouds_dir)
      opt_filter(ctg_norm) <- "-keep_class 3 4 5"
      # Classification filtering is a per-point operation with no need for
      # neighbouring context. catalog_apply() (unlike catalog_map()) does not
      # crop the buffer before writing, so leaving the default 30 m buffer
      # made each written tile bleed into its neighbour, producing genuinely
      # overlapping output tiles.
      opt_chunk_buffer(ctg_norm) <- 0
      opt_laz_compression(ctg_norm) <- TRUE
      opt_output_files(ctg_norm) <- parameters$norm_veg_clouds_path
      select_veg <- function(cluster) {
        las <- readLAS(cluster) # applies the -keep_class filter
        if (lidR::is.empty(las)) {
          return(NULL)
        }
        las # lidR writes it to opt_output_files
      }
      opt <- options(lidR.progress = FALSE)
      on.exit(options(opt))
      out <- catalog_apply(
        ctg_norm,
        select_veg,
        .options = list(automerge = TRUE)
      )
      out$filename
    }
  ),
  tar_target(
    name = single_tree_clouds,
    format = "file",
    command = extract_single_trees(
      input_ctg = census$census_ctg_dir,
      x = census$UTM_X,
      y = census$UTM_Y,
      out_path = census$single_tree_path
    ),
    pattern = map(census)
  )
)
