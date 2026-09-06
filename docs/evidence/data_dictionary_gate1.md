# Data dictionary — Gate 1 proposal, 2026-09-06

The saved panel has 80 columns and 450 state-year rows. **It is not yet a model-ready dataset.** [Machine-readable dictionary](variable_dictionary.csv) covers every saved column; [variable profile](evidence/variable_profile.csv) gives per-file types, missingness and numeric ranges. Existing field names/data are preserved. Names below marked proposed describe Phase 2 derivations that require Gate 1 approval.

## Keys, target and primary candidates

| Existing field(s) | Proposed analytical name | Definition / units | Missingness / handling |
|---|---|---|---|
| `state_fips`, `state`, `year` | same | two-character state FIPS; canonical state name; integer source/calendar year | Exact 50-state × 2015–2023 backbone. No DC/territories. Never parse FIPS as an unpadded number. |
| `crushed_stone_tons` | `crushed_stone_sold_used_metric_tons` | USGS state totals, crushed stone sold or used, metric tons; first-sale/use geography | 427 numeric, 23 withheld; keep original token and withholding flag. No zero replacement. Survey/agency estimates, not purely observed extraction. |
| `units_1unit`, `units_2unit`, `units_34unit`, `units_5punit` | `housing_units_authorized` | Sum of four Census unit categories, housing units/year | All 450 present; includes source imputation. Do not add `_rep` counts. |
| `capital_outlay_total` | `highway_capital_outlays_nominal_thousand_usd`; optionally `highway_capital_outlays_2017_million_usd` | SF-4C capital expenditure total; original thousands of dollars. Constant-price proposal = `total / 1000 * CPI_2017 / CPI_t` | All 450 numeric but eight older-year carry-forwards; mask those predictor cells in strict temporal analysis. CPI is a general purchasing-power adjustment. |
| `construction_real_gdp` | `construction_gdp_chained_2017_million_usd` | BEA SAGDP9 LineCode 11, construction value added, millions of chained 2017 dollars | 450 present; already real, do not deflate again. Verify CL_UNIT and multiplier on refresh. |
| Target at `t−1` (not stored) | `lag1_crushed_stone_sold_used_metric_tons` | Previous-year published quantity, explicit state/year self-join | Predictive baseline only; 2015 unavailable without added support year. With current observed targets, 379 eligible comparisons before FHWA masks. |
| Three primary predictors at `t−1` (not stored) | corresponding `lag1_` fields | Prior-year units, outlays and construction GDP | Build from eligible source values before joining target year. Masked FHWA propagates to next target year. Proposed strict sample 371. |
| Source state token, table year, reported year (not in panel) | `fhwa_state_token`, `fhwa_table_year`, `fhwa_reported_year`, `fhwa_year_matches` | Audit metadata for timing | Eight known mismatches in ledger; preserve source notes even when normalizing names. No automatic year reassignment. |

## Secondary candidates and descriptive fields

| Existing field(s) | Unit / construction | Role and caution |
|---|---|---|
| `construction_employment_thousands`, `months_reported`, `series_id` | BLS NAICS 237 annual mean of monthly NSA employment, thousands; valid month count; source ID | Secondary. 324 employment rows across 36 states; 310 overlap target. Require 12 months; no silent broader-industry fill. |
| `real_gdp`, `personal_income` | BEA total real GDP: millions chained 2017 USD; income: millions current USD | Alternative scale controls; GDP overlaps sector size, income needs price labeling. |
| `construction_real_gdp_unit`, `unit_multiplier` | text metadata; 6 means ×10^6 | Metadata, never predictors; hard-coded unit text in current code needs live validation. |
| `construction_real_gdp_growth_pct` | `100 * (GDP_t / GDP_(t−1) − 1)` | Derived secondary; 50 first-year missing. Must check adjacent years, not just row order. |
| `private_nonresidential_spending_nominal_millions` | Census annual millions current USD, excluding power/communication/railroad | Secondary substitute; source estimates and nonresidential scope limitation. |
| `state_local_construction_spending_nominal_millions` | Census annual millions current USD | Secondary substitute; overlaps highway activity. |
| `industrial_distillate_price_per_mmbtu`, `industrial_electricity_price_per_mmbtu`, `industrial_natural_gas_price_per_mmbtu`, `industrial_energy_price_per_mmbtu` | EIA annual industrial prices, nominal USD per million Btu | Secondary, one total/component at a time. Sector cost proxies, not quarry-specific prices. |
| `active_stone_mines` | Count of qualifying mine IDs after stone/open-pit activity filters | Secondary activity proxy; not measured rated capacity. Zero-completed aggregates must have a provenance flag. |
| `stone_mine_employees`, `stone_mine_employee_hours` | Aggregated average annual employees; annual employee hours | Secondary; target estimation uses MSHA hours. Current commodity assignment and omitted contractors/subunits limit interpretation. |
| `stone_mine_operations` | Number of mine/state/year aggregates | Redundant with active mines in existing definition; exclude predictor duplicate. |
| `lag_active_stone_mines`, `lag_stone_mine_employee_hours` | Previous-year values by state | 50 first-year missing each; stored lags match preceding calendar year in complete backbone. Lagging does not remove USGS measurement dependence. |
| `mortgage_rate_pct` | Annual mean weekly MORTGAGE30US, percent | National only; annual year effects absorb it. November 2022 method change. |
| `cpi_index` | Annual mean monthly CPIAUCSL, 1982–84=100, seasonally adjusted source | National; normalization input, not an independent state measure. |
| `inflation_pct` | Annual-mean CPI growth, percent | Stored panel missing all 50 copies of 2015. 2014 source CPI is now verified in separate evidence. |
| `mortgage_rate_observations`, `cpi_observations` | Counts of weekly/monthly observations per year | Quality metadata, not predictors. |
| `crushed_stone_total_value`, `crushed_stone_unit_value` | USGS nominal USD; USD/metric ton | Descriptive only. Same-year value/price and quantity are related arithmetically; exclude target-linked predictors. |

## Other saved columns

- Census `bldgs_*` are counts of buildings, `units_*` housing units, `value_*` thousands of nominal dollars. Suffixes `1unit`, `2unit`, `34unit`, `5punit` denote building-size categories; `_rep` restricts to reported components. No buildings/units double-counting. Raw header definitions and four components were inspected; permit values are not primary predictors.
- `census_bps_time`, `census_bps_state_name`, `region_code`, `division_code`, USGS `region`, `division` are source identifiers/geographic descriptors. Canonical state/year keys govern joins. Regional identifiers are absorbed by state fixed effects.
- Every FHWA monetary component from `capital_right_of_way` through `law_enforcement_safety_total` is thousands of nominal dollars. Store them for auditing; do not fit totals and their components simultaneously. Raw zeros/dashes need source-format interpretation, and older-year flags apply to the row.

## Transformations, missingness and information timing

Recommended missing-data policy: no target imputation; no automatic interpolation of predictors; disclose source-provided imputation and project-created zeros separately. Mask misdated FHWA values while retaining backbone rows. Use common eligible cases when comparing feature/model variants; report broader-coverage alternatives separately so coverage changes cannot masquerade as model gains.

Proposed logs require positive inputs; inspect the approved dataset before adopting them. Use training-only preprocessing and retransformation correction. Nominal outlays/spending and real GDP cannot share a generic `dollars` label. Percent growth is not a percentage-point level, and a mortgage percentage point is not one percent relative change.

State-year lags must join `(state, year−1)` and enforce an exact one-year difference; `lag()` on a sorted but gapped file alone is insufficient. No six-month inference is possible. Latest-vintage revised annual files do not demonstrate that each predictor was published by a historical forecast issue date.

The dictionary specifies candidate roles, not approved regressors. [Methodology decisions](methodology_decisions.md) and [Gate 1](decision_gate_1.md) govern any eventual implementation.
