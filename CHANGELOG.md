# Changelog

Grouped by date. There is no package version.

## 2026-09-19 (the NTSV result fails its own placebo and is withdrawn)

### Measured
- The ten CDC WONDER exports arrived and all ten pass `wonder_export_audit()`: 627 counties
  consistently, 51 states, the placebo export on 2016-2019, the negative control unfiltered.
  `analysis/18` ran on **578 counties**.
- **Primary: -1.23 pp per doubling of midwives per 1,000 births** (95% CI -2.57 to -0.07,
  p = 0.037), stable at 15 and 60 miles, under extended covariates, and in a quasi-binomial
  specification.
- **Placebo: -2.02 pp (p = 0.008), larger than the primary estimate.** Midwife supply measured
  today predicts the 2016-2019 NTSV rate more strongly than the 2022-2024 rate it is supposed to
  affect. A causal reading requires the contemporaneous association to be the stronger of the two;
  the ordering is reversed. County NTSV rates correlate at r = 0.74 across the two periods, so
  persistent county characteristics are abundant and the model is picking them up.
- Negative control (multiple-birth share) passed, p = 0.28. The failure is confounding by place
  specifically, not an artefact of weighting, clustering or the bootstrap.
- **A second, independent problem.** The primary model uses 337 of 578 counties because
  `share_hispanic` is missing for 236 of them: WONDER suppresses cells of 1 to 9 births and those
  are never read as zero, so adjusting for Hispanic share restricts the sample to larger, more
  diverse counties. The unadjusted model on all 578 is null (-0.76, p = 0.25).

### Withdrawn
- **No effect estimate and no implied facility price differential are reported.** The differential
  computed (roughly 7,900 fewer commercial and 4,400 fewer Medicaid cesareans a year at the
  interquartile contrast) but it is arithmetic on a slope that fails its own falsification test,
  and a dollar figure travels further from its caveats than a coefficient does.
- What is reported is the negative result: the association exists, fails falsification, and these
  data cannot distinguish an effect of midwife supply from the county characteristics that attract
  midwives. The descriptive rates stand: median county NTSV cesarean rate 26.1% against the
  Healthy People 2030 target of 23.6%.

### Documentation
- **`docs/appendix.md` section P**, the full audit: inputs, all ten models, why the placebo is
  decisive rather than merely inconvenient, the suppression-driven sample selection, what was
  withdrawn and why, where the verdict is recorded, and the three designs that could actually
  answer the question.
- `docs/childbirth_methods.md` section 6 carries the results table and the withdrawal; the status
  table and the caveats in both documents are updated.
- `check_ntsv_falsification()` records the verdict in `validation_report.md`, so a build that
  reinstated the headline would show a failing check.

### Fixed
- The exports guidance said TSV omits the Notes block. It does not; that claim was asserted from
  the XLS export without testing. All ten delivered exports were requested as TSV, carry the full
  Notes block, and match an independent XLS pull line for line.

## 2026-09-19 (the WONDER exports get a preflight)

### Added
- **`R/wonder_preflight.R`**: `wonder_export_audit()` checks every expected CDC WONDER export
  against the specification it is supposed to satisfy, reading each file's own Notes block rather
  than trusting the request form. It verifies the grouping variables, the years, the NTSV
  restrictions (present where required, absent from the all-births negative control), that the
  file parses, and that the geography count is plausible. It reports every problem at once
  instead of stopping at the first.
- **`tools/check_wonder_exports.R`**: run it the moment the exports land. Seconds rather than the
  twenty minutes a model fit takes, and it exits non-zero so it can gate a run. Writes
  `output/ntsv_wonder_audit.csv`.
- **Two validation checks**, so stage 18 is covered by the standard report like every other stage
  (category `ntsv`): `check_wonder_exports()` skips while the exports are absent, warns when some
  are missing but the present ones are consistent, and **fails when a present file is wrong**,
  because a mis-built export is worse than a missing one; and `check_ntsv_falsification()`, which
  fails if the placebo or negative-control model is significant.

### Why
The ten exports are built by hand in a web form, one dropdown at a time, and **a wrong one does
not look wrong**. Grouping by "Age of Mother 10" instead of "Age of Mother 9", or leaving the
placebo on 2022-2024, or picking only the 37-38 week category, all yield a well-formed file with
believable counts that would flow through the whole analysis and change the answer with nothing to
flag it. Stage 18 previously checked only that the NTSV filters appeared somewhere in the Notes,
and nothing at all checked the grouping or the years.

`check_ntsv_falsification()` exists for a different reason. The placebo and negative control are
the tests that can kill the headline result, and the temptation with a falsification test is to
explain it away afterwards. Putting the verdict in the validation report, beside every other
check, states it where it cannot be quietly dropped from a write-up.

### Changed
- `analysis/18` runs the audit before reading anything and stops on a mis-built export, with the
  same `HPT_WONDER_SKIP_FILTER_CHECK=true` escape hatch as before. Its provenance output now
  carries the row and geography counts and a `consistent_with_spec` column.
- `wonder_notes()` and the filter markers moved into `R/wonder_preflight.R` so the preflight and
  stage 18 share one definition and cannot drift. That drift is exactly what produced yesterday's
  bug, where the markers described a different wording from the one CDC writes.
- `tools/post_extract_refresh.sh` runs stage 18 when the preflight passes, and skips it without
  failing the refresh when the exports are not there yet. A failure in any stage now also exits
  non-zero, which it did not before: stage failures were printed before the later stages ran, so a
  late failure was reported and then forgotten.

## 2026-09-18 (the midwife roster goes national)

### Changed
- **`load_midwife_roster()` reads the national AMCB-NPI linkage freeze**
  (`amcb_npi_linkage_FROZEN.csv`) instead of `tracked_roster_active_primary_linked.csv`. It keeps
  the rows the withdrawn roster meant by "active primary linked": in the reconciled cohort,
  `status == "ACTIVE"`, and `npi_tax_class == "midwife"` rather than the nursing sensitivity arm.
  That is **12,170 midwives across all 50 states and DC**, against 11,093 over 40 states: 1,127
  added and 50 dropped. Lapsed (2,954), retired (774) and deceased (169) certificants stay out,
  so the full 17,028-member cohort is deliberately not used; a supply measure counts who is
  practising now.
- **The freeze is verified by content, not by name.** `load_midwife_roster()` re-hashes it against
  `artifact_sha256` in the midwifery repository's tracked manifest and stops on a mismatch. That
  repository once described 11,920 midwives instead of the registered number because a stale copy
  sat in `artifacts/` under the right name; the manifest is in git and the data is not, so this is
  the only way to tell the two apart.
- **Foreign and military addresses are excluded by postal code** (`us_postal_codes()`). One
  Rhineland-Palatinate practice address has a postal code that collides with a US ZCTA and was
  being placed in the United States; APO/FPO codes (AE 12, AP 8) have no ZCTA and dropped on the
  join anyway, but are now excluded so the count is honest. 22 rows in total.

### Fixed
- **The 40-state NA masking is gone.** `roster_uncovered_zctas()` returned the eleven jurisdictions
  the old roster omitted (AK, DC, DE, HI, ND, NJ, RI, SD, VT, WV, WY), and any catchment reaching
  one had its midwife count set to NA. On the national freeze it returns nothing: **188 of 1,539
  hospitals in `analysis/17` go from no exposure to a measured one** (1,351 to 1,539 usable).
- The check is kept rather than deleted, because it is what makes that claim checkable, and
  `national_roster_coverage(strict = TRUE)` now stops `analysis/17` and `analysis/18` if a future
  input covers less than all 50 states and DC. Deleting it would let a partial roster silently
  resume counting real midwives across a border as zero, which is the bug it was written for.

### Measured
- Recovering the 188 hospitals is not the whole effect. Of the 1,127 midwives added, **805 are in
  the eleven formerly-missing states and 272 are in states the roster already covered** (FL +28,
  CA +22, NY +20 the largest), so the exposure moved for **729 of the 1,351 hospitals that were
  never excluded**. Median midwives within 30 miles: 25 to 28. Tertile cut points moved from
  1.91/3.87 to 2.06/4.17. `analysis/17` stays null on every outcome.
- 12,170 roster rows locate to 12,023 ZCTA points; the 147 that do not are ZIPs with no ZCTA (PO
  boxes and newly issued ZIPs) and drop on the join, as before.

### Documentation
- `docs/childbirth_methods.md` section 5, `docs/childbirth_analytic_spec.md` (exposure, roster
  coverage, and amendment 6 marked superseded), `docs/appendix.md` section J (the limitation is
  marked resolved, leaving the NPPES-practice-ZIP caveat), README, and the `analysis/17` figure
  caption.

## 2026-09-18 (the APR-DRG fallback reaches 518 hospitals, and the two builds stop colliding)

### Measured
- The re-extract carries 11,269 APR-DRG 540-1 rows (1,138 files) and 10,989 560-1 rows (1,136
  files). **518 hospitals post a delivery price only as APR-DRG severity 1**, and **355 of them
  pass the labour-and-delivery filter** and reach the analysis; the analysis now reports both, the
  first being counted before that filter.
- **The two code systems do not price the same product.** At hospitals posting both, an APR-DRG
  severity-1 price is about half the MS-DRG price for the same delivery: median ratio 0.45
  (Medicaid vaginal), 0.52 (commercial vaginal), 0.54 and 0.61 for cesarean, IQR roughly 0.28 to
  0.89. It holds within case-rate rows, so it is not a methodology artefact, and the spread is too
  wide for a single calibration factor. The fallback build's lower medians therefore mix a
  different population of hospitals with a code system that prices lower at the same hospital, and
  its price levels are not quoted anywhere.
- The cesarean premium is 1.42 on both builds, across a Medicaid sample half again as large. A
  within-hospital ratio that lands in the same place on a different set of hospitals is evidence
  that 1.42 is a contracting convention rather than an artefact of coverage.

### Fixed
- `rate_row_filter_sql()` drops per-diem APR-DRG rows. The per-diem conversion multiplies by a
  DRG's geometric mean length of stay, which CMS publishes for MS-DRGs only: MS-DRG per-diem rows
  convert at 94.7% and APR-DRG rows at 0%, so a per-day amount was being compared against a stay
  price. Worth $5 on the Medicaid median, which is how the audit established that per-diem rows
  were not what makes the two code systems differ.
- `tools/post_extract_refresh.sh` ran validation second; `docs/appendix.md` section L says it runs
  last, because it compares the saved medians against the database. Running it before 11 rebuilt
  them produced a spurious "49,461 saved rows vs 49,773 recomputed" warning about the runbook's
  own order. Validation now runs last.
- The fallback run wrote the same filenames as the MS-DRG run, so whichever went last owned
  `output/`. An impact table then compared an MS-DRG "before" with an APR-DRG "after" and reported
  a 14% fall in the Medicaid delivery price that was really 347 extra hospitals. The fallback now
  writes `birth_apr_*` files and figures, the two builds sit side by side, and analysis 17 and 18
  read the unprefixed names so they always see the MS-DRG build rather than whatever ran last.
- `tools/post_extract_refresh.sh` no longer depends on stage order for that separation, and says
  where each build's outputs are.

### Rebuild
- 09 through 17 all ran clean on the new extract: 11,521,371 rates, 4,017 files, 3,368 CCNs.
- The CCN conflict exclusion and ZIP/city blocking moved the MS-DRG headline numbers by at most
  0.4%, and the Medicaid vaginal median not at all ($5,396 before and after).

## 2026-09-18 (thin ownership cells, and a provisional parameter that decides the answer)

### Changed
- `exploratory` now also flags an ownership group with fewer than `min_treated_hospitals()` (10)
  hospitals, not only one spanning fewer than 5 health systems. The cluster rule is about
  inference; it said nothing about how much evidence carries the price, so six estimates built on
  8 or 9 hospitals -- including a +108% Medicaid difference for 58100 -- were reported like any
  other row. The note now says which bar a group failed, since the two mean different things. One
  of the 93 rows the forest plot draws changes.
- The tornado figure marks each provisional parameter with a dagger and counts them in its
  caption, and `docs/addon_methods.md` calls the device paid share provisional in the same sentence
  that calls it the only parameter able to flip the sign. It swings net value by $2,109, four
  times the next parameter, and its range runs -$1,445 to +$665, so the headline holds at an
  assumed value with no published source behind it.

### Audited, no change needed
- Ownership reads both of its flags in the analysis and the figure, and of the 93 plotted rows, 86
  carry a bootstrap interval while the rest are exploratory by design: none plots a point whose
  interval is silently missing.
- All 54 add-on parameters carry a source, and the 20 without a defensible direct one were already
  flagged `provisional` in the configuration and the methods document.

## 2026-09-18 (a two-digit year dated a file to the year 26)

### Fixed
- `normalize_mrf_date()` compared the parsed year as TEXT against "1990", and "26" > "1990" is
  TRUE because "2" sorts after "1". On Linux, where `%Y` accepts a two-digit year, a hospital
  writing "1/2/26" got `last_updated_on = "26-01-02"`; macOS refused the two-digit year and fell
  through to `%y`, so the same file dated differently on the two platforms. The year is now
  compared as a number against 1990-2100.
- `%m/%d/%y` is tried only where the year really is two digits. Otherwise "1/2/1899", which fails
  the range check under `%m/%d/%Y`, had its "18" read by `%y` and became 2018.

Found by a test written the day before, which passed locally and failed in CI: the platforms
disagreed, which is what a date-parsing bug looks like from the outside.
## 2026-09-17 (conflicted CCN matches stop counting; name matches get a hard key)

### Fixed
- **A conflicted match no longer credits the file to that hospital.** `ccn_conflict` marks a file
  whose URL-derived CCN is not among the CCNs its NPI points to. The flag was recorded and never
  read, so 17 such files, covering 16 hospitals and 17,877 rate rows, fed the medians as if the
  evidence agreed. `v_hospital_rate` now joins the bridge only where the flag is false: the rates
  stay, counted as their own unit, and are no longer attributed to a disputed CCN. The bridge
  keeps the row and the flag, so the conflict is auditable rather than deleted. 14 of the 16
  hospitals have no other file and lose their CCN identity.

### Changed
- **The name tier blocks on a hard key before scoring.** State alone left every hospital in a
  large state competing on name similarity, and the tier accepts scores as low as 0.60: 114 files
  matched below 0.80, covering 94 hospitals, 50 of them with no other file, and 2.6% of all rate
  rows. `block_ccn_candidates()` now narrows same-state candidates to those sharing the facility's
  ZIP, or failing that its city. A candidate whose key is unknown is never dropped, since a
  missing ZIP cannot contradict one. `ccn_block_key` records which key was used.
- A match resting on the name alone -- no street address, nothing but the state agreeing -- must
  clear 0.75 rather than 0.60. A file carrying a street address is not penalised: a genuine match
  with a generic name scores 0.71 on an exact street match alone, and rejecting it would trade one
  error for another.
- ZIPs are read from the roster's `zip_code` or from the tail of a facility's free-text address,
  with a five-digit run that is not at the end treated as a street number, not a ZIP.

### Not done
Phone number would block better than city and is unavailable: the CMS roster carries one, an MRF
does not, so there is nothing to compare against.

## 2026-09-17 (figures for the NTSV result, ready before the data)

### Added
- `ntsv_county_map()`: the NTSV cesarean rate by county of residence, keyed by FIPS through
  `maps::county.fips` (mysterymaps draws states, not counties). Counties CDC WONDER does not
  report, which is most of them, are drawn in the missing-data grey so the coverage limit shows.
- `ntsv_supply_rate_plot()`: midwife supply against the NTSV rate, one point per county, area
  proportional to NTSV births. The line is the births-weighted BIVARIATE fit and says so; the
  adjusted within-state estimate is printed beside it. The two can point in opposite directions,
  because the model's work is mostly within states, and a plot whose line contradicts the number
  beside it is worse than either alone.
- `analysis/18` writes both as `birth5_ntsv_county_map` and `birth6_ntsv_supply_vs_rate`.
- `reference/census_cenpop/CenPop2020_Mean_CO.txt` is now downloaded into the data directory: it
  had only ever been fetched inside a temporary smoke-test directory, so the real run would have
  failed on it. With it, every analysis/18 input except the WONDER exports is present.

## 2026-09-17 (a lake scan that survives being interrupted)

### Added
- **Stage 1 of the Trilliant extract is resumable.** It reads `standard_charge_details` through
  the table's own parquet files (`ducklake_data_file`: 246 files, 67 GB, 7.7 billion rows) in
  batches of `HPT_STAGE_BATCH` files (default 20), writing one part per batch under
  `stage_parts/` and appending to `stage_parts/_manifest.csv` only after DuckDB closes the file.
  An interrupted scan resumes at the first unfinished batch; a part interrupted mid-write is
  rewritten, never half-read.
- Per-batch progress in the log: files done, target lines kept, minutes, and the share of the lake
  scanned. The single scan reported nothing until it finished.
- `trilliant_lake_data_files()` refuses to list files when reading them alone would be incomplete
  (delete files, inlined rows, or a file the metadata names but the disk lacks) and the extract
  falls back to the single scan.

### Why
An OOM kill lost 61% of a scan with nothing to resume from, and the next attempt ran for hours
with no way to tell how far it had got. A scan that cannot be interrupted safely is a scan that
costs an evening every time anything goes wrong.

### Measured, and NOT the cause
- The drive reads at 426 MB/s on a 10 Gb/s link, falling to 63 MB/s after hours of sustained
  reading (the enclosure appears to throttle).
- Per file, the scan costs 16-23 s whichever prefilter is used, so roughly 80 minutes of real work
  for the whole lake. A rewritten prefilter that compared raw spellings instead of normalizing
  looked 22x faster but was measuring the OS page cache; run fairly it was the same speed, and it
  silently dropped about 0.4% of matching rows. It was not kept.

## 2026-09-17 (find the data drive whatever number macOS mounts it under)

### Fixed
- `hpt_default_data_dir()` globbed the volume instead of checking a hardcoded
  `/Volumes/MufflySamsung` and `/Volumes/MufflySamsung 1`. macOS appends a number when a stale
  folder occupies the name, and the number moves: the drive was at `MufflySamsung 1` on
  2026-09-12 and at `MufflySamsung 3` on 2026-09-17, with `MufflySamsung`, ` 1` and ` 2` all stale
  empty folders on the boot disk. The pipeline reported "External drive 'MufflySamsung' is not
  mounted" while the drive was plugged in and holding the data.
- `hpt_volume_candidates()` returns every `/Volumes/MufflySamsung*` path, one already holding
  `hpt_prices` first, so a second empty copy cannot quietly become the destination. The `df`
  mount-point check is unchanged and still refuses a stale boot-disk folder, which is what keeps
  an 80 GB lake off the 14 GB boot volume. Tests cover both.

## 2026-09-17 (APR-DRG delivery codes, as an opt-in coverage sensitivity)

### Added
- **APR-DRG is a code family of its own** (`apr_drg`), alongside `procedure` and `ms_drg`:
  - `config/codebook.csv` carries APR-DRG 560-1 (vaginal) and 540-1 (cesarean), the severity-1
    (uncomplicated) cases that MS-DRG 807 and 788 price. Severities 2-4 have no anchor and are not
    collected.
  - `normalize_apr_drg_code()` and its SQL twin `sql_apr_drg_code()` fold every spelling of a
    base-plus-severity code ("560-1", "560.1", "5601", "560 SOI 1", "APR-DRG 540-1") into one
    canonical form. A four-digit run is read as base plus severity only when the last digit is
    1-4, so "5609" stays unmatched rather than being invented into a severity.
  - `apr_drg_code_types()` gates the family: an APR-DRG entry matches only a row whose declared
    type names the APR grouper. Untyped rows and the generic "DRG" never match, because an
    untyped three-digit code could be either grouper (APR-DRG 742 is not MS-DRG 742). This is the
    one family with no "unverified" state.
  - Both engines carry the rule: `code_type_fit()` in R and the extract's `CASE` in SQL, checked
    against each other on the same inputs in `test-codes.R`.
- **`add_apr_drg_delivery_prices()`** lets an APR-DRG severity-1 price stand in for the MS-DRG
  anchor at a hospital that posts no MS-DRG delivery price. It never overwrites an MS-DRG price,
  and labels every row `price_source` ("ms_drg" or "apr_drg").
- `analysis/16` reads the APR-DRG codes only under `HPT_BIRTH_APR_DRG=true` (off by default) and
  reports how many hospitals the fallback adds. Headline numbers stay MS-DRG only.

### Why
Hospitals in states whose Medicaid programs pay by APR-DRG post inpatient prices only as
APR-DRGs, so they had no delivery price here at all: a documented gap (appendix J) and the one
Turquoise Health closes by mapping APR-DRG 560 severity 1 to MS-DRG 807.

### Not yet measured
How many hospitals the fallback adds, and how their prices compare, needs a re-extract from the
Trilliant lake (`analysis/01`), which needs the data drive. The two groupers assign cases
differently and the Medicare benchmark stays the MS-DRG one, so this stays a sensitivity reported
apart from the headline until that measurement exists.

## 2026-09-14 (childbirth prices; per-diem DRG conversion; midwifery supply and the NTSV design)

### Added
- **Delivery codes** in `config/codebook.csv`, validated against the RVU26D fee schedule:
  - MS-DRGs 783-788 (`drg_cesarean`, anchor 788) and 796-798 and 805-807 (`drg_vaginal_delivery`,
    anchor 807);
  - CPT 59400-59622 (`vaginal_delivery_cpt`, `cesarean_cpt`).
  - The database grew from 8,301,406 to 11,499,113 rates, from 4,003 to 4,016 files, and from 3,362
    to 3,371 CCNs.
- **`R/birth_prices.R` and `analysis/16_childbirth_prices.R`: childbirth prices.**
  - Medicare benchmark: the FY 2026 IPPS standard payment per hospital (Tables 1A-1E, 2, 3, 5).
  - Hospital set: labor and delivery hospitals only (CMS SM-7; no psychiatric hospitals or Rural
    Emergency Hospitals).
  - Outputs: national, state, and hospital-group summaries; the within-hospital cesarean/vaginal
    price ratio; physician fees; a hospital-listed Medicare check.
  - Figures: `birth1`-`birth3`.
  - Results: commercial DRG 807 $8,584 (1.72x Medicare) and DRG 788 $12,465 (1.74x); Medicaid
    $5,396 (1.08x) and $7,643 (1.10x); the 788/807 ratio is 1.42 for both, 1,602 hospitals.
- **`R/midwifery_link.R` and `analysis/17_midwifery_presence.R`: midwifery presence** (exploratory).
  - Measures: AMCB-certified midwives, NVSS births, and CABC birth centers within 30 miles of each
    delivery hospital (Census ZCTA points).
  - Model: prices on those measures, with the wild cluster restricted bootstrap by state.
  - Result: null. The high tertile's commercial vaginal price is +3.2% (-8.7% to +16.6%); the
    premium is flat. Figure `birth4`.
- **`docs/childbirth_analytic_spec.md`: the locked design** of the NTSV cesarean analysis
  (approved 2026-09-14), with seven amendments made during implementation listed at its end.
- **`R/ntsv_county.R` and `analysis/18_ntsv_midwife_supply.R`**, implementing the spec:
  - Data: a CDC WONDER export registry and reader, NTSV rates, and county composition shares.
    Suppressed cells are bounded at 1-9 and never read as zero.
  - Exposure: supply at 2020 Census county centers of population.
  - Model: births-weighted linear, state fixed effects, wild cluster bootstrap. Sensitivity: a
    quasi-binomial logit with CR1 errors. Checks: placebo, negative-control, and state models.
  - Price step: the implied facility price differential by payer.
  - Safeguards: the script stops and prints the exact query for any missing export, and checks
    each export's Notes block for the NTSV filters. No CDC numbers are in the repository.
- `tools/smoke_ntsv.R` runs `analysis/18` end to end on synthetic WONDER exports in a temporary
  data folder. It was moved out of the working scratchpad.
- Docs:
  - `docs/childbirth_methods.md`.
  - `docs/turquoise_pricepoints.md`, from the scratchpad inventory of Turquoise Health's
    pricepoints repository. Its delivery replication data is not downloadable.
  - Appendix sections E9 and M.
  - Five childbirth figures in the README.
- Tests: `test-birth.R`, `test-midwifery.R`, and `test-ntsv.R` (50 expectations, including a
  check of the CR1 errors against `sandwich::vcovCL`).

### Changed
- **Per-diem MS-DRG rates become stay prices at load**: `case_dollar` = rate x the CMS Table 5
  geometric mean length of stay, marked `per_diem_converted`.
  - A rate at or above 3x Medicare's national per-day payment is taken as a mislabeled stay price
    (`per_diem_as_case`), following Turquoise Health.
  - Medians, payer ratios, and ownership prices use `case_dollar`. The new table `ref_drg_los`
    holds the length of stay and per-day payment.
  - Rows converted: vaginal 13,309, cesarean 12,612, DRG 742/743 5,422, DRG 619-621 6,207.
- **Effects of the rebuild on documented numbers:**
  - national commercial DRG 742 $24,361 to $25,133, and Medicaid $14,443 to $14,525;
  - DRG 621 Medicare Advantage $12,804 to $12,809;
  - the add-on model's DRG 620 variant -$1,247 to -$1,250;
  - one more hospital in several Medicaid cells (colonoscopy Medicaid ratio 0.778x to 0.781x;
    ownership estimates within 2 points).
  - Validation is unchanged (44 pass, 4 warn, 0 fail, 2 skip).
- `state_region_chart()` takes a custom label for its 1x line.
- `tools/export_public.sh` keeps `docs/childbirth_methods.md` and `docs/turquoise_pricepoints.md`
  out of the public copy (both quote Trilliant-derived numbers) and lists the spec in the public
  README.

### Fixed
- **Midwife roster coverage.** The NPI-linked roster the midwifery measures read covers 40 states.
  Hospitals and counties whose catchment reached AK, DC, DE, HI, ND, NJ, RI, SD, VT, WV, or WY had
  those states' midwives counted as zero. They now get a missing exposure
  (`roster_uncovered_zctas()`), which removes 189 of 1,546 hospitals from `analysis/17`. The
  high-tertile estimate moved from +2.7% to +3.2%; still null.
- `analysis/17`: the county total-cesarean block and `load_wonder_delivery_by_county()` are removed;
  the NTSV analysis supersedes them.

## 2026-09-13 (public code copy; tools from the working scratchpad)

### Fixed
- `config/paths.R`: `HPT_DATA_DIR` now bypasses the external-drive check. `Sys.getenv()` evaluates
  its `unset` argument, so `hpt_default_data_dir()` ran, and failed, on any machine without the
  drive even when `HPT_DATA_DIR` was set. Found by the first CI run on the public copy; the test in
  `test-codes.R` swaps in a drive check that always fails, and fails itself if the check runs.

### Changed
- CI runs on the public code copy (github.com/mufflyt/hpt_prices_public), which carries the same
  code and tests; Actions is turned off here. The README badge points there.
- `docs/appendix.md` covers the public-copy policy (section A), the private known-answer file
  (section K), and the test, CI, and publishing workflow (section L).

### Added
- `tests/testthat/fixtures/README.md`: where every fixture came from and which tool regenerates it.
- Tools moved out of the working scratchpad:
  - `tools/make_mrf_fixtures.py` regenerates the parser fixtures from the CMS v3.0.0 templates
    (pinned to CMSgov commit 33833d4c).
  - `tools/make_crosswalk_fixtures.R` regenerates the crosswalk fixtures from the real CMS, tracker,
    and AHRQ headers under `HPT_DATA_DIR/reference`.
  - Both reproduce the committed fixtures byte for byte.
  - `tools/make_pe_hospital_systems.R` records how `config/pe_hospital_systems.csv` was first built;
    the CSV remains the source of truth, and the script writes to a temp file by default.
  - `tools/smoke_discovery.R` is a live, rate-limited smoke test for `cms-hpt.txt` discovery,
    snowballing, and the footer fallback; all state goes to a temporary directory.
  - `tools/run_test_file.R` runs one test file with the suite's setup.
- The OPPS Addendum B test fixture no longer carries the AMA copyright line or CPT short
  descriptors (placeholders now). It keeps the preamble the parser must skip, a Windows-1252 byte,
  and the public CMS payment rates the tests check.

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
- Public code copy, github.com/mufflyt/hpt_prices_public, built by `tools/export_public.sh`. It
  keeps code, tests, config, tools, CI, and the download guide, and leaves out figures, the
  CHANGELOG/NEWS/appendix/methods docs, and `config/known_answers.csv`. The export refuses to write
  if a known-answer value or file hash appears anywhere in the tree. CI runs there, since this
  repository is private.
- To make the code publishable, data-derived numbers moved out of it:
  - The known per-hospital values are now `config/known_answers.csv`, kept only here; without it
    the known-answer check skips.
  - Code comments state each rule's evidence qualitatively and point to `docs/appendix.md` for the
    numbers.
  - Payer-rule notes drop lake row counts.
  - Test fixtures use synthetic values instead of ones matching real hospital rates.
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
