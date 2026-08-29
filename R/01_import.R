# =============================================================================
# Crushed Stone Project - Import and Raw Data Pull
# =============================================================================
# Pulls and minimally parses all source data used by the state-year analysis.
# Run this file from the project root. Derived variables are created in
# R/02_clean.R. API keys may be defined in an untracked api-keys.R file or
# supplied as BEA_KEY, BLS_KEY, and FRED_KEY environment variables.
# Pass a comma-separated source list to refresh selected imports, for example:
#   Rscript R/01_import.R usgs,fred

suppressPackageStartupMessages({
  library(dplyr)
  library(httr)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(readxl)
  library(tibble)
  library(tidyr)
})

analysis_start_year <- 2015L
analysis_end_year <- 2023L
analysis_years <- analysis_start_year:analysis_end_year

available_sources <- c(
  "usgs", "census_bps", "fhwa", "bls", "bea", "fred",
  "bea_construction", "census_construction", "eia", "msha"
)
arguments <- commandArgs(trailingOnly = TRUE)
requested_sources <- if (length(arguments) == 0L) {
  available_sources
} else {
  trimws(strsplit(arguments[[1]], ",", fixed = TRUE)[[1]])
}
unknown_sources <- setdiff(requested_sources, available_sources)
if (length(unknown_sources) > 0L) {
  stop(
    "Unknown import source(s): ", paste(unknown_sources, collapse = ", "),
    ". Choose from: ", paste(available_sources, collapse = ", ")
  )
}

should_import <- function(source) source %in% requested_sources

key_environment <- new.env(parent = baseenv())
if (file.exists("/Users/jschnee12/Library/Mobile Documents/com~apple~CloudDocs/MDATA600-Crushed-Stone/api-keys.R")) {
  sys.source("/Users/jschnee12/Library/Mobile Documents/com~apple~CloudDocs/MDATA600-Crushed-Stone/api-keys.R", envir = key_environment)
}

get_api_key <- function(object_name, environment_name) {
  if (exists(object_name, envir = key_environment, inherits = FALSE)) {
    return(get(object_name, envir = key_environment, inherits = FALSE))
  }
  Sys.getenv(environment_name, unset = NA_character_)
}

bea_key <- get_api_key("bea_key", "BEA_KEY")
bls_key <- get_api_key("bls_key", "BLS_KEY")
fred_key <- get_api_key("fred_key", "FRED_KEY")

require_api_key <- function(key, key_name) {
  if (length(key) != 1L || is.na(key) || !nzchar(key)) {
    stop(
      key_name,
      " is missing. Define it in api-keys.R or its corresponding ",
      "environment variable."
    )
  }
  invisible(key)
}

mean_or_na <- function(x) {
  if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
}

assert_required_columns <- function(data, required, source_name) {
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      source_name, " schema is missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  invisible(data)
}

validate_state_year_panel <- function(
  data,
  years,
  source_name,
  require_complete = TRUE
) {
  assert_required_columns(data, c("state_fips", "year"), source_name)
  if (nrow(data) == 0L) {
    stop(source_name, " returned no rows.")
  }

  missing_keys <- data |>
    filter(is.na(.data$state_fips) | is.na(.data$year))
  if (nrow(missing_keys) > 0L) {
    stop(source_name, " contains rows with missing state-year keys.")
  }

  duplicates <- data |>
    count(.data$state_fips, .data$year) |>
    filter(.data$n != 1L)
  if (nrow(duplicates) > 0L) {
    stop(source_name, " contains duplicate state-year rows.")
  }

  expected <- tidyr::crossing(
    state_fips = state_fips_lookup$state_fips,
    year = as.integer(years)
  )
  observed <- distinct(data, .data$state_fips, .data$year)
  unexpected <- anti_join(
    observed,
    expected,
    by = c("state_fips", "year")
  )
  if (nrow(unexpected) > 0L) {
    stop(source_name, " contains unexpected state-year keys.")
  }

  missing <- anti_join(
    expected,
    observed,
    by = c("state_fips", "year")
  )

  if (nrow(missing) > 0L) {
    detail <- paste0(
      nrow(missing), " state-year rows are missing (",
      n_distinct(missing$state_fips), " states affected)."
    )
    if (require_complete) {
      stop(source_name, " ", detail)
    }
    warning(source_name, " ", detail, call. = FALSE)
  }

  message(
    source_name, " rows: ", nrow(data),
    "; states: ", n_distinct(data$state_fips),
    "; years: ", min(data$year), "-", max(data$year)
  )
  invisible(data)
}

write_raw_csv <- function(data, source, filename) {
  source_dir <- file.path("data", "raw", source)
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  output_path <- file.path(source_dir, filename)
  readr::write_csv(data, output_path, na = "")
  message("Wrote ", nrow(data), " rows to ", output_path)
  invisible(output_path)
}

state_fips_lookup <- tibble(
  state = state.name,
  state_fips = c(
    "01", "02", "04", "05", "06", "08", "09", "10", "12", "13",
    "15", "16", "17", "18", "19", "20", "21", "22", "23", "24",
    "25", "26", "27", "28", "29", "30", "31", "32", "33", "34",
    "35", "36", "37", "38", "39", "40", "41", "42", "44", "45",
    "46", "47", "48", "49", "50", "51", "53", "54", "55", "56"
  )
)

# 1. USGS - State Crushed-Stone Production
# =============================================================================
# Current USGS aggregates time-series release:
#   USGS_Aggregates_Data-1971-2023.xlsx
#
# This is a direct Excel download, not a JSON API. The earlier script used an
# older 2022 Minerals Yearbook workbook; this version uses the state time-series
# dataset designed for longitudinal analysis.

usgs_crushed_stone_url <- paste0(
  "https://d9-wret.s3.us-west-2.amazonaws.com/assets/palladium/production/",
  "s3fs-public/media/files/USGS_Aggregates_Data-1971-2023.xlsx"
)

get_usgs_crushed_stone <- function(
  url = usgs_crushed_stone_url,
  years = analysis_years,
  sheet = "Data_1971_2023"
) {
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)

  download.file(
    url,
    destfile = tmp,
    mode = "wb",
    method = "libcurl",
    quiet = TRUE
  )

  if (!sheet %in% excel_sheets(tmp)) {
    stop(
      "USGS workbook downloaded, but expected sheet '", sheet,
      "' was not found. Available sheets: ",
      paste(excel_sheets(tmp), collapse = ", ")
    )
  }

  parse_usgs_number <- function(x) {
    suppressWarnings(
      readr::parse_number(
        as.character(x),
        na = c("", "NA", "--", "W", "Withheld")
      )
    )
  }

  raw <- read_excel(tmp, sheet = sheet)
  assert_required_columns(
    raw,
    c(
      "Commodity", "Data Description", "Year", "State Coverage", "Region",
      "Division", "Quantity", "Total Value", "Unit Value"
    ),
    "USGS crushed-stone workbook"
  )

  raw |>
    filter(
      Commodity == "Stone, crushed",
      `Data Description` == "State totals",
      Year %in% years
    ) |>
    transmute(
      year = as.integer(Year),
      state = `State Coverage`,
      region = Region,
      division = Division,
      crushed_stone_tons = parse_usgs_number(Quantity),
      crushed_stone_total_value = parse_usgs_number(`Total Value`),
      crushed_stone_unit_value = parse_usgs_number(`Unit Value`)
    ) |>
    left_join(state_fips_lookup, by = "state") |>
    relocate(state_fips, .after = state) |>
    arrange(state, year)
}

if (should_import("usgs")) {
  usgs_stone <- get_usgs_crushed_stone()
  validate_state_year_panel(usgs_stone, analysis_years, "USGS crushed stone")
  write_raw_csv(usgs_stone, "usgs", "usgs_crushed_stone_production.csv")
}

# =============================================================================

# 2. Census - Building Permits Survey (annual state flat files)
# =============================================================================
# BPS state annual data are published as flat files at:
#   https://www2.census.gov/econ/bps/State/stYYYYa.txt
#
# The Census directory currently contains annual files through 2025, but this
# script uses analysis_years so the predictor aligns with USGS through 2023.

bps_state_col_names <- c(
  "time", "state_fips", "region_code", "division_code", "state_name",
  "bldgs_1unit", "units_1unit", "value_1unit",
  "bldgs_2unit", "units_2unit", "value_2unit",
  "bldgs_34unit", "units_34unit", "value_34unit",
  "bldgs_5punit", "units_5punit", "value_5punit",
  "bldgs_1unit_rep", "units_1unit_rep", "value_1unit_rep",
  "bldgs_2unit_rep", "units_2unit_rep", "value_2unit_rep",
  "bldgs_34unit_rep", "units_34unit_rep", "value_34unit_rep",
  "bldgs_5punit_rep", "units_5punit_rep", "value_5punit_rep"
)

get_census_building_permits <- function(years = analysis_years) {
  urls <- sprintf(
    "https://www2.census.gov/econ/bps/State/st%04da.txt",
    years
  )

  map2_dfr(urls, years, function(url, file_year) {
    message("Census BPS: pulling ", file_year)

    out <- read_csv(
      url,
      skip = 2,
      col_names = bps_state_col_names,
      col_types = cols(.default = "c"),
      na = c("", "NA"),
      show_col_types = FALSE
    )
    assert_required_columns(out, bps_state_col_names, "Census BPS flat file")
    observed_years <- unique(as.integer(substr(out$time, 1L, 4L)))
    observed_years <- observed_years[!is.na(observed_years)]
    if (!identical(observed_years, as.integer(file_year))) {
      stop(
        "Census BPS file for ", file_year,
        " contains unexpected year values: ",
        paste(observed_years, collapse = ", ")
      )
    }
    out |>
      mutate(source_year = file_year)
  }) |>
    filter(.data$state_fips %in% state_fips_lookup$state_fips) |>
    mutate(
      year = as.integer(substr(.data$time, 1, 4)),
      across(
        c(
          bldgs_1unit:value_5punit,
          bldgs_1unit_rep:value_5punit_rep
        ),
        readr::parse_number
      )
    ) |>
    select(-source_year) |>
    arrange(state_name, year)
}

if (should_import("census_bps")) {
  building_permits <- get_census_building_permits()
  validate_state_year_panel(building_permits, analysis_years, "Census BPS")
  write_raw_csv(building_permits, "census", "census_building_permits.csv")
}

# =============================================================================

# 3. FHWA - State Highway Capital Outlays (Table SF-4C)
# =============================================================================
# Highway Statistics Table SF-4C is published as one Excel workbook per year:
#   https://www.fhwa.dot.gov/policyinformation/statistics/YYYY/xls/sf4c.xlsx
#
# The latest published Highway Statistics series is 2024, but the default pull
# below uses analysis_years to align with USGS through 2023.

fhwa_col_names <- c(
  "state",
  "capital_right_of_way",
  "capital_engineering",
  "capital_construction_preservation",
  "capital_outlay_total",
  "physical_maintenance",
  "traffic_control_operations",
  "snow_ice_removal",
  "other_services",
  "toll_collection_expenses",
  "highway_traffic_services_total",
  "general_administration",
  "research_planning",
  "administration_research_total",
  "traffic_supervision",
  "highway_safety_driver_education",
  "vehicle_inspection",
  "size_weight_enforcement",
  "law_enforcement_safety_total"
)

download_fhwa_workbook <- function(url, destfile) {
  utils::download.file(
    url,
    destfile = destfile,
    mode = "wb",
    method = "libcurl",
    quiet = TRUE
  )

  connection <- file(destfile, open = "rb")
  on.exit(close(connection), add = TRUE)
  signature <- readBin(connection, what = "raw", n = 2L)
  if (!identical(signature, as.raw(c(0x50, 0x4b)))) {
    stop("FHWA response is not a valid XLSX/ZIP file: ", url)
  }

  invisible(destfile)
}

normalize_fhwa_state <- function(x) {
  x |>
    trimws() |>
    sub(
      pattern = "\\s+(?:\\(?[0-9]+\\)?|[0-9]+/)$",
      replacement = "",
      perl = TRUE
    ) |>
    trimws()
}

get_fhwa_state_capital_outlays <- function(years = analysis_years) {
  map_dfr(years, function(year) {
    url <- sprintf(
      "https://www.fhwa.dot.gov/policyinformation/statistics/%d/xls/sf4c.xlsx",
      year
    )

    message("FHWA SF-4C: pulling ", year)

    tmp <- tempfile(fileext = ".xlsx")
    raw <- tryCatch(
      {
        download_fhwa_workbook(url, tmp)
        read_excel(
          tmp,
          sheet = 1,
          range = "A15:S65",
          col_names = fhwa_col_names
        )
      },
      finally = unlink(tmp)
    )
    assert_required_columns(raw, fhwa_col_names, "FHWA SF-4C workbook")
    if (nrow(raw) != 51L) {
      stop("FHWA SF-4C workbook has an unexpected row count for ", year, ".")
    }

    raw |>
      filter(!is.na(state), trimws(state) != "Total") |>
      mutate(
        state = normalize_fhwa_state(state),
        year = year,
        across(
          -c(state, year),
          ~ suppressWarnings(
            readr::parse_number(
              as.character(.x),
              na = c("", "NA", "-", "--")
            )
          )
        )
      ) |>
      left_join(state_fips_lookup, by = "state") |>
      relocate(year, state_fips, state)
  }) |>
    arrange(state, year)
}

if (should_import("fhwa")) {
  fhwa_outlays <- get_fhwa_state_capital_outlays()
  validate_state_year_panel(fhwa_outlays, analysis_years, "FHWA SF-4C")
  write_raw_csv(fhwa_outlays, "fhwa", "fhwa_state_capital_outlays.csv")
}

# =============================================================================

# 4. BLS - State Construction Employment
# =============================================================================
# Constructs State and Metro Area CES (SAE) statewide series IDs. A national
# CES series is not suitable because it cannot explain state-level differences.
# Default industry = Heavy and Civil Engineering Construction (NAICS 237).
# The function calculates annual averages from monthly, not-seasonally-adjusted
# observations. Some states may not publish the detailed heavy/civil series;
# the function warns if coverage is incomplete.
#
# industry options:
#   "heavy_civil"  -> Heavy and Civil Engineering Construction
#   "construction" -> Total Construction (broader fallback)

get_bls_state_construction <- function(
  start_year = analysis_start_year,
  end_year = analysis_end_year,
  industry = c("heavy_civil", "construction"),
  key = bls_key
) {
  require_api_key(key, "bls_key")
  industry <- match.arg(industry)

  series_tail <- switch(industry,
    heavy_civil = "000002023700001",
    construction = "000002000000001"
  )

  series_lookup <- state_fips_lookup |>
    mutate(series_id = paste0("SMU", state_fips, series_tail))

  base_uri <- "https://api.bls.gov/publicAPI/v2/timeseries/data/"

  response <- RETRY(
    verb = "POST",
    url = base_uri,
    body = list(
      seriesid = as.list(series_lookup$series_id),
      startyear = as.character(start_year),
      endyear = as.character(end_year),
      registrationkey = key
    ),
    encode = "json",
    user_agent("MDATA600-Crushed-Stone/1.0"),
    # The BLS gateway occasionally emits a malformed `route-id` header over
    # HTTP/2. Force HTTP/1.1 so libcurl does not reject the response framing.
    config(http_version = 2L),
    timeout(60),
    times = 5,
    pause_base = 1,
    pause_cap = 8,
    terminate_on = c(400, 401, 403)
  )

  stop_for_status(response)

  parsed <- content(
    response,
    as = "parsed",
    type = "application/json",
    encoding = "UTF-8"
  )

  if (!identical(parsed$status, "REQUEST_SUCCEEDED")) {
    stop(
      "BLS API request failed: ",
      paste(parsed$message, collapse = "; ")
    )
  }

  monthly <- map_dfr(parsed$Results$series, function(series) {
    if (length(series$data) == 0) {
      return(tibble())
    }

    bind_rows(series$data) |>
      mutate(series_id = series$seriesID, .before = 1)
  }) |>
    filter(period %in% sprintf("M%02d", 1:12)) |>
    transmute(
      series_id,
      year = as.integer(year),
      month = as.integer(sub("M", "", period)),
      employment_thousands = readr::parse_number(value)
    )

  annual <- monthly |>
    group_by(series_id, year) |>
    summarise(
      construction_employment_thousands = mean_or_na(employment_thousands),
      months_reported = sum(!is.na(employment_thousands)),
      .groups = "drop"
    ) |>
    left_join(series_lookup, by = "series_id") |>
    select(
      year,
      state_fips,
      state,
      construction_employment_thousands,
      months_reported,
      series_id
    ) |>
    arrange(state, year)

  incomplete_years <- annual |>
    filter(.data$months_reported != 12L)
  if (nrow(incomplete_years) > 0L) {
    warning(
      "BLS returned fewer than 12 monthly observations for ",
      nrow(incomplete_years), " state-year rows.",
      call. = FALSE
    )
  }

  annual
}

if (should_import("bls")) {
  bls_construction_emp <- get_bls_state_construction(
    industry = "heavy_civil"
  )
  validate_state_year_panel(
    bls_construction_emp,
    analysis_years,
    "BLS state construction employment",
    require_complete = FALSE
  )
  write_raw_csv(
    bls_construction_emp,
    "bls",
    "bls_state_construction_employment.csv"
  )
}

# =============================================================================

# 5. BEA - State Real GDP and Personal Income
# =============================================================================
# This project needs regional/state GDP rather than the national NIPA table.
# The BEA Regional API uses:
#   SAGDP9,  LineCode 1 -> Real GDP by state
#   SAINC1,  LineCode 1 -> Personal income by state

get_bea_regional <- function(
  table_name,
  line_code,
  years = analysis_years,
  geo_fips = "STATE",
  key = bea_key
) {
  require_api_key(key, "bea_key")

  base_uri <- "https://apps.bea.gov/api/data/"

  response <- GET(
    base_uri,
    query = list(
      UserID = key,
      method = "GetData",
      DataSetName = "Regional",
      TableName = table_name,
      LineCode = line_code,
      GeoFips = geo_fips,
      Year = paste(years, collapse = ","),
      ResultFormat = "JSON"
    ),
    timeout(60)
  )

  stop_for_status(response)

  parsed <- fromJSON(content(response, "text", encoding = "UTF-8"))

  if (!is.null(parsed$BEAAPI$Error)) {
    stop("BEA API error: ", paste(parsed$BEAAPI$Error, collapse = " "))
  }

  if (is.null(parsed$BEAAPI$Results$Data)) {
    stop("BEA API returned no data for ", table_name, ".")
  }

  as_tibble(parsed$BEAAPI$Results$Data) |>
    transmute(
      state_fips = substr(gsub("[^0-9]", "", GeoFips), 1, 2),
      state = trimws(gsub("\\*", "", GeoName)),
      year = as.integer(TimePeriod),
      value = readr::parse_number(DataValue)
    ) |>
    filter(state_fips %in% state_fips_lookup$state_fips) |>
    arrange(state, year)
}

if (should_import("bea")) {
  real_gdp <- get_bea_regional(
    table_name = "SAGDP9",
    line_code = 1
  ) |>
    rename(real_gdp = value)

  state_income <- get_bea_regional(
    table_name = "SAINC1",
    line_code = 1
  ) |>
    rename(personal_income = value)

  bea_state_gdp_personal_income <- full_join(
    real_gdp,
    state_income,
    by = c("state_fips", "state", "year")
  ) |>
    arrange(state, year)

  validate_state_year_panel(
    bea_state_gdp_personal_income,
    analysis_years,
    "BEA state GDP and personal income"
  )
  write_raw_csv(
    bea_state_gdp_personal_income,
    "bea",
    "bea_state_gdp_personal_income.csv"
  )
}

# =============================================================================

# 6. FRED - Mortgage Rates and Inflation
# =============================================================================
# FRED observations are national macro indicators. They can still be joined to
# the state-year panel because they vary by year, even though they do not vary
# by state.
#
# Series:
#   MORTGAGE30US -> 30-year fixed mortgage rate
#   CPIAUCSL     -> Consumer Price Index (used below to derive annual inflation)

get_fred_series <- function(
  series_id,
  start_date,
  end_date,
  key = fred_key
) {
  require_api_key(key, "fred_key")

  base_uri <- "https://api.stlouisfed.org/fred/series/observations"

  response <- GET(
    base_uri,
    query = list(
      series_id = series_id,
      api_key = key,
      file_type = "json",
      observation_start = start_date,
      observation_end = end_date
    ),
    timeout(60)
  )

  stop_for_status(response)

  parsed <- fromJSON(content(response, "text", encoding = "UTF-8"))

  if (!is.null(parsed$error_code)) {
    stop("FRED API error: ", parsed$error_message)
  }

  as_tibble(parsed$observations) |>
    transmute(
      series_id = series_id,
      date = as.Date(date),
      value = if_else(value == ".", NA_real_, readr::parse_number(value))
    )
}

annualize_fred <- function(data) {
  data |>
    mutate(year = as.integer(format(date, "%Y"))) |>
    group_by(series_id, year) |>
    summarise(
      observations = sum(!is.na(value)),
      value = mean_or_na(value),
      .groups = "drop"
    )
}

if (should_import("fred")) {
  mortgage_rates <- get_fred_series(
    series_id = "MORTGAGE30US",
    start_date = sprintf("%d-01-01", analysis_start_year),
    end_date = sprintf("%d-12-31", analysis_end_year)
  )

  mortgage_rates_annual <- annualize_fred(mortgage_rates) |>
    transmute(
      year,
      mortgage_rate_pct = value,
      observations
    )

  # Pull one prior year so initial-year inflation can be calculated when clean.
  cpi <- get_fred_series(
    series_id = "CPIAUCSL",
    start_date = sprintf("%d-01-01", analysis_start_year - 1L),
    end_date = sprintf("%d-12-31", analysis_end_year)
  )

  cpi_annual <- annualize_fred(cpi) |>
    arrange(year) |>
    transmute(
      year,
      cpi_index = value,
      observations
    )

  fred_mortgage_rates_inflation <- full_join(
    mortgage_rates_annual |>
      rename(mortgage_rate_observations = observations),
    cpi_annual |>
      rename(cpi_observations = observations),
    by = "year"
  ) |>
    arrange(year)

  write_raw_csv(
    fred_mortgage_rates_inflation,
    "fred",
    "fred_mortgage_rates_inflation.csv"
  )
}

# =============================================================================
# 7. BEA - State Construction-Sector Real GDP
# =============================================================================
# Official source and API documentation:
#   https://apps.bea.gov/api/data/
#   https://apps.bea.gov/api/_pdf/bea_web_service_api_user_guide.pdf
#
# SAGDP9 reports real GDP by state and industry. The construction LineCode is
# discovered from BEA metadata rather than hard-coded. The current table reports
# millions of chained 2017 dollars; UNIT_MULT == 6 confirms a 10^6 multiplier.

get_bea_construction_line_code <- function(key = bea_key) {
  require_api_key(key, "bea_key")

  response <- httr::GET(
    "https://apps.bea.gov/api/data/",
    query = list(
      UserID = key,
      method = "GetParameterValuesFiltered",
      DataSetName = "Regional",
      TargetParameter = "LineCode",
      TableName = "SAGDP9",
      ResultFormat = "JSON"
    ),
    httr::timeout(60)
  )
  httr::stop_for_status(response)

  parsed <- jsonlite::fromJSON(
    httr::content(response, "text", encoding = "UTF-8"),
    simplifyDataFrame = TRUE
  )
  values <- parsed$BEAAPI$Results$ParamValue

  if (is.null(values) || !all(c("Key", "Desc") %in% names(values))) {
    stop("BEA did not return the expected LineCode metadata schema.")
  }

  exact <- values |>
    dplyr::filter(tolower(trimws(.data$Desc)) == "construction")
  matches <- if (nrow(exact) == 1) {
    exact
  } else {
    values |>
      dplyr::filter(grepl("construction", .data$Desc, ignore.case = TRUE))
  }

  if (nrow(matches) != 1) {
    stop(
      "Expected exactly one BEA construction LineCode; found ", nrow(matches),
      ". Matching descriptions: ", paste(matches$Desc, collapse = "; ")
    )
  }

  message("BEA construction LineCode: ", matches$Key, " (", matches$Desc, ")")
  as.integer(matches$Key)
}

get_bea_construction_gdp <- function(
  years = analysis_years,
  key = bea_key
) {
  line_code <- get_bea_construction_line_code(key)

  response <- httr::GET(
    "https://apps.bea.gov/api/data/",
    query = list(
      UserID = key,
      method = "GetData",
      DataSetName = "Regional",
      TableName = "SAGDP9",
      LineCode = line_code,
      GeoFips = "STATE",
      Year = paste(years, collapse = ","),
      ResultFormat = "JSON"
    ),
    httr::timeout(60)
  )
  httr::stop_for_status(response)

  parsed <- jsonlite::fromJSON(
    httr::content(response, "text", encoding = "UTF-8")
  )
  if (!is.null(parsed$BEAAPI$Error)) {
    stop("BEA API error: ", paste(parsed$BEAAPI$Error, collapse = " "))
  }

  data <- parsed$BEAAPI$Results$Data
  if (is.null(data)) stop("BEA returned no construction GDP data.")

  tibble::as_tibble(data) |>
    dplyr::transmute(
      state_fips = substr(gsub("[^0-9]", "", .data$GeoFips), 1, 2),
      state = trimws(gsub("\\*", "", .data$GeoName)),
      year = as.integer(.data$TimePeriod),
      construction_real_gdp = readr::parse_number(.data$DataValue),
      construction_real_gdp_unit = "millions_of_chained_2017_dollars",
      unit_multiplier = as.integer(.data$UNIT_MULT)
    ) |>
    dplyr::filter(
      .data$state %in% state.name,
      .data$unit_multiplier == 6L
    ) |>
    dplyr::arrange(.data$state, .data$year)
}

if (should_import("bea_construction")) {
  bea_construction_gdp <- get_bea_construction_gdp()
  validate_state_year_panel(
    bea_construction_gdp,
    analysis_years,
    "BEA construction GDP"
  )

  write_raw_csv(
    bea_construction_gdp,
    "bea",
    "bea_construction_gdp.csv"
  )
}

# =============================================================================
# 8. Census - Annual Value of Construction Put in Place by State
# =============================================================================
# Official source:
#   https://www.census.gov/construction/c30/historical_data.html
#
# The geographic workbooks report millions of current (nominal) dollars.
# Private nonresidential and state/local construction are kept separate. These
# variables measure demand-side construction activity, but must be deflated in
# the cleaning step before being interpreted as real activity.

census_construction_urls <- tibble::tribble(
  ~series, ~source_priority, ~url,
  "private_nonresidential_spending_nominal_millions",
  1L,
  "https://www.census.gov/construction/c30/xlsx/nrstatehs1.xlsx",
  "private_nonresidential_spending_nominal_millions",
  2L,
  "https://www.census.gov/construction/c30/xlsx/nrstate.xlsx",
  "state_local_construction_spending_nominal_millions",
  1L,
  "https://www.census.gov/construction/c30/xlsx/slstatehs.xlsx",
  "state_local_construction_spending_nominal_millions",
  2L,
  "https://www.census.gov/construction/c30/xlsx/slstate.xlsx"
)

read_census_state_construction <- function(
  url,
  series,
  source_priority,
  years = analysis_years
) {
  message("Census construction spending: downloading ", basename(url))

  workbook <- tempfile(fileext = ".xlsx")
  on.exit(unlink(workbook), add = TRUE)
  utils::download.file(
    url,
    destfile = workbook,
    mode = "wb",
    method = "libcurl",
    quiet = TRUE
  )

  raw <- readxl::read_excel(workbook, col_names = FALSE)
  if (nrow(raw) < 6 || ncol(raw) < 3) {
    stop("Unexpected Census workbook dimensions for ", url)
  }

  header <- as.character(unlist(raw[4, ], use.names = FALSE))
  header_years <- rep(NA_integer_, length(header))
  year_headers <- grepl("^[0-9]{4}$", header)
  header_years[year_headers] <- as.integer(header[year_headers])
  year_columns <- which(!is.na(header_years) & header_years %in% years)

  if (length(year_columns) == 0) {
    stop("No requested analysis years found in ", url)
  }

  # State names occupy the second workbook column; region and national rows do
  # not match state.name and are removed below.
  out <- tibble::tibble(state = trimws(as.character(raw[[2]])))
  for (column in year_columns) {
    out[[as.character(header_years[[column]])]] <-
      readr::parse_number(as.character(raw[[column]]))
  }

  out |>
    dplyr::filter(.data$state %in% state.name) |>
    tidyr::pivot_longer(
      cols = -state,
      names_to = "year",
      values_to = "value"
    ) |>
    dplyr::mutate(
      year = as.integer(.data$year),
      series = series,
      source_priority = source_priority,
      source_file = basename(url)
    )
}

if (should_import("census_construction")) {
  census_construction_long <- purrr::pmap_dfr(
    census_construction_urls,
    function(series, source_priority, url) {
      read_census_state_construction(
        url,
        series,
        source_priority,
        analysis_years
      )
    }
  )

  overlapping_census_rows <- census_construction_long |>
    dplyr::count(.data$state, .data$year, .data$series) |>
    dplyr::filter(.data$n > 1L)
  if (nrow(overlapping_census_rows) > 0L) {
    message(
      "Census construction: resolving ", nrow(overlapping_census_rows),
      " overlapping state-year-series rows in favor of current workbooks."
    )
  }

  census_construction_spending <- census_construction_long |>
    dplyr::arrange(
      .data$state,
      .data$year,
      .data$series,
      is.na(.data$value),
      dplyr::desc(.data$source_priority)
    ) |>
    dplyr::distinct(.data$state, .data$year, .data$series, .keep_all = TRUE) |>
    dplyr::select(-source_priority, -source_file) |>
    tidyr::pivot_wider(names_from = "series", values_from = "value") |>
    dplyr::left_join(state_fips_lookup, by = "state") |>
    dplyr::select(state_fips, state, year, dplyr::everything()) |>
    dplyr::arrange(state, year)

  validate_state_year_panel(
    census_construction_spending,
    analysis_years,
    "Census construction spending"
  )

  write_raw_csv(
    census_construction_spending,
    "census",
    "census_construction_spending.csv"
  )
}

# =============================================================================
# 9. EIA SEDS - State Industrial Energy Prices
# =============================================================================
# Official bulk price file and codebook:
#   https://www.eia.gov/state/seds/sep_prices/total/csv/pr_all.csv
#   https://www.eia.gov/state/seds/CDF/Codes_and_Descriptions.xlsx
#
# Validated SEDS series (all dollars per million Btu):
#   DFICD - Distillate fuel oil price, industrial sector
#   ESICD - Electricity price, industrial sector
#   NGICD - Natural gas price, industrial sector
#   TEICD - Total energy average price, industrial sector
# These are production/transportation cost controls, not direct demand measures.

eia_seds_price_url <-
  "https://www.eia.gov/state/seds/sep_prices/total/csv/pr_all.csv"

eia_price_series <- c(
  DFICD = "industrial_distillate_price_per_mmbtu",
  ESICD = "industrial_electricity_price_per_mmbtu",
  NGICD = "industrial_natural_gas_price_per_mmbtu",
  TEICD = "industrial_energy_price_per_mmbtu"
)

get_eia_industrial_prices <- function(
  url = eia_seds_price_url,
  years = analysis_years
) {
  message("EIA SEDS: downloading industrial energy prices")
  raw <- readr::read_csv(
    url,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  required <- c("State", "MSN", as.character(years))
  missing_columns <- setdiff(required, names(raw))
  if (length(missing_columns) > 0) {
    stop("EIA price file is missing: ", paste(missing_columns, collapse = ", "))
  }

  state_crosswalk <- tibble::tibble(
    state = state.name,
    state_abbr = state.abb
  ) |>
    dplyr::left_join(state_fips_lookup, by = "state")

  out <- raw |>
    dplyr::filter(.data$MSN %in% names(eia_price_series)) |>
    dplyr::select(
      state_abbr = State,
      MSN,
      dplyr::all_of(as.character(years))
    ) |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(as.character(years)),
      names_to = "year",
      values_to = "value"
    ) |>
    dplyr::mutate(
      year = as.integer(.data$year),
      value = readr::parse_number(
        as.character(.data$value),
        na = c("", "NA", "N/A", "Not Available", "--")
      ),
      variable = unname(eia_price_series[.data$MSN])
    ) |>
    dplyr::select(-MSN) |>
    tidyr::pivot_wider(names_from = variable, values_from = value) |>
    dplyr::inner_join(state_crosswalk, by = "state_abbr") |>
    dplyr::select(state_fips, state, year, dplyr::everything(), -state_abbr) |>
    dplyr::arrange(state, year)

  out
}

if (should_import("eia")) {
  eia_energy_prices <- get_eia_industrial_prices()
  validate_state_year_panel(
    eia_energy_prices,
    analysis_years,
    "EIA energy prices"
  )

  write_raw_csv(eia_energy_prices, "eia", "eia_energy_prices.csv")
}

# =============================================================================
# 10. MSHA - Stone Quarry Employment and Capacity Controls
# =============================================================================
# Official datasets and definitions:
#   https://arlweb.msha.gov/OpenGovernmentData/DataSets/MinesProdYearly.zip
#   https://arlweb.msha.gov/OpenGovernmentData/DataSets/Mines.zip
#   https://arlweb.msha.gov/OpenGovernmentData/OGIMSHA.asp
#
# Defensible filters from the MSHA dictionaries:
#   PRIMARY_CANVASS_CD == "6" identifies M/NM (Stone).
#   SUBUNIT_CD == "03" identifies strip, quarry, or open-pit operations.
# A mine is active in a state-year when that quarry subunit reports positive
# annual hours or positive average annual employment. This historical activity
# definition is preferred to the Mines file's current-status field.
#
# Limitation: Mines.zip describes each mine's current primary commodity, not a
# historical commodity classification. The measures are supply-capacity controls
# and contemporaneous employment can respond to demand. Lagged versions are
# therefore created in R/02_clean.R.

msha_urls <- c(
  employment =
    "https://arlweb.msha.gov/OpenGovernmentData/DataSets/MinesProdYearly.zip",
  mines = "https://arlweb.msha.gov/OpenGovernmentData/DataSets/Mines.zip"
)

read_msha_zip_table <- function(url, expected_file) {
  archive <- tempfile(fileext = ".zip")
  extract_dir <- tempfile(pattern = "msha_")
  dir.create(extract_dir)
  on.exit(unlink(c(archive, extract_dir), recursive = TRUE), add = TRUE)

  message("MSHA: downloading ", basename(url))
  utils::download.file(
    url,
    destfile = archive,
    mode = "wb",
    method = "libcurl",
    quiet = TRUE
  )

  members <- utils::unzip(archive, list = TRUE)$Name
  if (!expected_file %in% members) {
    stop(
      "Expected ", expected_file, " in ", basename(url),
      "; found: ", paste(members, collapse = ", ")
    )
  }

  utils::unzip(archive, files = expected_file, exdir = extract_dir)
  readr::read_delim(
    file.path(extract_dir, expected_file),
    delim = "|",
    quote = "\"",
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE,
    trim_ws = TRUE
  )
}

get_msha_stone_capacity <- function(years = analysis_years) {
  employment <- read_msha_zip_table(
    msha_urls[["employment"]],
    "MinesProdYearly.txt"
  )
  mines <- read_msha_zip_table(msha_urls[["mines"]], "Mines.txt")

  employment_required <- c(
    "MINE_ID", "STATE_ABBR", "SUBUNIT_CD", "CALENDAR_YR",
    "ANNUAL_HRS", "AVG_ANNUAL_EMPL", "C_M_IND"
  )
  mines_required <- c("MINE_ID", "PRIMARY_CANVASS_CD")

  if (length(setdiff(employment_required, names(employment))) > 0) {
    stop("MSHA employment schema has changed; inspect its definition file.")
  }
  if (length(setdiff(mines_required, names(mines))) > 0) {
    stop("MSHA Mines schema has changed; inspect its definition file.")
  }

  stone_mines <- mines |>
    dplyr::transmute(
      MINE_ID = as.character(.data$MINE_ID),
      primary_canvass_code = as.character(.data$PRIMARY_CANVASS_CD)
    ) |>
    dplyr::filter(.data$primary_canvass_code == "6") |>
    dplyr::distinct(.data$MINE_ID)

  state_crosswalk <- tibble::tibble(
    state = state.name,
    state_abbr = state.abb
  ) |>
    dplyr::left_join(state_fips_lookup, by = "state")

  mine_year <- employment |>
    dplyr::transmute(
      MINE_ID = as.character(.data$MINE_ID),
      state_abbr = .data$STATE_ABBR,
      subunit_code = as.character(.data$SUBUNIT_CD),
      year = as.integer(.data$CALENDAR_YR),
      annual_hours = as.numeric(.data$ANNUAL_HRS),
      average_annual_employees = as.numeric(.data$AVG_ANNUAL_EMPL),
      coal_metal_indicator = .data$C_M_IND
    ) |>
    dplyr::semi_join(stone_mines, by = "MINE_ID") |>
    dplyr::filter(
      .data$year %in% years,
      .data$subunit_code == "03",
      .data$coal_metal_indicator == "M",
      dplyr::coalesce(.data$annual_hours, 0) > 0 |
        dplyr::coalesce(.data$average_annual_employees, 0) > 0
    ) |>
    dplyr::group_by(MINE_ID, state_abbr, year) |>
    dplyr::summarise(
      annual_hours = sum(.data$annual_hours, na.rm = TRUE),
      average_annual_employees =
        sum(.data$average_annual_employees, na.rm = TRUE),
      .groups = "drop"
    )

  capacity <- mine_year |>
    dplyr::group_by(state_abbr, year) |>
    dplyr::summarise(
      active_stone_mines = dplyr::n_distinct(.data$MINE_ID),
      stone_mine_employees = sum(.data$average_annual_employees, na.rm = TRUE),
      stone_mine_employee_hours = sum(.data$annual_hours, na.rm = TRUE),
      stone_mine_operations = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::inner_join(state_crosswalk, by = "state_abbr") |>
    dplyr::select(state_fips, state, year, dplyr::everything(), -state_abbr)

  # Complete the 50-state panel. A missing aggregate after explicit filtering
  # means no qualifying active stone quarry record, so capacity counts are zero.
  tidyr::crossing(
    state_fips_lookup,
    year = as.integer(years)
  ) |>
    dplyr::left_join(capacity, by = c("state_fips", "state", "year")) |>
    dplyr::mutate(
      dplyr::across(
        c(
          active_stone_mines,
          stone_mine_employees,
          stone_mine_employee_hours,
          stone_mine_operations
        ),
        ~ tidyr::replace_na(.x, 0)
      )
    ) |>
    dplyr::arrange(.data$state, .data$year)
}

if (should_import("msha")) {
  msha_stone_capacity <- get_msha_stone_capacity()
  validate_state_year_panel(
    msha_stone_capacity,
    analysis_years,
    "MSHA stone capacity"
  )

  write_raw_csv(msha_stone_capacity, "msha", "msha_stone_capacity.csv")
}
