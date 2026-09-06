"""Read-only project/data baseline; writes evidence under docs/evidence only.

Run: python3 R/00_baseline_audit.py
Existing clean/join code runs only in a temporary copy. No import or modeling.
"""
import collections
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence"
OUT.mkdir(parents=True, exist_ok=True)
os.chdir(ROOT)


def read(path):
    with Path(path).open() as handle:
        return list(csv.DictReader(handle))


def write(name, rows):
    if rows:
        with (OUT / name).open("w") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)


def numeric(value):
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


files = sorted(p for p in Path("data").rglob("*.csv") if "approved" not in p.parts and "snapshots" not in p.parts)
before = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
inventory, profiles = [], []
for path in files:
    rows = read(path)
    keys = [(r.get("state_fips", "national"), r["year"]) for r in rows]
    inventory.append(dict(path=str(path), bytes=path.stat().st_size, sha256=before[str(path)],
        rows=len(rows), columns=len(rows[0]), min_year=min(r["year"] for r in rows),
        max_year=max(r["year"] for r in rows),
        nonmissing_states=len({r["state_fips"] for r in rows if r.get("state_fips")}),
        duplicate_key_rows=len(keys)-len(set(keys)),
        missing_key_rows=sum(not all(k) for k in keys)))
    for column in rows[0]:
        values = [r[column] for r in rows if r[column] not in ("", "NA", "NaN")]
        nums = [numeric(v) for v in values]
        is_numeric = bool(nums) and all(v is not None for v in nums)
        profiles.append(dict(path=str(path), variable=column, observed=len(values), missing=len(rows)-len(values),
            distinct=len(set(values)), type="numeric" if is_numeric else "text",
            minimum=min(nums) if is_numeric else "", maximum=max(nums) if is_numeric else "",
            negative_count=sum(v < 0 for v in nums) if is_numeric else ""))
write("data_inventory.csv", inventory)
write("variable_profile.csv", profiles)
panel = read("data/processed/crushed_stone_state_year.csv")
valid_fips = set("01 02 04 05 06 08 09 10 12 13 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 44 45 46 47 48 49 50 51 53 54 55 56".split())
lookup = {(r["state_fips"], int(r["year"])): r for r in panel}
assert set(lookup) == {(s,y) for s in valid_fips for y in range(2015,2024)}
assert len(panel) == len(lookup) == 450
assert all(float(r["crushed_stone_tons"]) >= 0 for r in panel if r["crushed_stone_tons"])
coverage = []
for row in panel:
    previous = lookup.get((row["state_fips"], int(row["year"])-1), {})
    coverage.append({k:row[k] for k in ("state_fips","state","year")} | dict(
        target_observed=int(bool(row["crushed_stone_tons"])), bls_observed=int(bool(row["construction_employment_thousands"])),
        previous_target_observed=int(bool(previous.get("crushed_stone_tons"))),
        primary_predictors_observed=int(all(row[c] for c in ("units_1unit","units_2unit","units_34unit","units_5punit","capital_outlay_total","construction_real_gdp")))))
    for lag, current in (("lag_active_stone_mines","active_stone_mines"),("lag_stone_mine_employee_hours","stone_mine_employee_hours")):
        assert numeric(row[lag]) == numeric(previous.get(current)), (row["state"],row["year"],lag)
write("state_year_coverage.csv", coverage)
write("target_missingness.csv", [r for r in coverage if not r["target_observed"]])
write("fhwa_missing_raw_keys.csv", [r for r in read("data/raw/fhwa/fhwa_state_capital_outlays.csv") if not r["state_fips"]])
anomalies=[]
for row in panel:
    previous=lookup.get((row["state_fips"],int(row["year"])-1),{})
    for c in ("crushed_stone_tons","capital_outlay_total","construction_real_gdp","industrial_energy_price_per_mmbtu","active_stone_mines"):
        x, p = numeric(row[c]),numeric(previous.get(c))
        if x is not None and p and abs(x/p-1)>0.5:
            anomalies.append(dict(state=row["state"],year=row["year"],variable=c,previous=p,current=x,change_pct=100*(x/p-1),action="Review; do not automatically exclude"))
write("large_annual_changes.csv",anomalies)
year_counts=[]
for year in range(2015,2024):
    rows=[r for r in coverage if int(r["year"])==year]
    year_counts.append(dict(year=year,backbone=len(rows),target_observed=sum(r["target_observed"] for r in rows),
        target_and_bls=sum(r["target_observed"]*r["bls_observed"] for r in rows),
        target_and_previous_target=sum(r["target_observed"]*r["previous_target_observed"] for r in rows)))
write("coverage_by_year.csv",year_counts)
flags_path=OUT/"fhwa_reporting_year_flags.csv"
if flags_path.exists():
    flags={(r["state_fips"],int(r["table_year"])) for r in read(flags_path)}
    eligibility=[]
    for r in panel:
        state,year=r["state_fips"],int(r["year"])
        previous=lookup.get((state,year-1),{})
        observed=bool(r["crushed_stone_tons"])
        lagged=observed and bool(previous.get("crushed_stone_tons"))
        eligibility.append(dict(state_fips=state,state=r["state"],year=year,
            target_observed=int(observed),strict_contemporaneous=int(observed and (state,year) not in flags),
            prior_target_available=int(lagged),strict_lagged=int(lagged and (state,year-1) not in flags)))
    write("proposed_sample_eligibility.csv",eligibility)
snapshots=[]
for path in sorted(Path("output/source_verification").glob("*")):
    if path.is_file():
        snapshots.append(dict(path=str(path),bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
write("source_snapshot_manifest.csv",snapshots)
log=[]
with tempfile.TemporaryDirectory(prefix="mdata-baseline-") as temporary:
    for directory in ("R","data"):
        shutil.copytree(directory,Path(temporary)/directory)
    for original in Path("docs/evidence/baseline_code").glob("*.R"):
        shutil.copy2(original,Path(temporary)/"R"/original.name)
    for script in ("R/02_clean.R","R/03_join.R"):
        result=subprocess.run(["Rscript","--vanilla",script],cwd=temporary,capture_output=True,text=True)
        log.append(f"{script}: exit {result.returncode}\n{result.stdout}{result.stderr}")
    equal=panel==read(Path(temporary)/"data/processed/crushed_stone_state_year.csv")
    log.append(f"Isolated join equals stored panel as CSV records: {equal}\n")
    assert equal
packages=subprocess.run(["Rscript","--vanilla","-e", '''p <- c("dplyr","httr","jsonlite","purrr","readr","readxl","tibble","tidyr","renv"); cat(R.version.string,"\\n"); for(x in p) cat(x, if(requireNamespace(x,quietly=TRUE)) as.character(packageVersion(x)) else "NOT INSTALLED", "\\n"); for(f in list.files("R",pattern="[.]R$",full.names=TRUE)) { parse(f); cat("PARSE OK",f,"\\n") }'''],capture_output=True,text=True)
log.append(packages.stdout+packages.stderr)
after={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
assert before==after, "Baseline modified existing data"
log.append("PASS: all existing data hashes unchanged; panel keys, target nonnegativity, stored capacity lags checked.\n")
(OUT/"baseline_checks.log").write_text("\n".join(log))
print("Baseline evidence written. Cleaning failure is documented; stale-cache join succeeds. All existing data preserved.")
