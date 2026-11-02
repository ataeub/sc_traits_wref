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
        )
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
        mutate(
          norm_dir = here::here(
            "data/processed/norm",
            paste0(fs::path_file(census_ctg_dir), "_norm")
          ),
          norm_veg_dir = here::here(
            "data/processed/norm_veg",
            paste0(fs::path_file(census_ctg_dir), "_norm_veg")
          ),
          dtm_dir = parameters$dtm_dir,
          single_tree_path = fs::path(
            here("data/processed/single_trees"),
            glue("s{STEM_TAG}_t{TREE_TAG}_c{CTFS_CENSUS}")
          )
        ) |>
        filter(CTFS_CENSUS == 3)
    }
  ),
  tar_target(
    name = ctg_dirs,
    command = census |>
      distinct(census_ctg_dir, norm_dir, norm_veg_dir) |>
      filter(!is.na(census_ctg_dir))
  ),
  tar_terra_rast(
    name = dtm,
    command = {
      dtm_files <- fs::dir_ls(
        parameters$dtm_dir,
        glob = "*.tif"
      )
      terra::vrt(dtm_files, here("data/processed/dtm.vrt"), overwrite = TRUE)
    }
  ),
  tar_target(
    name = ctg_norm,
    format = "file",
    command = normalize_ctg(ctg_dirs$census_ctg_dir, ctg_dirs$norm_dir, dtm),
    pattern = map(ctg_dirs)
  ),
  tar_target(
    name = ctg_norm_veg,
    format = "file",
    command = {
      ctg_norm # Referenced so this target re-runs when normalization changes
      filter_veg_ctg(ctg_dirs$norm_dir, ctg_dirs$norm_veg_dir)
    },
    pattern = map(ctg_dirs)
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
