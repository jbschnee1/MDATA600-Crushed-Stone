# Data quality report - approved pipeline

PASS: 450 unique state-years, exact 50-state/2015-2023 coverage, nonnegative observed target and positive primary inputs.
PASS: joins preserve row counts; keys unique; CPI has 12 months in every year 2014-2023.
PASS: 23 withheld outcomes stay missing; 8 misdated FHWA values masked; no interpolation.
PASS: explicit previous-year joins; each lag reconciled to exact state/year-1 input including missingness.
Eligible: 419 contemporaneous, 371 lagged; 94 in final 2022-2023 prediction years.
BLS: 324 complete annual observations; not a primary eligibility requirement.
18 annual changes above 50% flagged in annual_change_review.csv; no automatic deletion.
All source inputs checksum-pinned. FHWA 2015-2022 uses preserved parsed data; live originals fail certificate validation.
MSHA zero aggregates explicitly flagged; current commodity classification and USGS estimation dependence retained as limitations.
USGS target uses first-sale/use geography. Read source_register.md for revision and historical-release limitations.
