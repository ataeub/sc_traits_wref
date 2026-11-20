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
    "targets",
    "sf"
  ),
  controller = crew::crew_controller_local(workers = 6)
)

tar_source()

# Toggle plot saving. Deliberately not part of `parameters`, so changing it
# only invalidates census_with_results (and downstream), not the structural
# targets (normalization, single-tree extraction).
save_plots <- TRUE

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
        "data/results/figures/structure_plots"
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

        chm_2011_dir = NA_character_,
        chm_2016_dir = NA_character_,
        chm_2021_dir = here(
          "data/raw/chm/NEON.D16.WREF.DP3.30015.001.2021-07.basic.20261030T130634Z.RELEASE-2026"
        ),

        # These first two are not available on NEON (likely non-existing)
        clouds_2011_dir = NA_character_,
        clouds_2016_dir = NA_character_,
        clouds_2021_dir = here(
          "data/raw/als_clouds/NEON.D16.WREF.DP1.30003.001.2021-07.basic.20261026T180824Z.RELEASE-2026"
        ),
        dtm_dir = here(
          "data/raw/dtm/NEON.D16.WREF.DP3.30024.001.2023-06.basic.20261030T121746Z.RELEASE-2026"
        ),

        ln_radius = 20,
        # Pixels at or below this height count as canopy gaps (openness)
        chm_gap_height = 2,
        voxel_res = 1,
        boxdim_t = 2,
        enl_layer_size = 5
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
          census_ctg_dir = case_when(
            CTFS_CENSUS == 1 ~ parameters$clouds_2011_dir,
            CTFS_CENSUS == 2 ~ parameters$clouds_2016_dir,
            CTFS_CENSUS == 3 ~ parameters$clouds_2021_dir
          ),
          chm_dir = case_when(
            CTFS_CENSUS == 1 ~ parameters$chm_2011_dir,
            CTFS_CENSUS == 2 ~ parameters$chm_2016_dir,
            CTFS_CENSUS == 3 ~ parameters$chm_2021_dir
          ),
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
            glue("s{STEM_TAG}_t{TREE_TAG}_c{CTFS_CENSUS}.laz")
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
    name = census_chunks,
    command = census |>
      dplyr::arrange(norm_veg_dir, chm_dir, single_tree_path) |>
      dplyr::mutate(
        chunk = ceiling(dplyr::row_number() / 50),
        .by = c(norm_veg_dir, chm_dir)
      ) |>
      dplyr::group_by(norm_veg_dir, chm_dir, chunk) |>
      targets::tar_group(),
    iteration = "group"
  ),
  tar_target(
    name = single_tree_clouds,
    format = "file",
    command = {
      ctg_norm_veg # Referenced so this re-runs when the veg clouds change
      extract_single_trees(
        input_ctg = unique(census_chunks$norm_veg_dir),
        trees = census_chunks,
        out_template = file.path(
          here("data/processed/single_trees"),
          "s{STEM_TAG}_t{TREE_TAG}_c{CTFS_CENSUS}"
        ),
        radius = parameters$ln_radius,
        voxel_res = parameters$voxel_res
      )
    },
    pattern = map(census_chunks)
  ),
  tar_target(
    name = census_with_results,
    command = {
      # Branch-aligned with the chunk's clouds so metrics can start as soon as
      # a chunk is extracted
      single_tree_clouds
      process_tree_chunk(
        trees = census_chunks,
        chm_dir = unique(census_chunks$chm_dir),
        chm_radius = parameters$ln_radius,
        chm_gap_height = parameters$chm_gap_height,
        vox_res = parameters$voxel_res,
        boxdim_t = parameters$boxdim_t,
        enl_layer_size = parameters$enl_layer_size,
        plot_dir = here("data/results/figures/structure_plots"),
        save_plots = save_plots
      )
    },
    pattern = map(census_chunks, single_tree_clouds)
  ),
  tar_target(
    name = census_with_results_file,
    command = {
      out_file <- here("data/results/census_with_results.csv")
      readr::write_csv(census_with_results, out_file)
      out_file
    },
    format = "file"
  )
)
