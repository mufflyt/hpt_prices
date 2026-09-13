# hpt_prices

Hospital price transparency prices for colonoscopy, endometrial biopsy, IUD insertion,
and vaginal hysterectomy, for as many US hospitals as possible, keyed by CMS
Certification Number (CCN).

Every hospital must publish a machine-readable file (MRF) of its standard charges, list
it in a `cms-hpt.txt` file at the root of the website that hosts it, and link to it from
a "Price Transparency" footer link (45 CFR 180.50(d)(6)). This project collects those
files, keeps every payer and plan rate for the target codes, and links each file to the
hospitals it covers.

## Target codes

`config/codebook.csv` is the single source of truth. Every code except MS-DRGs was
checked against the CMS 2026 physician fee schedule RVU file (RVU26C) with
`validate_codebook_against_pfs()`.

| Concept | Codes |
|---|---|
| colonoscopy | 45378, 45380, 45381, 45382, 45384, 45385, 45386, 45388, 45389, 45390, G0105, G0121 |
| emb | 58100 |
| iud_insertion | 58300 |
| iud_device | J7296-J7301 (kept separate so total IUD cost can be built) |
| vaginal_hysterectomy | 58260-58294 (58293 was deleted and is flagged `active_2026 = FALSE`) |
| lavh | 58550, 58552, 58553, 58554 |
| drg_uterine_nonmalignant | MS-DRG 742, 743 (all non-malignant uterine/adnexal inpatient surgery, not only vaginal hysterectomy) |

A code counts only when its value and its declared code type both match. Hospitals
reuse the same digits in other code systems (a chargemaster item "58100", APR-DRG 742),
and those never match. A missing type is kept and flagged `type_verified = FALSE`.

## Sources

1. **Trilliant Health Hospital MRF Data Directory** (primary). Trilliant fetches
   `cms-hpt.txt` files, downloads the MRFs, and parses them into a DuckLake (7,916
   facility entries as of the 2026-07-21 snapshot). Download it from Oria (free
   account, "Full Data Download"). Their terms of service require attribution (2.2(b))
   and forbid automated scraping of the site (2.3(xii)) and redistribution of derived
   rate data (2.3(i), 2.3(iii)). So this repo reads only the consolidated download,
   never commits extracted rates, and should not be used to publish a rate database.
   Check with Trilliant before publishing a paper built on it.
2. **cms-hpt-tracker** (github.com/anthonyisnotadev/cms-hpt-tracker, AGPL-3.0). Its
   published CSVs map about 3,970 CCNs to their `cms-hpt.txt` and MRF URLs. Used as data
   only (no code copied) to link Trilliant files to CCNs by MRF URL, and to seed the gap
   crawl.
3. **CMS**: Hospital General Information (all hospitals and their CCNs), Hospital
   Enrollments (NPI to CCN), and the PFS RVU file (code validation).
4. **AHRQ Compendium of US Health Systems** (2023 hospital linkage) for health-system
   membership.
5. **Our own crawl** of `cms-hpt.txt` files and MRFs for hospitals Trilliant is missing.
   Seeds: tracker, TPAFS (2022), DoltHub (2022-2023), HIFLD 2020 hospital websites.

## Pipeline

Run from the repository root. Data goes to `HPT_DATA_DIR` (default: the external drive,
`/Volumes/MufflySamsung 1/hpt_prices`; the code checks it is a real mount point).

```sh
Rscript analysis/01_trilliant_extract.R   # Part A: prices from the Trilliant lake
Rscript analysis/02_ccn_crosswalk.R       # Part B: CMS universe, NPI and tracker bridge, CCN match
Rscript analysis/03_tracker_gap_mrfs.R    # Part C1: tracker-known MRFs missing from Trilliant
Rscript analysis/04_seed_domains.R        # Part C2: candidate domains for uncovered CCNs
Rscript analysis/05_crawl_txt.R           # Part C2: cms-hpt.txt crawl with vendor snowballing
Rscript analysis/06_footer_fallback.R     # Part C2: "Price Transparency" footer links
Rscript analysis/07_extract_gap_mrfs.R    # Part C2: download, filter, and parse gap MRFs
Rscript analysis/08_summaries.R           # Part D: per-CCN summaries, coverage, flags
Rscript analysis/09_build_database.R      # hpt.duckdb star schema (readable from R duckdb 1.4.4)
Rscript analysis/10_validate.R            # spot-check validation report
Rscript analysis/11_state_medians.R       # median price per state x insurance type x code
Rscript analysis/12_addon_value.R         # is an add-on procedure worth the lost primary capacity?
Rscript analysis/13_ownership_prices.R    # private-equity vs other hospitals
Rscript analysis/14_emb_payer_ratios.R    # within-hospital payer-to-Medicare ratios
Rscript analysis/15_geographic_figures.R  # colonoscopy maps and state ranking, relative to Medicare OPPS
```

### The database (`hpt.duckdb`)

| Table | Grain | Notes |
|---|---|---|
| `fact_rate` | file x charge line x code x payer/plan | sorted by (code_id, file_id); ENUM setting, billing class, methodology; `plausible`, `fee_type` (+ `fee_type_inferred`), and `case_line` flags |
| `ref_code_gross` | code | typical facility and professional gross, the blank-billing-class cutoff, case-line thresholds |
| `dim_code` | codebook code | concept, `anchor` (reference code per concept), `active_2026` |
| `dim_payer` | distinct payer/plan text | `payer_type` from `config/payer_type_rules.csv`; Trilliant's own label kept alongside |
| `dim_file` | MRF file | source, URL, version, dates, header identifiers |
| `bridge_file_ccn` | file x CCN | unambiguous crosswalk matches only |
| `dim_hospital` | CMS CCN | roster plus AHRQ health system |
| `v_rate`, `v_hospital_rate` | views | denormalized; `v_hospital_rate` has one row per hospital a rate applies to, with state |

State medians are three-stage: the median of each payer/plan contract's rows, then the
median across contracts within each hospital, then the median across hospitals in the
state. That way a hospital listing 40 plans counts the same as one listing 3.

Rows that price a different product than the procedure are left out
(`rate_row_filter_sql()` in `R/state_medians.R`): explicitly inpatient rows and
operating-room case lines of outpatient procedures, case-rate and per-diem rows of the
office procedures (EMB, IUD insertion), and blank-billing-class rows whose gross is
professional-level. Rules and their evidence: `case_line_multiple()` in `R/duckdb_store.R`.

Every crawl stage is resumable and logs per-item status under `HPT_DATA_DIR/state/`.
Set `HPT_MAX_ITEMS` for a pilot run.

Lake queries run through the DuckDB CLI (>= 1.5, required for DuckLake 1.0), not the R
`duckdb` package.

## Tests

```sh
Rscript tests/testthat.R
```

All tests are offline. Fixtures are small synthetic files built from the verbatim CMS
v3.0 template headers, and they go through the real DuckDB and jq read paths.
