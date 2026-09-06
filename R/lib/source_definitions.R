# Source definitions extracted from the preserved acquisition script; no side effects.
state_fips_lookup <- tibble(state = state.name, state_fips = c("01", "02", "04", "05", "06", "08", "09", 
    "10", "12", "13", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28", 
    "29", "30", "31", "32", "33", "34", "35", "36", "37", "38", "39", "40", "41", "42", "44", "45", "46", 
    "47", "48", "49", "50", "51", "53", "54", "55", "56"))

bps_state_col_names <- c("time", "state_fips", "region_code", "division_code", "state_name", "bldgs_1unit", 
    "units_1unit", "value_1unit", "bldgs_2unit", "units_2unit", "value_2unit", "bldgs_34unit", "units_34unit", 
    "value_34unit", "bldgs_5punit", "units_5punit", "value_5punit", "bldgs_1unit_rep", "units_1unit_rep", 
    "value_1unit_rep", "bldgs_2unit_rep", "units_2unit_rep", "value_2unit_rep", "bldgs_34unit_rep", "units_34unit_rep", 
    "value_34unit_rep", "bldgs_5punit_rep", "units_5punit_rep", "value_5punit_rep")

fhwa_col_names <- c("state", "capital_right_of_way", "capital_engineering", "capital_construction_preservation", 
    "capital_outlay_total", "physical_maintenance", "traffic_control_operations", "snow_ice_removal", 
    "other_services", "toll_collection_expenses", "highway_traffic_services_total", "general_administration", 
    "research_planning", "administration_research_total", "traffic_supervision", "highway_safety_driver_education", 
    "vehicle_inspection", "size_weight_enforcement", "law_enforcement_safety_total")

normalize_fhwa_state <- function(x) {
    trimws(sub(trimws(x), pattern = "\\s+(?:\\(?[0-9]+\\)?|[0-9]+/)$", replacement = "", perl = TRUE))
}

eia_price_series <- c(DFICD = "industrial_distillate_price_per_mmbtu", ESICD = "industrial_electricity_price_per_mmbtu", 
    NGICD = "industrial_natural_gas_price_per_mmbtu", TEICD = "industrial_energy_price_per_mmbtu")

get_msha_stone_capacity <- function(years = analysis_years) {
    employment <- read_msha_zip_table(msha_urls[["employment"]], "MinesProdYearly.txt")
    mines <- read_msha_zip_table(msha_urls[["mines"]], "Mines.txt")
    employment_required <- c("MINE_ID", "STATE_ABBR", "SUBUNIT_CD", "CALENDAR_YR", "ANNUAL_HRS", "AVG_ANNUAL_EMPL", 
        "C_M_IND")
    mines_required <- c("MINE_ID", "PRIMARY_CANVASS_CD")
    if (length(setdiff(employment_required, names(employment))) > 0) {
        stop("MSHA employment schema has changed; inspect its definition file.")
    }
    if (length(setdiff(mines_required, names(mines))) > 0) {
        stop("MSHA Mines schema has changed; inspect its definition file.")
    }
    stone_mines <- dplyr::distinct(dplyr::filter(dplyr::transmute(mines, MINE_ID = as.character(.data$MINE_ID), 
        primary_canvass_code = as.character(.data$PRIMARY_CANVASS_CD)), .data$primary_canvass_code == 
        "6"), .data$MINE_ID)
    state_crosswalk <- dplyr::left_join(tibble::tibble(state = state.name, state_abbr = state.abb), state_fips_lookup, 
        by = "state")
    mine_year <- dplyr::summarise(dplyr::group_by(dplyr::filter(dplyr::semi_join(dplyr::transmute(employment, 
        MINE_ID = as.character(.data$MINE_ID), state_abbr = .data$STATE_ABBR, subunit_code = as.character(.data$SUBUNIT_CD), 
        year = as.integer(.data$CALENDAR_YR), annual_hours = as.numeric(.data$ANNUAL_HRS), average_annual_employees = as.numeric(.data$AVG_ANNUAL_EMPL), 
        coal_metal_indicator = .data$C_M_IND), stone_mines, by = "MINE_ID"), .data$year %in% years, .data$subunit_code == 
        "03", .data$coal_metal_indicator == "M", dplyr::coalesce(.data$annual_hours, 0) > 0 | dplyr::coalesce(.data$average_annual_employees, 
        0) > 0), MINE_ID, state_abbr, year), annual_hours = sum(.data$annual_hours, na.rm = TRUE), average_annual_employees = sum(.data$average_annual_employees, 
        na.rm = TRUE), .groups = "drop")
    capacity <- dplyr::select(dplyr::inner_join(dplyr::summarise(dplyr::group_by(mine_year, state_abbr, 
        year), active_stone_mines = dplyr::n_distinct(.data$MINE_ID), stone_mine_employees = sum(.data$average_annual_employees, 
        na.rm = TRUE), stone_mine_employee_hours = sum(.data$annual_hours, na.rm = TRUE), stone_mine_operations = dplyr::n(), 
        .groups = "drop"), state_crosswalk, by = "state_abbr"), state_fips, state, year, dplyr::everything(), 
        -state_abbr)
    dplyr::arrange(dplyr::mutate(dplyr::left_join(tidyr::crossing(state_fips_lookup, year = as.integer(years)), 
        capacity, by = c("state_fips", "state", "year")), dplyr::across(c(active_stone_mines, stone_mine_employees, 
        stone_mine_employee_hours, stone_mine_operations), ~tidyr::replace_na(.x, 0))), .data$state, 
        .data$year)
}

