# =============================================================================
# Crushed Stone Project - Assemble the State-Year Analysis Panel
# =============================================================================
# Joins every available source variable to a 50-state by 2015-2023 backbone.
# Run R/02_clean.R first so derived variables are available.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

analysis_years <- 2015L:2023L
key_columns <- c("state_fips", "year")

state_lookup <- tibble(
  state = state.name,
  state_fips = c(
    "01", "02", "04", "05", "06", "08", "09", "10", "12", "13",
    "15", "16", "17", "18", "19", "20", "21", "22", "23", "24",
    "25", "26", "27", "28", "29", "30", "31", "32", "33", "34",
    "35", "36", "37", "38", "39", "40", "41", "42", "44", "45",
    "46", "47", "48", "49", "50", "51", "53", "54", "55", "56"
  )
)

read_state_year <- function(path, source_name) {
  if (!file.exists(path)) stop("Missing input for ", source_name, ": ", path)

  data <- read_csv(
    path,
    col_types = cols(state_fips = col_character()),
    show_col_types = FALSE
  )
  missing_keys <- setdiff(key_columns, names(data))
  if (length(missing_keys) > 0L) {
    stop(source_name, " is missing keys: ", paste(missing_keys, collapse = ", "))
  }

  # FHWA occasionally appends footnote markers to state names, which caused
  # the raw state-name lookup to miss a handful of FIPS codes.
  if ("state" %in% names(data) && anyNA(data$state_fips)) {
    repaired_keys <- data |>
      transmute(
        row_id = row_number(),
        state_clean = trimws(gsub(
          "[[:space:]]+(\\([0-9]+\\)|[0-9]+/)[[:space:]]*$", "", .data$state
        ))
      ) |>
      left_join(state_lookup, by = c("state_clean" = "state"))
    data$state_fips <- coalesce(data$state_fips, repaired_keys$state_fips)
  }
  if (anyNA(data$state_fips) || anyNA(data$year)) {
    stop(source_name, " contains missing state-year keys.")
  }
  duplicates <- data |>
    count(across(all_of(key_columns))) |>
    filter(.data$n > 1L)
  if (nrow(duplicates) > 0L) stop(source_name, " contains duplicate keys.")

  # State is the canonical panel identifier, so source copies are redundant.
  data |>
    select(-any_of("state"))
}

join_source <- function(panel, data, source_name) {
  overlapping <- intersect(setdiff(names(data), key_columns), names(panel))
  if (length(overlapping) > 0L) {
    stop(
      source_name, " has non-key columns already present in the panel: ",
      paste(overlapping, collapse = ", ")
    )
  }
  left_join(panel, data, by = key_columns)
}

panel <- crossing(
  state_fips = state_lookup$state_fips,
  year = analysis_years
) |>
  left_join(state_lookup, by = "state_fips") |>
  select("state_fips", "state", "year")

state_sources <- list(
  usgs = read_state_year(
    "data/raw/usgs/usgs_crushed_stone_production.csv", "USGS"
  ),
  census_bps = read_state_year(
    "data/raw/census/census_building_permits.csv", "Census BPS"
  ) |>
    rename(
      census_bps_time = "time",
      census_bps_state_name = "state_name"
    ),
  fhwa = read_state_year(
    "data/raw/fhwa/fhwa_state_capital_outlays.csv", "FHWA"
  ),
  bls = read_state_year(
    "data/raw/bls/bls_state_construction_employment.csv", "BLS"
  ),
  bea = read_state_year(
    "data/raw/bea/bea_state_gdp_personal_income.csv", "BEA"
  ),
  bea_construction = read_state_year(
    "data/clean/bea/bea_construction_gdp.csv", "BEA construction GDP"
  ),
  census_construction = read_state_year(
    "data/raw/census/census_construction_spending.csv",
    "Census construction spending"
  ),
  eia = read_state_year(
    "data/raw/eia/eia_energy_prices.csv", "EIA"
  ),
  msha = read_state_year(
    "data/clean/msha/msha_stone_capacity.csv", "MSHA"
  )
)

for (source_name in names(state_sources)) {
  panel <- join_source(panel, state_sources[[source_name]], source_name)
}

fred <- read_csv(
  "data/clean/fred/fred_mortgage_rates_inflation.csv",
  show_col_types = FALSE
)
if (anyDuplicated(fred$year)) stop("FRED contains duplicate years.")
panel <- left_join(panel, fred, by = "year") |>
  arrange(.data$state_fips, .data$year)

if (nrow(panel) != nrow(state_lookup) * length(analysis_years)) {
  stop("The assembled panel does not have the expected 450 rows.")
}
if (anyDuplicated(panel[key_columns])) {
  stop("The assembled panel contains duplicate state-year keys.")
}

output_path <- "data/processed/crushed_stone_state_year.csv"
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
write_csv(panel, output_path, na = "")

message(
  "Wrote ", nrow(panel), " rows and ", ncol(panel),
  " columns to ", output_path
)
