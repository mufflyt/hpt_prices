# Childbirth prices and midwifery supply: methods

Three analyses, in the order they depend on each other:

| Script | Question | Status |
|---|---|---|
| `analysis/16_childbirth_prices.R` | What does a hospital birth cost commercial insurers and Medicaid, relative to Medicare, and how much more is a cesarean? | Descriptive results below |
| `analysis/17_midwifery_presence.R` | Are delivery prices or the cesarean premium different where more midwives practice? | Exploratory; null |
| `analysis/18_ntsv_midwife_supply.R` | Does midwife supply relate to the NTSV cesarean rate, and what facility price differential would that imply? | Design locked ([`childbirth_analytic_spec.md`](childbirth_analytic_spec.md)); code and preflight ready; waiting on the CDC WONDER exports |

Numbers come from the 2026-07-21 Trilliant snapshot (database built 2026-09-13 with per-diem
conversion). They are Trilliant-derived national summaries, so this file stays in the private
repository.

**Language.** The gap between a hospital's cesarean and vaginal prices is a **facility price
differential**, never "savings" or "value". It leaves out professional fees, downstream care,
repeat cesareans, and outcomes.

## 1. Codes and hospitals

- **Facility prices** are inpatient MS-DRG rates.
  - Cesarean DRGs are 783-788 and vaginal DRGs 796-798 and 805-807 (`config/codebook.csv`
    concepts `drg_cesarean` and `drg_vaginal_delivery`).
  - The anchors are the uncomplicated DRGs: **788** (cesarean without sterilization, without
    CC/MCC) and **807** (vaginal delivery without sterilization or D&C, without CC/MCC).
- **Physician fees** are the CPT obstetric codes 59400-59622 (concepts `vaginal_delivery_cpt` and
  `cesarean_cpt`). 59400 and 59510 are global codes (antepartum, delivery, and postpartum care).
- **Hospitals** must deliver babies:
  - The CMS Care Compare maternal health measure SM-7 must be "Yes" or "No"; "Not Applicable"
    means no labor and delivery unit.
  - Psychiatric hospitals and Rural Emergency Hospitals (no inpatient beds) are also excluded.
  - 1,602 hospitals have a delivery DRG price.
- **APR-DRG lines are off by default, and they reach a lot of hospitals.** Code-type gating never
  lets an APR-DRG match an MS-DRG (appendix B), so hospitals posting delivery prices only as
  APR-DRG were missing outright. The codebook carries APR-DRG 560-1 (vaginal) and 540-1
  (cesarean), the uncomplicated severity that MS-DRG 807 and 788 price, and
  `HPT_BIRTH_APR_DRG=true` lets them stand in for the MS-DRG anchor at a hospital that posts no
  MS-DRG delivery price (`add_apr_drg_delivery_prices()`). It never overwrites an MS-DRG price,
  every row it adds is labelled `price_source = "apr_drg"`, and it writes `birth_apr_*` files, so
  the MS-DRG build below is untouched. Turquoise Health maps APR-DRG 560 severity 1 the same way
  (see [`turquoise_pricepoints.md`](turquoise_pricepoints.md)). Section 4b has the measurement.

## 2. Hospital prices

- **Per-contract, then per-hospital medians.** Each hospital's price for a DRG and payer type is
  the median across its payer/plan contracts of each contract's median row. The row filter shared
  with every other analysis applies (`rate_row_filter_sql()`).
- **Per diem.** A per-diem rate prices one day of the stay. At load, a per-diem MS-DRG rate
  becomes a stay price: rate x the DRG's geometric mean length of stay (CMS FY 2026 IPPS Table 5;
  2.0 days for DRG 807, 2.9 for DRG 788).
- **Mislabeled per diem.** Following Turquoise Health's delivery method, a per-diem rate at or
  above 3 times Medicare's national per-day payment for the DRG (standard IPPS payment at wage
  index 1, divided by the length of stay) is treated as a stay price mislabeled per diem and not
  multiplied.
- **How many rows this touches.** 13,309 vaginal-DRG and 12,612 cesarean-DRG rows were
  converted, and 2,797 and 4,020 were kept as stay prices. The conversion appears in about a
  quarter of the files that list a delivery DRG (658 and 622 of about 2,690).
- **Where the prices live.** The listed rate stays in `negotiated_dollar`. `case_dollar` holds
  the stay price that medians use. Appendix E9 has the details.

## 3. The Medicare benchmark

Medicare pays for few births, so the benchmark is a common yardstick rather than a competing
payer. It is the standard FY 2026 IPPS payment each hospital would receive for the DRG
(`hospital_ipps_benchmark()` in `R/birth_prices.R`):

    operating = (labor x wage index + nonlabor) x DRG weight
    capital   = capital federal rate x wage index^0.6848 x DRG weight

The formula's inputs:
- **Standardized amounts** (Tables 1A and 1B): labor $4,456.72 and nonlabor $2,295.89 when the wage
  index exceeds 1 (66% labor share); $4,186.62 and $2,565.99 otherwise.
- **Capital federal rate** (Table 1D): $524.15.
- **DRG weights** (Table 5): 0.6742 for DRG 807 and 0.9588 for DRG 788.
- **Wage index:** the hospital's Table 2 value, or its state's rural index from Table 3 for 192
  hospitals missing from Table 2. The same wage index feeds the colonoscopy benchmark (appendix H).

It leaves out the indirect medical education, disproportionate share, uncompensated care, outlier,
and quality adjustments. The median benchmark is $4,876 for DRG 807 and $6,935 for DRG 788.
Hospital-listed traditional Medicare rates for the same DRGs run 1.18x (807, 551 hospitals) and
1.14x (788, 555 hospitals) the benchmark, consistent with the omitted add-ons.

## 4. Results (descriptive)

**National medians across hospitals** (hospital price, and hospital price / benchmark):

| DRG | Payer | Hospitals | Median price | Ratio to Medicare | IQR of ratio |
|---|---|---|---|---|---|
| 807 vaginal | Commercial | 1,483 | $8,584 | 1.72x | 1.33 to 2.20 |
| 807 vaginal | Medicaid | 728 | $5,396 | 1.08x | 0.74 to 1.59 |
| 807 vaginal | Medicare Advantage | 1,389 | $6,242 | 1.22x | 1.08 to 1.43 |
| 807 vaginal | Cash price | 424 | $8,547 | 1.71x | 1.24 to 2.30 |
| 788 cesarean | Commercial | 1,487 | $12,465 | 1.74x | 1.31 to 2.25 |
| 788 cesarean | Medicaid | 725 | $7,643 | 1.10x | 0.77 to 1.52 |
| 788 cesarean | Medicare Advantage | 1,392 | $8,489 | 1.17x | 1.06 to 1.34 |
| 788 cesarean | Cash price | 420 | $14,070 | 2.03x | 1.41 to 2.93 |

**Cesarean-vaginal facility price differential** (hospitals listing both DRGs for the payer type):

| Payer | Hospitals | Median 788 / 807 | Median differential | Cesarean priced higher |
|---|---|---|---|---|
| Commercial | 1,473 | 1.42 | $3,525 | 96% |
| Medicaid | 719 | 1.42 | $2,214 | 90% |
| Medicare Advantage | 1,383 | 1.37 | $2,193 | 95% |
| Cash price | 418 | 1.61 | $5,522 | 97% |

Medicare's own DRG weights imply 0.9588 / 0.6742 = 1.42. Most commercial and Medicaid contracts
reproduce that ratio, which suggests they are set as a multiple of DRG weights.

**By hospital group** (commercial DRG 788, ratio to Medicare; `birth_by_hospital_group.csv`):
- nonprofit 1.85x (1,036 hospitals), government 1.87x (202), for-profit 1.32x (249);
- in a health system 1.76x (1,363), independent 1.46x (124);
- CMS Birthing-Friendly 1.76x (1,350), not designated 1.51x (137).

These are descriptive. Hospital groups differ in state, size, and case mix.

**Physician fees** (national median across hospitals, facility-listed professional rates):
- 59400 global vaginal: commercial $3,565, Medicaid $2,152;
- 59510 global cesarean: commercial $3,865, Medicaid $2,377.

These rest on about 170-230 hospitals, because most hospital files do not list physician global
obstetric codes.

**Figures.**
- `birth1_vaginal_ranks` and `birth1_cesarean_ranks`: state ranking by Census region.
- `birth2_cesarean_premium`: the differential ratio by state.
- `birth3_vaginal_maps`: commercial and Medicaid maps. States with fewer than 5 hospitals are
  suppressed.

## 4b. What the APR-DRG fallback adds, and what it cannot be used for (2026-09-18 extract)

The 2026-07-21 lake carries **11,269 APR-DRG 540-1 rows across 1,138 files** and **10,989 APR-DRG
560-1 rows across 1,136 files**. **517 hospitals post a delivery price only as APR-DRG severity
1**, and **355 of those survive the labour-and-delivery filter** (CMS SM-7, no psychiatric
hospitals or Rural Emergency Hospitals) to enter the analysis. 355 is the coverage figure: the
other 162 would be dropped whatever grouper they used.

### The prices are not interchangeable

At hospitals that post BOTH code systems, the APR-DRG severity-1 price is about **half** the
MS-DRG price for the same delivery:

| Comparison (same hospital, same payer) | Hospitals | Median APR / MS-DRG | IQR |
|---|---|---|---|
| Vaginal, Medicaid (560-1 vs 807) | 356 | **0.45** | 0.28 to 0.85 |
| Vaginal, commercial | 345 | **0.52** | 0.27 to 0.89 |
| Cesarean, Medicaid (540-1 vs 788) | 364 | **0.54** | |
| Cesarean, commercial | 352 | **0.61** | |

This is not a methodology artefact. It holds within case-rate rows (Medicaid median $2,934 for
560-1 against $4,364 for 807) and the spread is wide, so no single calibration factor would fix
it. Whether APR-DRG severity 1 is simply a narrower, lower-acuity product than "MS-DRG without
CC/MCC", or hospitals post something closer to a base rate on those lines, is not settled here.

**So the fallback's price levels must not be quoted.** The build reports a Medicaid vaginal median
of $4,626 at 0.94x Medicare against $5,396 at 1.08x for MS-DRG only, and that fall mixes two
things that cannot be separated from these data: a different population of hospitals, and a code
system that prices lower at the same hospital. The earlier draft of this section read that 0.94x
as a coverage result. It is not one.

### What the fallback IS good for

- **Counting who is invisible.** 355 delivery hospitals have no MS-DRG delivery price at all, and
  the MS-DRG-only analysis silently omits them. Their Medicaid concentration matters even if their
  price levels are not comparable: the APR-only Medicaid rows sit in TX (98), FL (86), NY (76), CA
  (50), MN (50), WI (36), IL (34), OH (30), AZ (26) and MI (26), states widely reported to pay
  Medicaid inpatient claims by APR-DRG. This project has not verified any state's payment method
  against a primary source; that is the check that would settle the mechanism.
- **Testing the cesarean premium on a different sample.** The premium is a ratio taken WITHIN a
  hospital, so a level difference affecting both codes cancels. It is 1.42 on the MS-DRG build and
  1.42 with the fallback, across a Medicaid sample half again as large. That is a real robustness
  result and the strongest evidence yet that 1.42 is a contracting convention.

### Per-diem APR rows are dropped

The per-diem conversion multiplies a daily rate by the DRG's geometric mean length of stay, which
CMS publishes for MS-DRGs only. MS-DRG per-diem rows convert at 94.7%; APR-DRG rows converted at
0%, so a per-day amount was being compared against a stay price. `rate_row_filter_sql()` now drops
per-diem APR-DRG rows. It moved the Medicaid median by $5 (from $4,631 to $4,626), which is how
the audit established that per-diem rows were not what made the two code systems differ.

## 5. Midwifery presence around hospitals (analysis/17, exploratory)

- **Exposure.** Active AMCB-certified midwives (CNM and CM) are placed at the ZCTA internal point
  of their NPPES practice ZIP. The count covers midwives within 30 miles of the hospital, per
  1,000 NVSS births in counties whose center lies within 30 miles. The model uses tertiles
  (cut points 1.91 and 3.87) and log2(x + 0.5). Secondary exposures are a CABC-accredited birth
  center within 30 miles and the county's CNM-attended share of births.
- **Roster coverage.** The midwife roster is the national AMCB-NPI linkage freeze
  (`amcb_npi_linkage_FROZEN.csv`), read at the rows the withdrawn 40-state roster meant by
  "active primary linked": in the reconciled cohort, certification ACTIVE, and a midwifery
  rather than nursing taxonomy. That is 12,170 midwives covering all 50 states and DC, against
  11,093 over 40 states before (1,127 added, 50 dropped). Lapsed, retired and deceased certificants stay out; a supply
  measure counts who is practising now.

  The freeze is verified by content, not by name: `load_midwife_roster()` re-hashes it against
  the sha256 in the midwifery repository's tracked manifest and stops on a mismatch. That repo
  once described 11,920 midwives instead of the registered number because a stale file sat in
  `artifacts/` under the right name.

  **This replaced an exclusion, and it moved more than the excluded hospitals.** The old roster
  omitted AK, DC, DE, HI, ND, NJ, RI, SD, VT, WV and WY, so a hospital whose 30-mile area
  reached a ZIP in one of them had no exposure at all (`roster_uncovered_zctas()`) and 188 of
  1,539 hospitals dropped out. All 188 now have a count. But of the 1,127 added midwives only 805 are in
  those eleven states; the other 272 are spread across states the roster already covered (FL
  +28, CA +22, NY +20 the largest), so the exposure changes for 729 of the 1,351 hospitals that
  were never excluded. The median
  midwife count within 30 miles goes from 25 to 28. Results below are on the new roster; the
  earlier numbers are not comparable hospital for hospital.

  `roster_uncovered_zctas()` is still called and must now return nothing;
  `national_roster_coverage(strict = TRUE)` stops the run if a future input covers less ground,
  so the masking would come back on rather than silently counting real midwives as zero.
  Foreign practice addresses are excluded by postal code: one Rhineland-Palatinate address has a
  postal code that collides with a US ZCTA, and APO/FPO codes (AE, AP) have no ZCTA at all.
- **Model.** Log outcome ~ exposure + hospital type + system + ownership + log beds + metro +
  state fixed effects. Intervals come from the wild cluster restricted bootstrap by state
  (9,999 draws).
- **Results.**
  - The high tertile's commercial vaginal price is +3.2% relative to Medicare (-8.7% to +16.6%,
    p = 0.61; 1,251 hospitals). The unadjusted tertile medians are 1.51x, 1.71x, and 1.78x.
  - The cesarean premium is flat at 1.42 in every tertile.
  - Birth centers and the county CNM share show nothing.
- **Interpretation.** Prices are contracts, not utilization. A null here says nothing about
  whether midwives change how often cesareans happen, which is the question for analysis/18.

## 6. Midwife supply and NTSV cesareans (analysis/18)

The design is locked in [`childbirth_analytic_spec.md`](childbirth_analytic_spec.md). In brief:
- **Unit:** county of mother's residence. These are the counties CDC WONDER identifies, those of
  100,000+ residents. A state-of-residence model gives complete coverage.
- **Outcome:** the NTSV cesarean rate over 2022-2024.
- **Exposure:** midwives within 30 miles of the county's 2020 Census center of population, per
  1,000 births.
- **Model:** a births-weighted linear model in percentage points with prespecified composition
  covariates and state fixed effects. Intervals come from the wild cluster restricted bootstrap
  by state.
- **Checks:**
  - a placebo outcome (the 2016-2019 NTSV rate);
  - a negative-control outcome (the multiple-birth share);
  - radii of 15 and 60 miles;
  - a quasi-binomial logit.
- **Price step:** the implied facility price differential is arithmetic on the primary slope.
  Each payer's share of NTSV births is priced at the local DRG 788 minus 807 price.
- **Figures:**
  - `birth5_ntsv_county_map`: the NTSV cesarean rate by county of residence. Counties WONDER does
    not report are drawn grey, so the coverage limit is visible rather than implied.
  - `birth6_ntsv_supply_vs_rate`: midwife supply against the NTSV rate, one point per county sized
    by NTSV births. Its line is the **unadjusted** weighted fit and is labelled as such, with the
    adjusted within-state estimate printed beside it: the two can point in different directions,
    and a plot whose line quietly contradicts the number beside it is worse than either alone.

**Why exports by hand.**
- The NCHS public-use microdata has no geography.
- The WONDER API refuses sub-national natality.
- So the county and state tables are manual WONDER web exports, listed with exact file names in
  the spec and in `wonder_ntsv_exports()`.
- `analysis/18` stops and prints the query for any missing export. It records each export's
  sha256 and query date, and checks that its Notes block shows the NTSV filters.
- `tools/smoke_ntsv.R` runs the whole analysis on synthetic exports.

Suppressed WONDER cells (1-9 births) are never read as zero. Rates and shares are bounded, and a
value is set to missing when suppression could move it by more than 1 percentage point.

## 7. Caveats

- **The benchmark is not what Medicare pays a given hospital.** It omits the IME, DSH, outlier,
  and quality adjustments (section 3).
- **Critical access hospitals** are paid on cost by Medicare. Their benchmark uses the state rural
  wage index.
- **Per-diem thresholds.** The 3x rule decides whether a per-diem rate is multiplied. Rates just
  below the threshold may still be mislabeled stay prices.
- **APR-DRG-only hospitals are excluded** from the headline numbers unless the fallback is turned
  on (sections 1 and 4b). That exclusion is not neutral: it drops 518 hospitals, most of them
  Medicaid, and they price lower than the hospitals that remain.
- **Medicaid coverage is thinner** (about 725 hospitals, against about 1,485 for commercial).
  Several states' Medicaid programs pay by APR-DRG or fee schedules that hospitals do not post as
  MS-DRG rates.
- **Midwife roster.** Resolved: the national linkage freeze covers all 50 states and DC (section 5).
