# Explicit, uniform column types for all three census files. Left to its own
# guessing, readr infers types per file from a sample of rows, which produces
# inconsistent types across census years for sparsely-populated columns (e.g.
# FIELD_3-FIELD_5 guess as character when they hold recorder names but as
# logical when the column is almost entirely empty). Pinning the spec keeps
# the three censuses directly comparable/bindable.
tree_census_col_types <- readr::cols(
  STEM_TAG = readr::col_character(),
  TREE_TAG = readr::col_character(),
  CTFS_CENSUS = readr::col_double(),
  QUADRAT = readr::col_character(),
  SPECIES = readr::col_character(),
  DBH = readr::col_double(),
  VIGOR = readr::col_double(),
  CTFS_DA = readr::col_character(),
  OTHER_HOM = readr::col_double(),
  QX = readr::col_double(),
  QY = readr::col_double(),
  PLOT_X = readr::col_double(),
  PLOT_Y = readr::col_double(),
  UTM_X = readr::col_double(),
  UTM_Y = readr::col_double(),
  # Parsed to Date manually below (not col_date()) so a placeholder "00" day
  # can fall back to the 1st of the month instead of becoming NA.
  DATE = readr::col_character(),
  FIELD_1 = readr::col_character(),
  FIELD_2 = readr::col_character(),
  FIELD_3 = readr::col_character(),
  FIELD_4 = readr::col_character(),
  FIELD_5 = readr::col_character()
)

read_census <- function(file) {
  data <- read_csv(
    file,
    # The exports use the literal text "NULL" (not an empty field) to mark
    # missing values; treat it as NA alongside readr's own defaults.
    na = c("", "NA", "NULL"),
    col_types = tree_census_col_types
  )
  problems_main <- problems(data)
  attr(data, "problems") <- NULL

  # A run of records record an unknown day-of-month as "00"
  # (e.g. "2021-06-00"). Fall back to the 1st of that month so the
  # year/month stay usable, instead of discarding the whole date as NA.
  raw_date <- data$DATE
  fixed_date <- sub("-00$", "-01", raw_date)
  parsed_date <- as.Date(fixed_date, format = "%Y-%m-%d")

  # Anything that still fails to parse is a genuine problem (not just an
  # unknown day), recorded in the same shape as readr::problems().
  still_bad <- is.na(parsed_date) & !is.na(raw_date)
  problems_date <- tibble(
    row = which(still_bad),
    col = which(names(data) == "DATE"),
    expected = "date in ISO8601",
    actual = raw_date[still_bad],
    file = file
  )

  data$DATE <- parsed_date
  data
}
