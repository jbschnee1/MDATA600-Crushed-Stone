# =============================================================================
# Crushed Stone Project - Clean and Derive Analysis Variables
# =============================================================================
# Reads minimally parsed raw imports and writes analysis-ready datasets. Run
# R/01_import.R first so all required raw files exist.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

analysis_start_year <- 2015L
analysis_end_year <- 2023L
analysis_years <- analysis_start_year:analysis_end_year

read_required_csv <- function(
  path,
  required_columns,
  col_types = readr::cols()
) {
  if (!file.exists(path)) {
    stop("Required raw file does not exist: ", path)
  }

  data <- readr::read_csv(
    path,
    col_types = col_types,
    show_col_types = FALSE
  )
  missing_columns <- setdiff(required_columns, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      path, " is missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  data
}

assert_unique_keys <- function(data, keys, source_name) {
  missing_keys <- data |>
    filter(if_any(all_of(keys), is.na))
  if (nrow(missing_keys) > 0L) {
    stop(source_name, " contains missing keys.")
  }

  duplicates <- data |>
    count(across(all_of(keys))) |>
    filter(.data$n != 1L)
  if (nrow(duplicates) > 0L) {
    stop(source_name, " contains duplicate keys.")
  }
  invisible(data)
}

write_clean_csv <- function(data, source, filename) {
  source_dir <- file.path("data", "clean", source)
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  output_path <- file.path(source_dir, filename)
  readr::write_csv(data, output_path, na = "")
  message("Wrote ", nrow(data), " rows to ", output_path)
  invisible(output_path)
}

fred_macro <- read_required_csv(
  file.path("data", "raw", "fred", "fred_mortgage_rates_inflation.csv"),
  c("year", "mortgage_rate_pct", "cpi_index")
)
assert_unique_keys(fred_macro, "year", "FRED macro data")
required_fred_years <- (analysis_start_year - 1L):analysis_end_year
missing_fred_years <- setdiff(required_fred_years, fred_macro$year)
if (length(missing_fred_years) > 0L) {
  stop(
    "FRED macro data are missing years needed for inflation: ",
    paste(missing_fred_years, collapse = ", "),
    ". Rerun R/01_import.R fred."
  )
}
fred_macro <- fred_macro |>
  arrange(.data$year) |>
  mutate(inflation_pct = 100 * (.data$cpi_index / lag(.data$cpi_index) - 1)) |>
  filter(.data$year %in% analysis_years)

write_clean_csv(
  fred_macro,
  "fred",
  "fred_mortgage_rates_inflation.csv"
)

bea_construction_gdp <- read_required_csv(
  file.path("data", "raw", "bea", "bea_construction_gdp.csv"),
  c("state_fips", "state", "year", "construction_real_gdp"),
  col_types = readr::cols(state_fips = readr::col_character())
)
assert_unique_keys(
  bea_construction_gdp,
  c("state_fips", "year"),
  "BEA construction GDP"
)
bea_construction_gdp <- bea_construction_gdp |>
  group_by(.data$state_fips, .data$state) |>
  arrange(.data$year, .by_group = TRUE) |>
  mutate(
    construction_real_gdp_growth_pct = 100 * (
      .data$construction_real_gdp / lag(.data$construction_real_gdp) - 1
    )
  ) |>
  ungroup()

write_clean_csv(
  bea_construction_gdp,
  "bea",
  "bea_construction_gdp.csv"
)

msha_stone_capacity <- read_required_csv(
  file.path("data", "raw", "msha", "msha_stone_capacity.csv"),
  c(
    "state_fips", "state", "year", "active_stone_mines",
    "stone_mine_employee_hours"
  ),
  col_types = readr::cols(state_fips = readr::col_character())
)
assert_unique_keys(
  msha_stone_capacity,
  c("state_fips", "year"),
  "MSHA stone capacity"
)
msha_stone_capacity <- msha_stone_capacity |>
  group_by(.data$state_fips, .data$state) |>
  arrange(.data$year, .by_group = TRUE) |>
  mutate(
    lag_active_stone_mines = lag(.data$active_stone_mines),
    lag_stone_mine_employee_hours = lag(.data$stone_mine_employee_hours)
  ) |>
  ungroup()

write_clean_csv(
  msha_stone_capacity,
  "msha",
  "msha_stone_capacity.csv"
)
