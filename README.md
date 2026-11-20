# SC Traits with WREF

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

Please remember to attribute the following authors when using this repo:

- [NEON](https://www.neonscience.org/data)
- [Seidel et al. (2018)](https://doi.org/10.1002/ece3.3661) for the structural complexity/Box dimension calculation
- [Ehbrecht et al. (2016)](https://doi.org/10.1016/j.foreco.2016.09.003) for the effective number of layers calculation
- The authors of the `lidR` and `targets` packages, which are integral for this pipeline

Please also attribute me according to the CC-BY license, when forking or using this repo directly.

## 1. Requirements

- R 4.6 or newer

- R packages:

```r
install.packages(c(
  "targets", "geotargets", "crew", "dplyr", "fs", "glue", "here",
  "readr", "tibble", "lidR", "rlas", "terra", "sf", "ggplot2",
  "ggtext", "patchwork", "remotes"
))
remotes::install_github("ataeub/coi", ref = "v2.4.0")
```

## 2. Prepare the data directory

Once all packages are installed run

```r
targets::tar_make(data_dirs)
``` 

once to create the following data directory structure:

```text
data/
├── raw/
│   ├── als_clouds/
│   ├── chm/
│   ├── dtm/
│   └── tree_census/
├── processed/
│   ├── norm/
│   ├── norm_veg/
│   └── single_trees/
└── results/
    └── figures/
        └── structure_plots/
```

Then you will need to insert the following [NEON](https://data.neonscience.org/data-products/explore) datasets in the following manner:

Into `data/raw/tree_census/` place the census CSVs for the given years.

Into `data/raw/als_clouds/` place the folder with the LAS/LAZ files from the NEON [DP1.30003.001](https://data.neonscience.org/data-products/DP1.30003.001) datasets for a given tile and year.

Into `data/raw/chm/` place the folder with the respective TIF files from the NEON [DP3.30015.001](https://data.neonscience.org/data-products/DP3.30015.001) datasets for a given tile and year.

Finally, into `data/raw/dtm/` place directly the TIF files (with no folder) from the NEON [DP3.30024.001](https://data.neonscience.org/data-products/DP3.30024.001) dataset. Make sure you *use the DTM* and *NOT the DSM* as only the DTM is the actual ground with the trees removed, which is needed for normalization.

The final directory will look similar to this:

```text
data/raw
├── als_clouds
│   └── NEON.D16.WREF.DP1.30003.001.2021-07.basic.20261026T180824Z.RELEASE-2026
│       ├── NEON_D16_WREF_DP1_580000_5074000_classified_point_cloud_colorized.laz
│       └── NEON_D16_WREF_DP1_581000_5074000_classified_point_cloud_colorized.laz
├── chm
│   └── NEON.D16.WREF.DP3.30015.001.2021-07.basic.20261030T130634Z.RELEASE-2026
│       ├── NEON_D16_WREF_DP3_580000_5074000_CHM.tif
│       └── NEON_D16_WREF_DP3_581000_5074000_CHM.tif
├── dtm
│   └── NEON.D16.WREF.DP3.30024.001.2023-06.basic.20261030T121746Z.RELEASE-2026
│       ├── NEON_D16_WREF_DP3_580000_5074000_DTM.tif
│       └── NEON_D16_WREF_DP3_581000_5074000_DTM.tif
└── tree_census
    ├── wfdp_Tree_CTFS_Census_1_20260416.csv
    ├── wfdp_Tree_CTFS_Census_2_20260416.csv
    └── wfdp_Tree_CTFS_Census_3_20260416.csv
```

The census CSVs must use the same column names and types expected by `R/census_prep.R`, especially `STEM_TAG`, `TREE_TAG`, `CTFS_CENSUS`, `UTM_X`, and `UTM_Y`.

For the ALS cloud and CHM folders, `_targets.R` currently uses specific NEON release directories. The lidar catalog must contain LAS/LAZ tiles, and the DTM/CHM directories must contain TIFF tiles with a spatial reference compatible with the census coordinates.

The data directories are intentionally excluded from Git. Download or copy them into `data/raw/` on each machine without renaming files or folders unless `_targets.R` is updated accordingly.

## 3. Configure the pipeline

Parameters are set in `_targets.R` in the `parameters` target. Before running, update if necessary:

- `census_*_path`: census CSV locations
- `clouds_*_dir`: LAS/LAZ catalog locations
- `chm_*_dir`: CHM TIFF catalog locations
- `dtm_dir`: DTM TIFF catalog location
- `ln_radius`: Radius in map units (meters) used to extract and sample around each tree
- `chm_gap_height`: Height cutoff used to calculate canopy openness. Cells lower than this value in the CHM will be labeled as "open" and affect the openness result
- `voxel_res`: Voxel size used in single-tree clouds
- `boxdim_t`: Minimum box size used for box-dimension fitting
- `enl_layer_size`: Layer thickness used for effective number of layers (ENL) calculations

Set unavailable census-years or data sources to `NA_character_`. The current configuration processes `CTFS_CENSUS == 3` only, as point clouds on NEON are only available for this year (2021).

To add additional census years (given that the data structure doesn't change) you will have to:
- add the respective arguments to parameters
- add the respective `census_YEAR` targets
- add the respective logic in the `census` target

## 4. Run the pipeline

Once everything is set up, run the complete workflow from the repository root:

```r
targets::tar_make()
```

The pipeline will take a relatively long time to run depending on the system configuration and especially in the first run.
The first run will extract the single neighbourhoods from the complete point clouds, normalize and extract the vegetation points.
Once this has been run the pipeline will automatically skip this step in further runs, unless you change parameters relevant for this.
You can drastically speed up the subsequent runs by setting `save_plots <- FALSE` at the top of `_targets.R`, this will skip the plotting for the structural parameters, which you might only need for an initial check.

The pipeline:

1. Validates/Creates the required directory structure through `data_dirs`.
2. Reads and combines the census files.
3. Loads the DTM and creates `data/processed/dtm.vrt`.
4. Normalizes the ALS catalogs into `data/processed/norm/`.
5. Filters only the vegetation points(Point class 3, 4, and 5) into `data/processed/norm_veg/`.
6. Groups trees into chunks of up to 50 trees by normalized-cloud and CHM source (For better pipeline parallelization).
7. Extracts individual single-tree clouds into `data/processed/single_trees/`.
8. Calculates CHM and point-cloud metrics.
9. Writes combined structure plots to `data/results/figures/structure_plots/` (skipped if `save_plots <- FALSE`).
10. Writes the combined results table to `data/results/census_with_results.csv`.

The pipeline can use up to six local workers by default. This is configured in `_targets.R` with `crew_controller_local(workers = 6)`. You can (should) adjust this value based on the computing machines number of physical CPU cores and available memory. 

## 5. Inspect the results

The pipeline will directly output the results into `data/results/census_with_results.csv`.

The plots to inspect the structural variables visually are saved into `data/results/figures/structure_plots` (only if `save_plots <- TRUE`; the `plot_path` column is `NA` otherwise).

## License

Copyright (c) 2026 Alexander Täuber. This work is licensed under the [Creative Commons Attribution 4.0 International License](LICENSE) (CC BY 4.0). You may share and adapt it, including commercially, as long as you give appropriate credit, link to the license, and indicate changes.