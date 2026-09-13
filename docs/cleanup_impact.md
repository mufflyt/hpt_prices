# Impact of the 2026-09-13 cleaning on the headline outputs

The line-type cleanup on branch `feat/line-cleanup-geo-figures` adds five rules: operating-room
case lines, office-procedure case rates, blank-billing-class fee type, the ConnectiCare and Buckeye
payer rules, and state validation. This page compares every headline output before and after.

## How it was measured

- **Before:** the pre-cleanup code (hpt_prices @ `6de7ea8`) rebuilt from the same inputs (the same
  Trilliant extract, own-crawl files, CCN crosswalk, and reference files) into a separate data folder.
- **After:** the current build.
- **Same exclusions:** both builds exclude the same 45 files (rates above gross, cross-source
  duplicates), so every difference comes from the new rules.
- **Same database size:** both builds hold 8,301,406 rates from 4,003 files covering 3,362 CCNs.
  The rules flag and reclassify rows; they delete none.

Reproduce with `tools/cleanup_impact.py <after HPT_DATA_DIR> <before HPT_DATA_DIR>` after building
the before outputs. That means a git worktree at the old commit, `HPT_DATA_DIR` pointing at a
folder that symlinks `prices/`, `crosswalk/`, and `reference/` and holds a copy of
`output/files_rates_above_gross.csv`, then `analysis/09`, `11`, `14`, and `12`.

## Results

| Output | Before | After | Change | Reason |
|---|---|---|---|---|
| 45378 commercial facility median (national) | $2,068 | $2,220 | +$152 (+7.4%) | blank-class professional fees removed from facility rows (hospitals 2,541 to 2,312) |
| 45378 Medicaid facility median | $707 | $753 | +$46 (+6.5%) | same (hospitals 1,546 to 1,397) |
| 45378 Medicare Advantage facility median | $940 | $954 | +$15 (+1.5%) | same; MA is paid at Medicare rates (hospitals 2,158 to 1,973) |
| 58300 IUD insertion commercial facility median | $551 | $417 | -$134 (-24.4%) | OR case lines and office-procedure case rates removed (hospitals 2,103 to 1,848) |
| 45378 Medicare facility median / OPPS rate ($950.10) | 0.976 | 1.008 | +0.032 | professional fees had pulled the facility median below OPPS |
| Commercial D&C (58120) payer-to-Medicare multiplier | 1.666 | 1.626 | -0.039 (-2.4%) | OR case lines removed (hospitals 68 to 66) |
| EMB at colonoscopy, commercial net value per add-on | $149 | $115 | -$34 (-23.1%) | higher colonoscopy price raises the displaced-case cost; lower EMB rate lowers add-on revenue |
| EMB at colonoscopy, commercial break-even added minutes | 20.9 | 16.3 | -4.5 | same |
| IUD at bariatric surgery (MS-DRG 621), commercial net value | -$1,234 | -$1,234 | +$0 (-0.0%) | IUD insertion rate cleaned; conclusion unchanged |
| IUD at bariatric surgery: payers with positive net value | 0 of 10 | 0 of 10 |  | negative for every payer before and after |
| Commercial 45378 state variation (p90/p10 of state medians, states with 5+ hospitals) | 2.69 | 2.10 | -0.58 | states 48 to 48 |
| Medicaid 45378 state variation (p90/p10 of state medians, states with 5+ hospitals) | 4.60 | 4.10 | -0.50 | states 40 to 39 |
| Medicare Advantage 45378 state variation (p90/p10 of state medians, states with 5+ hospitals) | 1.25 | 1.25 | -0.00 | states 47 to 47 |
| Rates flagged as operating-room case lines | 0 | 30,603 rows in 347 files |  | of 8,301,406 rates in 4,003 files; outpatient procedures only |
| Rates reclassified professional (blank billing class, professional-level gross) | 0 | 142,002 rows in 620 files |  | left out of both facility and professional fees |
| EMB/IUD case-rate and per-diem rates excluded | 0 | 35,877 rows in 978 files |  | package prices for a surgical case |
| Payer plans with a changed payer type |  | 17 plans (3,804 rates) |  | medicare to medicare_advantage; medicaid to commercial; other to commercial |
| Files with a corrected state |  | 31 |  | street tokens (PO, NW, SE) replaced by the USPS code from the address, or dropped |
| Files excluded from medians (rates above gross, cross-source duplicates) | 45 | 45 |  | same list in both builds, so it does not drive the differences |

National medians are three-stage facility medians (`output/state_insurance_medians.parquet`, state
= "US"). State variation is the 90th/10th percentile ratio of state medians, among the 50 states
and DC with at least 5 hospitals.

## Reading the table

- **The cleaning fixed identifiable contamination.**
  - Unlabeled physician fees had pulled facility medians down. Colonoscopy commercial rose 7% and
    Medicaid 6.5%, and the Medicare facility median moved from 0.976x to 1.008x the OPPS rate.
  - Mixed IUD products had pushed the IUD price up; it fell 24%.
  - A hospital drops out of a median only when every one of its rows for that code was flagged.
    Commercial colonoscopy lost 229 of 2,541 hospitals this way.
- **No conclusion changed direction.**
  - Adding an endometrial biopsy to a commercial colonoscopy is still worth it, but by less:
    $115 instead of $149 per add-on. The break-even is now 16.3 added minutes, still more than
    three times the 5-minute base case. Two things drove the change: a higher colonoscopy price
    makes a displaced colonoscopy more costly, and a lower EMB rate lowers the add-on's revenue.
  - IUD at bariatric surgery is unchanged to the dollar. The base case credits the IUD procedure
    with no payment when billed with the bariatric DRG, so its cleaned rate does not enter.
- **The state spread narrowed.** Commercial fell from 2.69 to 2.10 and Medicaid from 4.60 to 4.10.
  Some of the apparent geography was contamination: professional fees in some states' "facility"
  rows and misfiled payers in Connecticut. Medicare Advantage stayed flat (1.25).
- **For emb_colonoscopy**, only the commercial D&C multiplier moved (1.666 to 1.626). That shifted
  the commercial scenario by less than $10 per strategy (D&C $4,005 to $3,996, office $911 to
  $910, combined unchanged at $573); the ranking of strategies did not change.

## Reclassification checks

- **Payer types.** All 17 plans that changed type are ConnectiCare or Buckeye Commercial. Three
  ConnectiCare Medicare plans moved from traditional Medicare to Medicare Advantage, which is
  correct. One plan with a Medicaid payer name and a ConnectiCare contract name (15 rates in one
  file) is now commercial; see the appendix, section J.
- **States.** All 31 changed file states went from an invalid token (PO, NW, SE, EL, FT, ST, BH)
  or a blank to a USPS code read from the address, or from an invalid token to NULL. No file moved
  from one valid state to another. Only 5 of the 31 files lack a CCN match; matched files take
  their state from the CMS roster, so the change matters only for those 5.
