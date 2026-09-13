# Changelog

Grouped by date. There is no package version.

## 2026-09-13 (line-type cleanup; geographic figures)

### Fixed
- IUD insertion (58300) mixed three products under one code: clinic insertions, operating-room case
  lines, and outpatient-surgery case rates. Two rules now keep only the insertion itself
  (`rate_row_filter_sql()`, evidence in `case_line_multiple()`):
  - `case_line` (load time, all outpatient procedures): a charge line whose gross exceeds 10x the
    code's typical gross for its fee type. 58300 facility gross has a clinic mode at $180-560 and
    a second mode of OR lines at $5,000-100,000 (CHS lists "INSERT INTRAUTERINE DEVICE" at
    $20,000-75,000 beside a $190 clinic line). About 4% of 58300 rows are flagged; under 2.2% for
    every other code.
  - Case-rate and per-diem rows of the office procedures (EMB, IUD insertion) are left out: a CMS
    case rate prices a package triggered by a primary procedure. Commercial 58300 case-rate rows
    had a median of $1,750-2,940 against $226-255 for fee-schedule rows. Colonoscopy keeps them
    (its case rate is the endoscopy encounter).
  - National facility 58300: commercial $551 to $417, cash $316 to $266, MA $171 to $160. 58300 is
    not covered by traditional Medicare (OPPS status E1), so its Medicare and MA medians are not
    payment benchmarks. HCA (148 hospitals) lists 58300 only on a line with no gross and no
    methodology at outpatient-surgery rates (commercial about $2,125, MA $2,350), which no rule
    can separate; it remains.
- Blank billing class no longer means facility. Blank-class rows with a professional-level gross
  (below the geometric midpoint of the code's typical facility and professional gross, where the
  two differ by at least 2.5x) are `fee_type_inferred` professional and left out of both facility
  and professional fees. Colonoscopy facility medians had been pulled down by unlabeled physician
  fees ("45378 - PF COLONOSCOPY", "HOSPITALIST BP 45378"): national commercial 45378 $2,070 to
  $2,220, Medicare $927 to $958 (now 1.008x OPPS). Professional medians are unchanged. Iowa, South
  Dakota, and West Virginia commercial colonoscopy had sat below Medicare because of this.
- Payer type: "MOLINA dba CONNECTICARE" was Medicaid through the Molina rule. ConnectiCare is a
  commercial and exchange insurer and Connecticut Medicaid has no managed-care plans; a new rule
  types it commercial (ConnectiCare Medicare and exchange plans keep their types). Connecticut's
  colonoscopy "Medicaid" median of $5,657 came from these rows. The same rule types "Buckeye
  Commercial" (Centene's Ohio commercial product, listed in WVU files) commercial instead of
  Buckeye Health Plan Medicaid.
- `fact_rate` gains `fee_type`, `fee_type_inferred`, and `case_line`; `ref_code_gross` holds the
  thresholds. Queries use the stored `fee_type` instead of re-deriving it from billing class.
- File states are validated (`clean_state_sql()`). Trilliant's `hospital_state` sometimes holds a
  street token ("PO" from "PO Box", "NW"/"SE" from street quadrants), which created three bogus
  state units (NW, PO, SE) from five files with no CCN match. Only USPS codes are kept, else the
  code before the ZIP at the end of the address, else NULL.

### Changed (figure review)
- Add-on figures:
  - HPT rates are labelled a payment proxy, not claims or remittance data.
  - The three lines are now "displaced-case margin, add-on paid its expected share of the
    negotiated rate" (base), the same with the full negotiated rate (upper bound), and
    "accounting room cost per minute". The room cost is Childers 2018's direct-expense average,
    so its "(marginal)" description was wrong.
  - The model is unchanged: the displacement term already charges the displaced case's
    contribution margin.
  - The full-rate scenario is blanked where Medicare does not cover the add-on (58300 and IUD
    J-codes are OPPS E1; MA follows Medicare). This applies to the case A figures and the state,
    PSA, and by-state outputs.
  - The day-capacity figure is discrete: k = 0..n add-on cases in one fully booked room day, with
    each displaced primary case labelled.
  - Tornado bars carry plain-language labels with their tested ranges.
  - The u axis reads "probability the added minutes displace otherwise productive room time".
- PE ownership model:
  - The wild cluster restricted bootstrap (Webb weights, 9,999 draws, test-inversion CIs) replaces
    CRV1 intervals in the forest; CRV1 stays in the CSV. The fast cluster-sum implementation
    matches brute-force refits and sandwich CRV1 exactly.
  - Groups from fewer than 5 health systems are exploratory (point estimate, no interval): every
    strict-PE estimate (1-3 systems) and 43 of 93 estimates overall.
  - With the bootstrap, 4 of the 50 non-exploratory estimates are significant (12 with CRV1).
  - IUD insertion x Medicare Advantage is flagged as not a payment comparison and dropped from
    the plot.
  - Verified: the % axis is 100 x (exp(b) - 1) with limits exponentiated separately; strict and
    broad PE are separate models.
- Geographic figures:
  - States with fewer than 5 hospitals are suppressed on the maps (neutral hatched fill, no
    estimate); the ranking chart still shows them as hollow dots.
  - The MA map moves to the supplement (`supp_geo3`), joined by an MA state-ranking chart
    (`supp_geo4`) and a system-weighting scatter (`supp_geo5`).
  - System-weighting sensitivity (one value per health system per state): Spearman with the
    hospital-weighted state medians is 0.72 commercial, 0.81 Medicaid, 0.76 MA. Commercial p90/p10
    falls from 1.96 to 1.67 and state R2 from 0.20 to 0.14. The commercial-versus-MA contrast
    holds, but some state positions (WV, NC, VT, KS, GA, Connecticut MA) mostly reflect single
    large systems.

### Added
- `tools/`: the Trilliant download helpers, moved out of a session scratchpad so they can be run
  on any machine. `trilliant_download.sh` resumes and optionally fetches parallel 1 GiB byte
  ranges; the signed URL comes from `TRILLIANT_URL` and is never written to disk.
  `etag_verify.py` checks the zip against the S3 multipart ETag. `fast_unzip.py` extracts at disk
  speed with CRC checks and resume. `refresh_readme_figures.sh` copies the current figures into
  `docs/figures/`.
- `docs/trilliant_download.md` (getting the data onto a machine), `docs/appendix.md` (technical
  appendix: sources, extraction, crosswalk, every cleaning rule with its evidence, medians, the
  Medicare benchmark, known data issues, validation, reproducibility), `NEWS.md`
  (plain-language highlights), and `docs/cleanup_impact.md` (before-and-after impact of today's
  cleaning on the headline outputs).
- README: target-code table brought up to date (bariatric, 88305, 58120, 58558, 99213), data
  acquisition, a documentation index, and the main figures (the repository is private; the
  figures are aggregates of Trilliant-derived data).
- GitHub Actions (`.github/workflows/r-tests.yml`) runs the offline test suite with the DuckDB CLI
  on every pull request and push to `main`.
- `R/geo_figures.R`, `analysis/15_geographic_figures.R`: colonoscopy (45378) state maps of the
  commercial, Medicaid, and Medicare Advantage rate relative to Medicare, and a state ranking
  chart by Census region (2 x 2 panels, landscape) with commercial and Medicaid on each state's row
  and within-state interquartile ranges. The Medicare benchmark is each
  hospital's OPPS payment (Addendum B rate x (0.6 x FY 2026 IPPS wage index + 0.4); critical
  access hospitals get the state rural wage index), not hospital-listed Medicare rates, which are
  thin and noisy by state. Maps are drawn with `mysterymaps::mysterymaps_geographic_map()`;
  states with fewer than 5 hospitals are hatched. Result: MA is flat (national 1.00x; p90/p10 of
  state medians 1.10), commercial varies about 2x across states (national 2.30x) and Medicaid
  about 4.6x (national 0.78x); state explains 20% of the hospital-level variance in commercial
  price.
- CMS FY 2026 IPPS Tables 2-3 download with provenance (`download_ipps_wage_index()`).

### Effect on other outputs
- Payer-to-Medicare professional ratios for emb_colonoscopy: unchanged except commercial D&C
  (58120) 1.666 to 1.626 (66 hospitals, was 68).
- Add-on model: no conclusion changes direction, but EMB at colonoscopy (commercial) falls from
  +$149 to +$115 per add-on and its break-even from 20.9 to 16.3 added minutes (base 5), because the
  colonoscopy price rose and the EMB rate fell. IUD at bariatric surgery is unchanged (-$1,234
  commercial; negative for every payer). Full before-and-after table: `docs/cleanup_impact.md`,
  against a rebuild of the pre-cleanup code (6de7ea8) from the same inputs.
- Validation: 44 pass, 4 warn, 0 fail.

## 2026-09-13 (D&C and hysteroscopy codes; vendor-URL cross-linking corrected)

### Added
- CPT 58120 (D&C) and 58558 (hysteroscopy with sampling). The national extract is now 7,746,760 rows
  and the database 7,753,542 rates across 3,303 CCNs. Validation: 44 pass, 4 warn, 0 fail.
- `R/payer_ratios.R`, `analysis/14_emb_payer_ratios.R`: within-hospital payer-to-Medicare ratios by
  code and fee type, to replace emb_colonoscopy's provisional payer multipliers.

### Fixed
- `outpatient_concepts()` now includes `dc` and `hysteroscopy_sampling`, so explicitly inpatient
  rows for them stay out of state medians (found by the ownership module).
- Vendor-hosted reports were cross-linked to the wrong hospitals in builds before this one. 516
  facilities publish through `apps.para-hcfs.com/PTT/FinalLinks/Reports.aspx?dbName=...`, 317
  distinct URLs that collapse to 4 keys if the query string is dropped. The crosswalk used before
  the `normalize_url_key()` fix dropped it, so the tracker URL tier bridged other hospitals' files
  to about 300 CCNs. For example, Forrest City Medical Center (040019) showed a $564 colonoscopy
  price from another hospital's file; its own file has only 88305 among our codes. The rebuilt
  crosswalk links each facility to its own file. National medians barely moved (commercial 45378
  $2,078 to $2,070; MS-DRG 621 $21,064 to $21,145), but hospital- and state-level values for
  affected hospitals did.

## 2026-09-13 (national run, validation fixes, build 21x faster)

### Verified against the full Trilliant lake (snapshot 2026-07-21)
- The download was checked against the server's S3 multipart ETag
  (`da6d4a4ae4896ce5b33e8f86da87ab49-1520`): byte-for-byte identical.
- The extract gives 7,220,599 rows for the codebook from 4,923 distinct files covering
  7,916 facilities. Known answers reproduce exactly: Denver Health 45378 $1,289.13 and
  58100 $213.27; HCA Houston Healthcare Southeast 45378 $2,431 (305 rows), MS-DRG 742
  $4,429 (652 rows).
- Validation: 44 pass, 4 warn, 0 fail. Cross-source agreement is 98.5% within $0.01.
  Medicare facility medians are 0.97-1.04x CMS OPPS 2026. Payer-type agreement with
  Trilliant's labels is 93% adjudicated.

### Fixed
- Trilliant layout: payer rates come from `current_charge_details`, not
  `current_charges`, which has no payer rows; the join key is `internal_id` +
  `run_date` (`hospital_id` is 1 everywhere); file URL and content hash come from
  `lake.hospital_versions`; NPI and license come from `lake.hospital_identity`.
- Out of memory on the 16 GB Mac: the extract now runs in two stages. A streaming filter
  scan writes a staging file, and matching runs on that file. DuckDB runs at 5 GB,
  3 threads, spilling to the data drive.
- Shared files are read once, through one representative facility. The extract's final
  DISTINCT was removed: HCA lists MS-DRG 742 on 69 distinct charge lines, and collapsing
  them moved the hospital's pooled median from $4,429 to $4,786.
- State medians are now three-stage (payer/plan contract, then hospital, then state), so
  repeated charge lines cannot tilt a hospital.
- Bridge: one row per (file, CCN), CCNs restricted to the roster. The old duplicates
  repeated 2.6M rows in `v_hospital_rate`.
- 416,865 rates had no state. Files now take their facilities' state from the
  crosswalk, and blank strings become NULL.
- Literal JSON quotes are stripped from payer, plan, and description. Trilliant files get
  hospital name and NPI from the crosswalk.
- `normalize_url_key()` keeps query strings on script endpoints
  (`download.aspx?pi=...`) and drops them on data-file paths and signed URLs.
- Files held by both sources count once in the medians. They stay in the database so the
  cross-source check stays live.
- The headline uses the discounted-cash price for self-pay and adds MS-DRG 621 as the
  bariatric price; CPT-coded bariatric lines are partial.
- Medians exclude the 30 files where most rates exceed gross (unit errors). The list is
  saved to `output/median_excluded_file_ids.csv`.

### Performance
- Database build: about 35 minutes, now 97 seconds. The `dim_payer` join on two
  `IS NOT DISTINCT FROM` columns plus an `OR` ran as a nested-loop join
  (`BLOCKWISE_NL_JOIN`, 2,050 of 2,100 seconds). It now joins on a single `payer_key`,
  which DuckDB runs as a hash join.
- Trilliant extract: 55 minutes for the single lake scan (I/O bound). Re-matching with
  `HPT_REUSE_STAGE=true` takes 9 minutes.
- Lake unzip: macOS `unzip` managed 7 MB/s; a Python extractor with 16 MB buffers and a
  CRC check per member reached 40-80 MB/s.

### Known limitations
- Community Health Systems files list some codes on both a clinic line and an
  operating-room case line. Contract-level medians are robust to this; the thin
  `self_pay` payer-row type is not, so the headline uses the cash price.
- Coverage is thin in PR (7%), DC (20%), and MD (34%), and VA/DoD hospitals are exempt.

## 2026-09-12 (database, state medians, validation, add-on economics)

### Added
- `config/codebook.csv`: bariatric surgery (CPT 43644, 43645, 43770, 43775, 43842, 43843,
  43845, 43846, 43847; all active in RVU26C), MS-DRG 619-621, CPT 88305, and an `anchor`
  column (one reference code per concept for headline medians).
- `R/payer_type.R` + `config/payer_type_rules.csv`: ordered regex rules classifying
  payer/plan text into 10 insurance types. The same rules drive R and DuckDB SQL.
- `R/duckdb_store.R`, `analysis/09_build_database.R`: `hpt.duckdb` star schema. It uses
  ENUMs, integer keys, and a fact table sorted by (code_id, file_id), and is written in
  v1.4.0 storage so R duckdb 1.4.4 can read it.
- `R/state_medians.R`, `analysis/11_state_medians.R`: two-stage median per state x
  insurance type x code (within hospital, then across hospitals). Facility and
  professional fees are separate, cells under 3 hospitals are suppressed in the
  headline, and files flagged for rates above gross can be excluded.
- `R/validation.R`, `analysis/10_validate.R`: 32 spot checks, covering integrity, known
  answers, plausibility, payer-type agreement with Trilliant, cross-source agreement,
  the CMS OPPS 2026 benchmark, raw re-checks, and coverage.
- `R/addon_economics.R`, `config/addon_parameters.csv`, `analysis/12_addon_value.R`,
  `docs/addon_methods.md`: is an add-on (IUD at bariatric surgery; EMB at colonoscopy)
  worth the primary capacity it displaces? The model reports net value per add-on,
  break-even minutes and utilization, integer day capacity, a tornado, a PSA, and a
  payer/patient view. It reuses sourced parameters from emb_colonoscopy.

## 2026-09-12 (initial build)

### Added
- **Codebook** (`config/codebook.csv`): colonoscopy, EMB, IUD insertion, IUD devices,
  vaginal hysterectomy, LAVH, MS-DRG 742/743. Every CPT/HCPCS code was checked against
  CMS PFS RVU26C (July 2026) with `validate_codebook_against_pfs()`. 58293 is absent
  from that file and is flagged `active_2026 = FALSE`.
- **Code matching** (`R/codes.R`): a code counts only when its value and declared type
  agree. CDM, revenue codes, and APR/TRICARE DRGs never match. A missing type, or a
  generic "DRG", is kept with `type_verified = FALSE`.
- **Part A, Trilliant lake extract** (`R/trilliant.R`, `analysis/01`): one SQL pass
  through the DuckDB CLI (DuckLake needs DuckDB >= 1.5; the R package is 1.4.4). Splits
  lines carrying several target codes into one row per code and collapses facilities
  that share one MRF to one copy of each row. Column names were verified on live
  per-hospital databases; the lake schema is resolved at runtime.
- **Part B, CCN crosswalk** (`R/hospital_universe.R`, `R/tracker.R`, `R/ccn_match.R`,
  `analysis/02`): the CMS roster (5,419 CCNs), Hospital Enrollments (11,338 NPI-CCN
  pairs), AHRQ CHSP systems, and a pinned cms-hpt-tracker snapshot. Matching goes by
  MRF URL, then NPI, then name and address, with a conflict flag when URL and NPI
  disagree.
- **Part C, gap crawl** (`R/txt_discovery.R`, `R/domain_seeds.R`,
  `R/footer_discovery.R`, `R/mrf_download.R`, `R/mrf_probe.R`, `R/parse_csv.R`,
  `R/parse_json.R`, `analysis/03`-`07`):
  - `cms-hpt.txt` crawl with vendor-host snowballing;
  - "Price Transparency" footer fallback that honors robots.txt;
  - resumable MRF downloads;
  - CSV (v2/v3, tall/wide) and JSON (streamed through jq) parsers.
- **Part D** (`R/summaries.R`, `analysis/08`): per-CCN x code summaries and rate-pattern
  flags (identical rates across colonoscopy codes; DRG 742 equal to 743).
- `R/pipeline.R`: shared orchestration. MRFs are downloaded, parsed, stored, and
  deleted one at a time, so disk use is bounded by the largest file.

### Verified against live data
- Trilliant schema and prices: live read-only queries on Denver Health (45378 median
  negotiated $1,289, 58100 $213, 58300 $114, MS-DRG 742 $31,231) and HCA Houston
  Healthcare Southeast (45378 $2,431).
- NPI 1174576698 from the HCA Houston Southeast MRF header maps to CCN 450097.
- TXT crawl smoke test: 212 locations from 16 of 24 domains in 58 requests.
- Gap-extraction pilot: 20 random acute/CAH tracker MRFs gave 16 with prices, 3 genuine
  zeros (Mercy Logan County, Trustpoint, Genoa, each checked by hand), and 1 stale 404.
  That is 6,782 price rows. An earlier count of 54,944 was wrong: three files written
  while `sha256_file()` was briefly broken carried 2-character file ids, which
  multiplied and mixed their rows. The validation suite's `integrity_file_ids` check
  caught it. The files were re-extracted, and `extract_gap_mrfs()` now refuses to store
  malformed ids.

### Fixed during the pilot
- Mixed UTF-8/Windows-1252 files (Mass General, BHMC Conway, PVHMC): stray bytes are
  repaired on the way into DuckDB and counted; no rows are lost.
- A server with an incomplete TLS chain (McLaren Flint): certificate checks stay on. The
  download retries once over http:// and records that in a `note` column.
- `sha256_file()` now returns a plain string, not an openssl "hash" object.
- `hpt_perform_parallel()` interleaves requests by host, so one throttled host no
  longer stalls the queue.
- Stale mount point: a leftover folder at `/Volumes/MufflySamsung` pushes the real drive
  to `/Volumes/MufflySamsung 1`. `hpt_default_data_dir()` checks for a real mount point
  with `df`.

### Known limitations
- Codes that appear only in descriptions or CDM/LOCAL columns are missed by design. For
  example, Genoa's "Colonoscopy-procedurew/oanes" line carries no CPT code.
- Footer discovery reads static HTML only.
- JSON stream mode takes about 40 minutes for a 5 GB file. Memory mode (files under
  750 MB) uses about 6 times the file size in RAM.
- No free national license-to-CCN source exists, so the license tier is off unless you
  supply a table.
- Only 42% of MS-DRG rows had a verified type in the pilot; many hospitals label them
  just "DRG".
