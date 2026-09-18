# Technical appendix

This appendix documents how `hpt_prices` turns hospital price-transparency files into
state and national prices, and every rule applied along the way. Two analyses have their own
methods documents and are only summarized here:

- [`docs/addon_methods.md`](addon_methods.md): is an add-on procedure (IUD insertion at bariatric
  surgery, endometrial biopsy at colonoscopy) worth the primary capacity it displaces?
- [`docs/ownership_methods.md`](ownership_methods.md): do private-equity-owned hospitals post
  different prices?
- [`docs/childbirth_methods.md`](childbirth_methods.md): delivery prices relative to Medicare, the
  cesarean-vaginal facility price differential, and midwifery supply (section M). The NTSV
  cesarean design is locked in [`docs/childbirth_analytic_spec.md`](childbirth_analytic_spec.md).

Acquiring the Trilliant file is covered in [`docs/trilliant_download.md`](trilliant_download.md).

Numbers below come from the final build of 2026-09-13 (database built from the 2026-07-21
Trilliant snapshot) unless stated otherwise. Only national summaries are reported; hospital-level
rates stay on the data drive (section A).

## Contents

- [A. Data sources and terms](#a-data-sources-and-terms)
- [B. Extraction from the Trilliant lake](#b-extraction-from-the-trilliant-lake)
- [C. CCN crosswalk](#c-ccn-crosswalk)
- [D. Own-crawl gap filling](#d-own-crawl-gap-filling)
- [E. Database and load-time cleaning rules](#e-database-and-load-time-cleaning-rules)
- [F. Three-stage medians](#f-three-stage-medians)
- [G. Payer-to-Medicare ratios](#g-payer-to-medicare-ratios)
- [H. The Medicare benchmark](#h-the-medicare-benchmark)
- [I. Geographic figures](#i-geographic-figures)
- [J. Known data issues and caveats](#j-known-data-issues-and-caveats)
- [K. Validation summary](#k-validation-summary)
- [L. Reproducibility](#l-reproducibility)
- [M. Childbirth prices and midwifery supply](#m-childbirth-prices-and-midwifery-supply)

## A. Data sources and terms

| Source | What it provides | Version used |
|---|---|---|
| Trilliant Health Hospital MRF Data Directory ("Full Data Download" on Oria) | Parsed hospital machine-readable files (MRFs): charge lines, codes, gross, cash, and payer/plan negotiated rates, as a DuckLake (DuckDB catalog plus Parquet) | Snapshot 2026-07-21: 79,646,417,056-byte zip, 7,916 facility entries, 4,923 distinct files |
| CMS Hospital General Information | The hospital roster (5,419 CCNs), state, type, ownership | Downloaded 2026-09-12, with provenance |
| CMS Hospital Enrollments (+ Additional NPIs) | Type 2 NPI to CCN (11,338 NPI-CCN pairs) | 2026-07-31 release |
| AHRQ Compendium of US Health Systems | Health-system membership of each hospital | 2023 hospital linkage |
| cms-hpt-tracker (github.com/anthonyisnotadev/cms-hpt-tracker, AGPL-3.0) | Each CCN's `cms-hpt.txt` and MRF URLs | Pinned snapshot; used as data only, no code copied |
| CMS OPPS Addendum B | National unadjusted outpatient payment rate and status indicator per HCPCS code | July 2026 (`2026 July Web Addendum B.07.13.26.csv`) |
| CMS FY 2026 IPPS final rule (CMS-1833-F), Tables 2 and 3 | Wage index by CCN (Table 2) and statewide rural wage index (Table 3) | fy2026-ipps-fr-tables-2-3-4a-4b.zip, sha256 `863f1cb2...5386d` |
| CMS PFS RVU file | Code validation and professional-fee benchmarks | RVU26C (July 2026) |

Every download writes a provenance CSV (URL, release, sha256, time) next to the file under
`HPT_DATA_DIR/reference/`.

**Trilliant terms of service.** Trilliant requires attribution (2.2(b)) and forbids automated
scraping of its site (2.3(xii)) and building rate data for redistribution to third parties (2.3(i),
2.3(iii)). The project therefore:

- reads only the consolidated download, never the per-hospital pages;
- keeps every extracted rate, median, and derived table under `HPT_DATA_DIR` (`.gitignore`
  excludes `output/`, `*.parquet`, `*.duckdb`);
- cites Trilliant in every figure caption;
- should not be used to publish a rate database. Confirm with Trilliant before publishing a paper
  built on it.

**Public code copy.** This repository stays private because its docs and figures carry
Trilliant-derived numbers. A code-only copy, github.com/mufflyt/hpt_prices_public, is built from it
by `tools/export_public.sh`. The copy includes code, tests, config, tools, CI, and
`docs/trilliant_download.md`. It leaves out:

- the figures (`docs/figures/`);
- the CHANGELOG, NEWS, this appendix, and the methods and impact docs;
- `config/known_answers.csv`.

The export reads every known-answer value and file hash from `config/known_answers.csv` and refuses
to write if any appears in the exported tree. To keep the code publishable:

- code comments state each rule's evidence qualitatively and point here for the numbers;
- payer-rule notes carry no lake row counts;
- test fixtures use synthetic values.

## B. Extraction from the Trilliant lake

`analysis/01_trilliant_extract.R` and `R/trilliant.R`.

**Layout.** Payer-level rates are in the `current_charge_details` view (`current_charges` holds
only per-service summaries with no payer rows). Facilities are `current_hospitals`, keyed by
`internal_id` + `run_date` (`hospital_id` is 1 everywhere). The file URL and content hash are in
`lake.hospital_versions`; the facility NPI and license state are in `lake.hospital_identity`.
`trilliant_relations()` resolves these at run time, so older per-hospital databases (and the test
fixture) still work.

**Two stages.** A single query over the whole lake ran the 16 GB Mac out of memory. Stage 1
streams the lake once, keeping any charge line whose code columns hold a codebook code, and writes
`stage_target_lines.parquet`. Stage 2 applies the code-type rules on that small file. The scan takes
about 55 minutes (I/O bound); re-matching with `HPT_REUSE_STAGE=true` takes about 9. DuckDB runs
through the CLI at 5 GB memory and 3 threads, spilling to the data drive.

**Code-type gating** (`R/codes.R`). A code counts only when its value and its declared type agree:
`cpt`/`hcpcs` columns for procedures, `ms_drg` for DRGs (trimmed and zero-padded to 3 digits),
`other_code1/2` only when the type column matches. Chargemaster (CDM) numbers, revenue codes, and
APR-DRG or TRICARE DRGs never match, even when the digits coincide (a CDM item "58100", APR-DRG
742). A missing type, or a generic "DRG", is kept with `type_verified = FALSE`. A charge line that
carries several target codes becomes one row per code.

**No final DISTINCT.** Hospitals list the same code on many charge lines. HCA lists MS-DRG 742 on 69
distinct lines, and collapsing duplicates moved Houston Southeast's pooled median from $4,429 to
$4,786. Repetition is handled by the median stages (section F), not by deleting rows.

**Shared files.** Trilliant duplicates a shared MRF under every facility that points to it (the HCA
Houston emergency departments share one 909 MB file). Each file is read once, through one
representative facility, keyed by `mrf_content_hash`; the facility-to-file mapping is kept
separately so every facility still reaches its CCN.

Result: 8,294,624 rate rows from 3,987 Trilliant files for the 55-code codebook.

## C. CCN crosswalk

`analysis/02_ccn_crosswalk.R`, `R/ccn_match.R`, `R/hospital_universe.R`. MRFs identify hospitals by
name, address, license, and NPI, never by CCN. Tiers, first success wins:

1. `mrf_url`: the file's URL appears in the cms-hpt-tracker manifest.
2. `npi`: a type 2 NPI declared in the file is in CMS Hospital Enrollments. CCNs are normalized
   with `normalize_ccn()` (Enrollments drops the leading zero on some CCNs: 60011 becomes 060011).
3. `license`: license number plus state, only with a caller-supplied table (no free national
   license-to-CCN source exists).
4. `name_address`: name, street, and city similarity against roster hospitals in the same state,
   accepted only above a threshold with a clear margin over the runner-up. Before scoring, the
   same-state candidates are narrowed by a hard key: the facility's ZIP where one agrees,
   otherwise its city (`block_ccn_candidates()`). A candidate whose key is unknown is never
   dropped, because a missing ZIP cannot contradict one. `ccn_block_key` records which key
   narrowed the field. A match resting on the name alone, with no street address and nothing but
   the state agreeing, must clear a higher score (0.75 against the usual 0.60); a file that
   carries a street address is not penalised, since the address is scored by containment and
   zeroed outright when house numbers differ. Phone number would be a better block than either
   and is unavailable: the CMS roster carries one, an MRF does not.


When a URL match and an NPI match disagree, the row is flagged `ccn_conflict`, and that file is
not attributed to the disputed CCN: `v_hospital_rate` joins the bridge only where the flag is
false, so the file's rates count as their own unit in a state median rather than being credited
to a hospital the evidence disputes. The bridge keeps the row and the flag, so the conflict stays
auditable. As of the 2026-09-13 build this affects 17 files, 16 hospitals and 17,877 rate rows;
14 of those hospitals have no other file, so they lose their CCN identity while their rates
remain in the state totals. The database bridge
keeps unambiguous matches only, one row per (file, CCN), and only roster CCNs. CCNs linked per tier
(a CCN can be reached by more than one file): URL 2,794, name/address 521, NPI 165. In total
3,371 of 5,419 roster CCNs (62%) have prices.

**URL normalization and the para-hcfs lesson.** `normalize_url_key()` lowercases the host, drops the
scheme and trailing slash, and decodes `%20`. Whether it drops the query string depends on the path:

- dropped on data-file paths (`.csv`, `.json`, `.zip`, `.gz`, `.xlsx`, `.txt`, where a query is a
  cache-buster) and on signed or expiring URLs (S3 `X-Amz-*`, Azure SAS, `Signature`/`Expires`);
- kept on script endpoints, where the query names the file.

An earlier version always dropped it. 516 facilities publish through
`apps.para-hcfs.com/PTT/FinalLinks/Reports.aspx?dbName=...`: 317 distinct URLs that collapse to 4
keys without the query. The URL tier then bridged other hospitals' files to about 300 CCNs (one
hospital showed a colonoscopy price from a file that has no colonoscopy code for it at all). The
fix changed national medians only slightly (commercial 45378 $2,078 to $2,070) but corrected the
affected hospitals and states.

## D. Own-crawl gap filling

`analysis/03`-`07`. For hospitals Trilliant is missing, the pipeline can crawl `cms-hpt.txt` files
itself:

- seed domains come from the tracker, TPAFS, DoltHub, and HIFLD;
- each host's `cms-hpt.txt` is fetched, with snowballing to vendor hosts;
- a "Price Transparency" footer fallback honors robots.txt;
- MRFs are downloaded resumably, then parsed (CSV v2/v3 tall and wide; JSON streamed through jq)
  and deleted one at a time.

Requests are throttled to 1 per second per host and interleaved by host. A 401/403 is recorded as
blocked and never retried around. The current database holds the 16-file pilot (6,782 rows). Files
present in both sources count once in the medians and stay in the database for the cross-source
check (section K).

## E. Database and load-time cleaning rules

`analysis/09_build_database.R`, `R/duckdb_store.R`. `hpt.duckdb` is a star schema written by the
DuckDB CLI in v1.4.0 storage format, so the R duckdb package can read it. The build takes about
4 minutes. Current size: 11,499,113 rates, 4,016 files, 58,114 payer/plan strings, 3,371 CCNs, 79
codes. The delivery DRG and obstetric CPT codes added on 2026-09-13 account for the growth from
8,301,406 rates (section M).

| Table | Grain |
|---|---|
| `fact_rate` | file x charge line x code x payer/plan; sorted by (code_id, file_id) for zone-map pruning |
| `dim_code`, `dim_payer`, `dim_file`, `dim_hospital` | code, payer/plan text, MRF file, CMS CCN |
| `bridge_file_ccn` | file x CCN (unambiguous crosswalk matches) |
| `ref_code_gross` | code: typical facility and professional gross, the blank-class cutoff, case-line thresholds |
| `v_rate`, `v_hospital_rate` | denormalized views; `v_hospital_rate` has one row per hospital a rate applies to, with state |

Rules are applied once, at load, as flags on the row; rows are never deleted. Analyses apply
them through one predicate, `rate_row_filter_sql()` in `R/state_medians.R`, shared by the
medians, payer ratios, ownership prices, and figures.

**E1. `plausible`** (`plausible_rate_sql()`). A negotiated dollar amount is implausible at $1 or
less (placeholder "0.01" values), when it is a 9-filled sentinel (999999.99), or above $2,000,000.
99.8% of dollar rates are plausible.

**E2. `fee_type` and `fee_type_inferred`.** Facility and professional fees are reported separately.
An explicit billing class decides it. Most files leave billing class blank, and a blank used to
count as facility, which let unlabeled physician fees ("45378 - PF COLONOSCOPY", "HOSPITALIST BP
45378", or plain "DIAGNOSTIC COLONOSCOPY" at $160-380) into facility medians against an OPPS facility
rate near $950. The rule now:

- For each code, `ref_code_gross` takes the typical facility and typical professional gross (median
  across files of each file's lowest gross), from explicitly classed outpatient rows only.
- A blank-class row with a gross below the geometric midpoint of the two typicals is inferred
  professional. For 45378: facility $3,022, professional $957, cutoff $1,701.
- The rule runs only where each typical rests on at least 20 files and the two differ by at least
  2.5x. Codes where gross cannot tell the two apart (58100 and 58300 separate by only 2.2x, 88305
  by 1.9x) keep blank as facility.
- Validation against the Medicare Advantage rate on the same blank-class lines (a line is
  professional when its MA rate is below the geometric midpoint of the national MA facility and
  professional rates): the share classified consistently was 58120 90% vs 62% under "blank =
  facility", 45378 81% vs 77%, G0121 74% vs 72%, 58100 65% vs 66% (hence the 2.5x floor).
- Because the rule also moves some true facility lines (214 of 1,222 checked 45378 lines), inferred
  professional rows are dropped from facility fees and not counted as professional fees either.
  Professional medians therefore rest on explicitly labeled rows.

Effect: national commercial facility 45378 rose from $2,070 to $2,220, and the national Medicare
facility median moved from $927 to $958, now 1.008x the OPPS rate. 142,002 rows are inferred
professional.

**E3. `case_line`** (outpatient procedures only). Some hospitals list an office procedure twice: a
clinic line and an operating-room case line with the same CPT code. Community Health Systems files
list 58300 at about $190 gross and again as "INSERT INTRAUTERINE DEVICE" at $20,000-75,000. A charge
line whose gross exceeds 10x the typical gross for its code and fee type is a case line. The 10x
multiple comes from the 58300 facility gross distribution, which is bimodal: a clinic mode at
$180-560, a second mode of OR lines from about $5,000 to $100,000, and a trough at $3,000-4,000
(10x the typical is $5,140). A within-file rule (5x the file's lowest line) was rejected because it
flagged ordinary colonoscopy lines whose rates were no higher than the rest. 30,603 rows are
flagged; about 4% of 58300 rows and under 2.2% for every other code.

**E4. Office-procedure package rates** (query time). For endometrial biopsy and IUD insertion,
case-rate and per-diem rows are excluded. CMS defines a case rate as "a flat rate for a package of
items and services triggered by a primary procedure", so a case rate for 58300 prices the surgical
case, not the insertion. Commercial 58300 case-rate rows had a median of $1,750-2,940 against
$226-255 for fee-schedule and percent-of-charges rows. Colonoscopy keeps its case rates: the
endoscopy encounter is the product. Together E3 and E4 moved national commercial facility 58300
from $551 to $417.

**E5. Setting.** Outpatient procedures (colonoscopy, EMB, IUD insertion and devices, pathology, D&C,
hysteroscopy) exclude rows whose setting is explicitly inpatient.

**E6. Payer type** (`config/payer_type_rules.csv`, 14 ordered regex rules, first match wins, applied
identically in R and SQL). Nine insurance types plus "unknown": commercial, Medicare Advantage,
Medicare, Medicaid, exchange, TRICARE/VA, workers' compensation, self-pay, and other. The median stage
adds the discounted cash price and the gross charge alongside them. Order matters. Examples:

- Medigap is Medicare before any Medicare Advantage rule.
- Carrier names next to "Medicare" are MA before the exchange and Medicaid rules.
- Exchange comes before Medicaid, because Centene names exchange plans after its Medicaid plans
  ("Ambetter from Sunshine Health").
- Rule 9 types ConnectiCare (a Connecticut commercial and exchange insurer owned by Molina since
  2025) and "Buckeye Commercial" (Centene's Ohio commercial product) as commercial before the
  Medicaid rule's "molina" and "buckeye" brands match. Connecticut Medicaid has no managed-care
  plans; the old typing produced a Connecticut colonoscopy "Medicaid" median of $5,657.

Every rule change adds a regression case to `tests/testthat/test-validation.R`. Adjudicated
agreement with Trilliant's own payer labels is 92.9%.

**E7. States** (`clean_state_sql()`). A file with no CCN match takes its state from the facilities
that publish it. Trilliant's `hospital_state` sometimes holds a street token ("PO" from "PO Box",
"NW" and "SE" from street quadrants), which had created three false state units from five files.
Only USPS codes are kept; otherwise the two-letter code before the ZIP at the end of the address;
otherwise NULL. Matched files take the state from the CMS roster.

**E8. File exclusions** (medians only; `output/median_excluded_file_ids.csv`, 45 files):

- files where most rates exceed gross, a sign of unit errors (35 files, listed in
  `files_rates_above_gross.csv`);
- own-crawl files that duplicate a Trilliant file (`cross_source_duplicate_file_ids()`).

**Stage 1 is resumable.** The lake scan reads `standard_charge_details` through its own parquet
files (246 of them, 67 GB, 7.7 billion rows, listed in DuckLake's `ducklake_data_file`), in
batches of `HPT_STAGE_BATCH` files (default 20). Each batch writes one part under
`stage_parts/` and is recorded in `stage_parts/_manifest.csv` only after DuckDB closes the file,
so an interrupted scan resumes at the first unfinished batch instead of starting over, and a
half-written part is rewritten rather than half-read. The log reports files done and rows kept per
batch; before this, the only progress signal was a staging file's size.

Reading the files directly is only valid when nothing else holds rows for the table:
`trilliant_lake_data_files()` returns NULL, and the single scan runs instead, if the table has
delete files, if its inlined-data table holds rows, or if any listed file is missing. Note that
DuckLake registers an inlined-data table for every table whether or not it holds rows, so the
check counts rows rather than trusting the registration.

**E9. Per-diem MS-DRG rates** (`per_diem_case_multiple()`, `per_diem_note()`). A per-diem contract
prices one day of an inpatient stay. A hospital paid per diem therefore looked several times
cheaper than one paid by case rate for the same DRG.
- **Conversion.** At load, a per-diem rate for any MS-DRG becomes a stay price: `case_dollar` =
  rate x the DRG's geometric mean length of stay (CMS FY 2026 IPPS Table 5), and
  `per_diem_converted` marks the row.
- **Mislabeled per diem.** Following Turquoise Health's delivery-price method, a "per diem" rate at
  or above 3x Medicare's national per-day payment for the DRG is taken as a stay price and not
  multiplied; `per_diem_as_case` marks it. The per-day payment is the standard IPPS payment at wage
  index 1, divided by the length of stay.
- **Where the prices live.** `negotiated_dollar` keeps the listed rate. Medians, payer ratios, and
  ownership prices use `case_dollar`, which equals `negotiated_dollar` on every other row.

| Concept | Converted | Kept as stay price | Files with per-diem rows / files |
|---|---|---|---|
| Vaginal delivery DRGs | 13,309 | 2,797 | 658 / 2,694 |
| Cesarean DRGs | 12,612 | 4,020 | 622 / 2,692 |
| DRG 742/743 uterine | 5,422 | 459 | 497 / 2,725 |
| DRG 619-621 bariatric | 6,207 | 281 | 394 / 2,488 |

**Effect on the headline numbers.**
- National commercial DRG 742 rose from $24,361 to $25,133, and Medicaid from $14,443 to $14,525.
- DRG 621 did not move for commercial, Medicaid, or Medicare.
- The add-on model's DRG 620 variant moved by $3 (section F; `docs/addon_methods.md`).
- One more hospital entered several Medicaid cells in the same rebuild (colonoscopy, D&C,
  hysteroscopy, and DRG 621). The cause was not isolated, since the earlier build's outputs were
  overwritten. It moved the national colonoscopy Medicaid ratio from 0.778x to 0.781x and the
  ownership model's Medicaid and DRG 621 estimates by at most 2 percentage points.

## F. Three-stage medians

`analysis/11_state_medians.R`, `R/state_medians.R`.

1. Per hospital x code x payer/plan: the median of that contract's rows (files repeat one contract
   rate on many charge lines).
2. Per hospital x code x insurance type: the median across that hospital's contracts.
3. Per state x code x insurance type: the median and interquartile range across hospitals. A
   national row (state "US") uses the same stages over all hospitals.

A hospital is a CCN; a file with no CCN match counts as its own unit. The discounted cash price and
gross charge are added as insurance types, deduplicated per charge line first. The headline table
suppresses cells with fewer than 3 hospitals and uses MS-DRG 621 as the bariatric price (CPT-coded
bariatric lines are partial). National facility medians:

| Code | Commercial | Medicaid | Medicare | Medicare Advantage | Cash |
|---|---|---|---|---|---|
| 45378 colonoscopy | $2,220 | $753 | $958 | $954 | $1,993 |
| 58100 EMB | $396 | $164 | $201 | $205 | $291 |
| 58300 IUD insertion | $417 | $153 | (not covered) | (not covered) | $266 |
| MS-DRG 621 bariatric | $21,154 | $12,436 | $12,907 | $12,809 | $22,314 |
| MS-DRG 742 uterine | $25,133 | $14,525 | $15,521 | $15,345 | $24,857 |

## G. Payer-to-Medicare ratios

`analysis/14_emb_payer_ratios.R`, `R/payer_ratios.R`. For each hospital listing both a payer type's
rate and a traditional Medicare rate for the same code and fee type, ratio = payer rate / Medicare
rate (each the contract-then-hospital median of section F). The median across hospitals is an
empirical multiplier; comparing within a hospital removes differences in which hospitals list which
payers. These replace emb_colonoscopy's provisional flat multipliers (Medicaid 0.70x, commercial
1.75x). Professional fees, final build:

| Code | Medicaid | Commercial | Hospitals |
|---|---|---|---|
| 58100 EMB | 0.883 | 1.775 | 72-73 |
| 88305 pathology | 0.916 | 1.800 | 55-60 |
| 58120 D&C | 0.775 | 1.626 | 65-66 |
| 99213 office visit | 0.836 | 1.492 | 110-114 |

Professional-fee rows come only from hospitals that list employed-physician fees, which is why the
hospital counts are small.

## H. The Medicare benchmark

`R/geo_figures.R`. The geographic figures divide each hospital's negotiated facility rate by what
traditional Medicare's outpatient system pays that hospital:

    medicare_opps = Addendum B rate x (0.6 x wage index + 0.4)

The labor share is 60% (42 CFR 419.43(c)). The wage index is the FY 2026 IPPS Table 2 value by CCN
(the low-wage-index transition value where one is listed, plus any out-migration adjustment).
Hospitals absent from Table 2 (mostly critical access hospitals, which Medicare pays on cost) get
their state's rural wage index from Table 3, so their ratio is against what OPPS would pay in that
area. For colonoscopy, 1,763 hospitals use Table 2 and 508 the state rural fallback.

**Why not hospital-listed Medicare rates.** Only about 570-630 hospitals list a traditional Medicare
rate for 45378, fewer than 5 in 16 states, and some state medians are implausible for a national
fee schedule (Utah $169 with 6 hospitals, Montana $2,011 with 3). The OPPS benchmark exists for
every hospital. Nationally, hospital-listed Medicare facility medians agree with it closely (section
K), and the national Medicare Advantage ratio comes out at exactly 1.00x.

## I. Geographic figures

`analysis/15_geographic_figures.R`, `R/geo_figures.R`. All figures use colonoscopy (45378) facility
rates, relative to each hospital's OPPS benchmark. A state's value is the median of its hospitals'
ratios.

- **Maps** (`geo1`, supplement `supp_geo3`) are drawn with
  `mysterymaps::mysterymaps_geographic_map()` for the polygons, Albers projection, and theme, with a
  log-scale diverging fill centered on 1x. States with fewer than 5 hospitals are suppressed: a
  neutral hatched fill, no estimate. Plain light grey means no data. Alaska and Hawaii are omitted
  from the maps and shown in the ranking chart.
- **Ranking chart** (`geo2`): one panel per Census region, one row per state carrying both payers
  (commercial and Medicaid), dot = state median, bar = within-state 25th to 75th percentile, hollow
  dot = fewer than 5 hospitals, solid line = Medicare, dashed lines = national medians. The tallest
  panel has 17 rows, so labels stay readable on screen.
- **Medicare Advantage** goes to the supplement: the map on the same color scale (`supp_geo3`) and a
  state-ranking chart (`supp_geo4`).

National medians: commercial 2.30x Medicare, Medicaid 0.78x, Medicare Advantage 1.00x.

**Spread across states** (states with at least 5 hospitals):

| Payer | States | p90/p10 of state medians | Within-state p75/p25 (median) | Variance explained by state |
|---|---|---|---|---|
| Commercial | 48 | 1.96 | 1.72 | 20% |
| Medicaid | 38 | 4.61 | 1.84 | 25% |
| Medicare Advantage | 46 | 1.10 | 1.09 | 13% |

**System-weighting sensitivity** (`supp_geo5`, `output/geo_system_weighted_45378.csv`). State
medians are hospital-weighted, so a system with many hospitals in a state dominates it. The
sensitivity gives each health system one value per state (its hospitals' median; independent
hospitals count as their own system):

| Payer | Spearman with hospital-weighted | p90/p10 hospital-weighted | p90/p10 system-weighted | State R2 hospital-level | State R2 system-level |
|---|---|---|---|---|---|
| Commercial | 0.72 | 1.96 | 1.67 | 0.20 | 0.14 |
| Medicaid | 0.81 | 4.61 | 3.63 | 0.25 | 0.20 |
| Medicare Advantage | 0.76 | 1.10 | 1.08 | 0.13 | 0.13 |

The finding holds: commercial varies roughly 1.7-2x across states, Medicaid more, and Medicare
Advantage stays flat. But about a sixth of the commercial spread and a quarter of the state share of
variance come from large systems, and some state positions mostly reflect one system: West
Virginia, North Carolina, Vermont, Kansas, Georgia, and Connecticut's Medicare Advantage outlier.

## J. Known data issues and caveats

- **IUD insertion (58300) is not covered by traditional Medicare** (OPPS status E1; PFS status N).
  Hospital-listed Medicare and Medicare Advantage rates for it are not payment benchmarks, the OPPS
  check is skipped, and 58300 is omitted wherever a Medicare-relative comparison would be drawn.
- **HCA 58300 lines.** HCA's 148 hospitals list 58300 only on a line with no gross, no cash price,
  and no methodology, at outpatient-surgery rates (commercial about $2,125, Medicare Advantage about
  $2,350). No chargemaster-based rule can separate them from clinic insertions, so they remain in
  the 58300 medians.
- **Connecticut Medicare Advantage.** 7 of Connecticut's 14 hospitals belong to Hartford
  HealthCare, which posts a UnitedHealthcare MA colonoscopy rate far below Medicare. That is what
  the files say; the state's MA median (0.34x) reflects it. Under system weighting it becomes 0.98x.
- **West Virginia Medicaid** (0.2x Medicare for colonoscopy). WVU Medicine files list several
  Medicaid plans at $100-181 on fee schedules, including three Pennsylvania Medicaid plans. The
  rates are consistent across payers and look like real contracts rather than a parsing error, but
  cannot be confirmed from the files.
- **Michigan commercial** colonoscopy is about 1.1x Medicare, consistent across independent systems,
  and appears to be a genuine market feature.
- **Critical access hospitals** get a state rural wage index in the benchmark (section H); their
  real Medicare payment is cost-based.
- **Coverage.** 62% of roster CCNs have prices (3,371 of 5,419). Coverage is thinnest in Puerto Rico
  (7%), DC (20%), Maryland (34%), Louisiana (44%), and Rhode Island (46%). VA and DoD hospitals are
  exempt from the rule.
- **ConnectiCare rule edge case.** One plan, "EMBLEM HEALTH MEDICAID / CCMC HB CONNECTICARE REIMB
  CONTRACT" (15 rates in one file), is typed commercial because the ConnectiCare rule runs before the
  Medicaid rule, although its payer name says Medicaid.
- **Shared vendor files.** A file with no CCN match takes the most common state among the
  facilities that publish it. Aiken Regional's unmatched file shares a vendor URL with MedStar
  Washington's, so it counts as DC rather than South Carolina (one file).
- **Codes only in descriptions** or CDM/local columns are missed by design.
- **Rates above gross** remain in 6.6% of rates that carry a gross charge (validation warning); the
  35 files where most rates exceed gross are excluded from medians.
- **APR-DRG-only inpatient prices are missed**, except for delivery. Code-type gating never lets
  an APR-DRG match an MS-DRG, so a hospital that posts hysterectomy or bariatric prices only as
  APR-DRGs has no DRG price here. Delivery has an opt-in fallback (section M), off by default.
- **Per-diem threshold** (E9). A per-diem rate just under 3x the Medicare per-day payment is
  multiplied even if it is really a mislabeled stay price.
- **Midwife roster coverage.** The NPI-linked AMCB roster read from the midwifery repository covers
  40 states. Midwifery exposures are missing, not zero, wherever a catchment reaches AK, DC, DE,
  HI, ND, NJ, RI, SD, VT, WV, or WY (section M).

## K. Validation summary

`analysis/10_validate.R`, `R/validation.R`, `output/validation_report.md`. 50 checks: 44 pass,
4 warn, 0 fail, 2 skip.

- **Integrity:** keys, bridge, row counts, file ids, and medians current: all pass.
- **Known answers** (`config/known_answers.csv`, private; the check skips without it): Denver
  Health and HCA Houston Healthcare Southeast reproduce the live files exactly (for example 45378
  $1,289.13 and $2,431.00; MS-DRG 742 $31,230.50 and $4,429.00).
- **CMS OPPS benchmark** (national hospital-listed Medicare facility median / Addendum B rate):

  | Code | Ratio |
  |---|---|
  | 45378 | 1.008 |
  | 45380 | 1.006 |
  | 45385 | 1.019 |
  | 58100 | 0.974 |
  | 88305 | 1.035 |
  | G0121 | 1.001 |
  | 58300 | skipped (not payable under OPPS) |

- **Cross-source agreement:** 98.5% of rates within $0.01 on files present in both Trilliant and
  the own crawl.
- **Payer types:** 92.9% adjudicated agreement with Trilliant's labels; stored types match the
  current rules.
- **Warnings:** rates above gross (6.6%, threshold 5%); 35 files with most rates above gross
  (excluded from medians); the thin self-pay payer rows disagree with the cash price for gastric
  bypass (43644), so the headline uses the cash price; CCN coverage 62% (threshold 70%).
- **Skipped:** the raw re-check (network opt-in).

## L. Reproducibility

**Requirements.** R (tested on 4.4) with the packages listed in `R/00_source_all.R`, plus arrow,
duckdb (R), sf, maps, patchwork, and mysterymaps (github.com/mufflyt/mysterymaps) for the maps. The
DuckDB CLI 1.5 or newer (DuckLake needs it; the R package is older). `jq` for JSON MRFs. About
170 GB free on the data drive for the lake and its extraction.

**Data location.** Set `HPT_DATA_DIR`. The default is whichever `/Volumes/MufflySamsung*` path is
a real mount point, preferring one that already holds `hpt_prices` (`hpt_volume_candidates()`).
macOS appends a number when a stale folder occupies the name, and the number changes between
mounts: the drive was at `MufflySamsung 1` on 2026-09-12 and at `MufflySamsung 3` on 2026-09-17,
with three stale, empty folders on the boot disk beside it. The candidates used to be a hardcoded
pair, which read as "drive not mounted" while the drive was plugged in.
`hpt_default_data_dir()` checks with `df` that the path is a real mount point, because a stale
folder at `/Volumes/MufflySamsung` would otherwise fill the boot disk. Before 2026-09-13 that check
ran even when `HPT_DATA_DIR` was set (`Sys.getenv()` evaluates its `unset` argument), so the
pipeline failed on any machine without the drive. It now runs only when `HPT_DATA_DIR` is unset;
`tests/testthat/test-codes.R` guards this.

**Order and runtimes** (16 GB Mac, external SSD):

| Step | Script | Runtime |
|---|---|---|
| Extract | `analysis/01_trilliant_extract.R` | about 55 min (9 min with `HPT_REUSE_STAGE=true`) |
| Crosswalk | `analysis/02_ccn_crosswalk.R` | minutes |
| Gap crawl (optional) | `analysis/03`-`07` | depends on the crawl |
| Summaries | `analysis/08_summaries.R` | minutes |
| Database | `analysis/09_build_database.R` | about 4 min |
| Validation | `analysis/10_validate.R` | minutes |
| State medians | `analysis/11_state_medians.R` | under 1 min |
| Add-on model | `analysis/12_addon_value.R` | about 30 s |
| Ownership | `analysis/13_ownership_prices.R` | about 5 min (wild cluster bootstrap) |
| Payer ratios | `analysis/14_emb_payer_ratios.R` | seconds |
| Geographic figures | `analysis/15_geographic_figures.R` | about 30 s |
| Childbirth prices | `analysis/16_childbirth_prices.R` | about 1 min |
| Midwifery presence | `analysis/17_midwifery_presence.R` | about 5 min (wild cluster bootstrap) |
| NTSV and midwife supply | `analysis/18_ntsv_midwife_supply.R` | minutes; needs the CDC WONDER exports (section M) |

Run the median-dependent steps (11, 12, 14) after any rebuild, and step 10 last. DuckDB is capped at
5 GB and 3 threads and spills to `HPT_DATA_DIR/duckdb_tmp`.

**Tests and CI.**
- `Rscript tests/testthat.R` runs the offline suite, with `HPT_DATA_DIR` set to a temporary folder
  so tests never touch real data. `tools/run_test_file.R <file>` runs one file.
- `tests/testthat/fixtures/README.md` records where every fixture came from and which tool
  regenerates it.
- GitHub Actions runs the suite on the public code copy, installing the R packages and the DuckDB
  CLI. Actions is turned off in this private repository.

**Smoke tests.** `tools/smoke_ntsv.R` runs `analysis/18` end to end on synthetic WONDER exports
in a temporary data folder whose other inputs are symlinks to the real ones (about 1 minute).

**Publishing a code change.** Merge here first. Then run
`tools/export_public.sh ~/hpt_prices_public`, review the diff in that clone, commit, and push. The
copy's CI runs on the push.

## M. Childbirth prices and midwifery supply

Full methods: [`docs/childbirth_methods.md`](childbirth_methods.md). Design of the NTSV analysis:
[`docs/childbirth_analytic_spec.md`](childbirth_analytic_spec.md).

- **Codes.** Facility prices are MS-DRGs 783-788 (cesarean) and 796-798 and 805-807 (vaginal),
  anchored on 788 and 807. Physician fees are CPT 59400-59622.
- **Hospitals.** Only hospitals with a labor and delivery unit count (CMS SM-7 not "Not
  Applicable"; no psychiatric hospitals or Rural Emergency Hospitals). 1,602 have a delivery price.
- **Benchmark.** The standard FY 2026 IPPS payment for the DRG at the hospital's wage index
  (operating plus capital, Tables 1A-1E, 2, 3, and 5). It leaves out the IME, DSH, outlier, and
  quality adjustments. Hospital-listed Medicare delivery rates run 1.14x-1.18x this benchmark.
- **Headline.** Commercial DRG 807 is $8,584 (1.72x Medicare) and DRG 788 $12,465 (1.74x);
  Medicaid is $5,396 (1.08x) and $7,643 (1.10x). Within hospitals, the cesarean price is 1.42x the
  vaginal price for both payers, exactly the ratio of Medicare's DRG weights.
- **Language.** The cesarean-vaginal gap is a facility price differential, not savings or value.
- **APR-DRG fallback** (`HPT_BIRTH_APR_DRG=true`, off by default). The codebook carries APR-DRG
  560-1 and 540-1 in their own `apr_drg` family, matched only when the row's declared type names
  the APR grouper (`apr_drg_code_types()`); an untyped or MS-DRG-typed three-digit code never
  matches one. `add_apr_drg_delivery_prices()` lets a severity-1 price stand in for MS-DRG 807 or
  788 at a hospital posting no MS-DRG delivery price, never overwriting one, labelling each row
  `price_source`. How much coverage it adds is not yet measured: it needs a re-extract.
- **Midwifery presence** (`analysis/17`, exploratory):
  - Exposure: midwives within 30 miles per 1,000 births within 30 miles.
  - Result: no association with delivery prices or the premium. The high tertile's commercial
    price is +3.2% (-8.7% to +16.6%).
  - Coverage: the 40-state roster, with the coverage guard.
- **NTSV cesareans** (`analysis/18`):
  - County-of-residence NTSV rates from manual CDC WONDER exports (`wonder_ntsv_exports()`).
  - Model: births-weighted linear, state fixed effects, wild cluster bootstrap.
  - Checks: placebo and negative-control outcomes.
  - Price step: the implied facility price differential by payer.
  - Status: the code is tested and smoke-tested; waiting on the exports.
- **Reference point.** Turquoise Health's delivery-price study (commercial only) is compared in
  [`docs/turquoise_pricepoints.md`](turquoise_pricepoints.md). Its replication data is not
  downloadable.
