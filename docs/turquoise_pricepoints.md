# Turquoise Health "pricepoints": inventory and comparison with hpt_prices

Prepared 2026-09-13 from a read-only clone of github.com/turquoisehealth/pricepoints
(commit b9bd9b6, at ~/pricepoints); updated 2026-09-14 for the per-diem rule hpt_prices adopted.
It contains hpt_prices coverage counts derived from Trilliant data, so it stays in the private
repository.

## 1. What the repository is

Price Points is Turquoise Health's research publication (pricepoints.health). The repo holds
the replication code for its posts: Python ingest (SQL run against Turquoise's internal Trino
warehouse) and R/Quarto analysis. It is by Dan Snow, a Turquoise employee
(dan.snow@turquoise.health).

**Projects:**

| Folder | Post | Replication data |
|---|---|---|
| projects/2025_04_delivery_costs | How much does it cost to give birth in the United States? (2025-05-07) | Google Drive ZIP (id 1FKDVQFNHCt6-Y-teji-rgsLVDdre96AC); **not downloadable** |
| projects/2025_05_bsca_hoag | Orange County's big healthcare brawl (2025-05-30) | Google Drive ZIP; **not downloadable** |
| projects/2025_06_il_340b | Two 340B posts (2025-07-17, 2025-07-24) | Google Drive ZIP; **not downloadable** |
| projects/2025_07_blues | BlueCard underpayments (2025-09-11) | None ("very large ... harmful to Turquoise's business"); repo has only a 3.7 KB payer-ID list |
| projects/2025_05_rural_v_urban | Rural hospitals are paid less than urban hospitals (2025-11-03) | None (same reason); repo has county crosswalk inputs |
| projects/2025_11_cpw | Cost Plus Wellness | Google Drive ZIP; **requires Google sign-in**; repo has public CPW rate sheets |
| projects/2025_12_prop_tax | 340B and property taxes (2026-02-17) | None ("extremely large"; contact the author) |
| projects/2026_02_v2_tic | TiC 2.0 schema adoption | Queries only |
| analyses/2025_05_cld_coverage | Coverage calculator for billing codes | Code list only |

**Download results.**
- Three ZIPs (delivery, BSCA/Hoag, 340B) return Google Drive's "Sorry, the owner hasn't given you
  permission to download this file. Only the owner and editors can download this file."
- The CPW link redirects to a Google sign-in.
- So no replication dataset is publicly downloadable today, the delivery set included. The attempt
  is recorded in "/Volumes/MufflySamsung 1/turquoise/2025_04_delivery_costs/provenance.csv"; no data
  was retrieved.
- Getting the data would mean emailing Dan Snow or going through Community Tier.

## 2. License and data terms

- **Code:** MIT (LICENSE, "Copyright (c) Turquoise Health").
- **Data:** the README says "Code in this repository uses the MIT license. Datasets and other
  linked assets may use different licenses." No license file or data-use terms accompany the
  replication datasets.
- **Upstream licensing:** the delivery extract embeds Policy Reporter covered-lives data, a
  commercial subscription, which is likely why sharing is restricted.
- **Community Tier** is governed by Turquoise's Terms of Use (linked in the application page
  footer, not reviewed here).
- **Recommendation:** treat any Turquoise data as non-redistributable until written terms say
  otherwise, the same way we treat Trilliant (no derived rates in git or the public copy).

## 3. Community Tier access

README, verbatim:

> 2. Request (free) researcher access to the Turquoise backend through the Community Tier. This
> provides nearly full access to the main Turquoise Health rates tables, but limited customer
> support.

The README lists three options, least to most access:
1. Request research datasets at turquoise.health/researchers, "a limited subset of hospital and
   payer negotiated rate data".
2. Community Tier.
3. Paid access through sales, which is the only option that includes historical rates.

**How to apply.** turquoise.health/researchers links to https://hey.turquoise.health/community-waitlist.
- Headline: "Apply to join our no-cost Community Tier".
- Audience: "community health providers, local employers, researchers, and select innovators".
- The page says access "works best for small teams, self-service workflows, and focus on a single
  region".
- A separate track offers "engineer-friendly, broader access" to "small startups and research
  organizations".
- The form fields were not visible to the fetcher. General contact: info@turquoise.health.

**Not yet known:**
- whether Community Tier exposes the Trino tables the SQL uses: glue.hospital_data.hospital_rates,
  hospital_provider, redshift.reference.provider_demographics, ref_cms_msdrg,
  hive.labps.quality_cms_hospital_ratings_v0;
- whether it exposes NPI, CCN, or health-system tables;
- whether it includes historical vintages.

These have to be checked after access is granted. Do not assume the internal tables are exposed.

## 4. The delivery dataset (from the ingest SQL and analysis, since the data could not be downloaded)

**Scope** (README and queries/rates.sql):
- 645,393 negotiated rates, as of 2025-05-06; 2,889 providers.
- Providers: short-term acute and critical access hospitals only (children's hospitals excluded).
- Commercial payer class, inpatient setting only. Turquoise-flagged outliers removed.
- 12 delivery MS-DRGs (783-788, 796-798, 805-807).
- APR-DRG 560-1 maps to MS-DRG 807 and 560-4 to 805. APR severities 2-3 and cesarean APR-DRG 540
  are not mapped.
- Revenue-code-only hospitals (a generic OB room rate) are excluded.

**Columns and keys:**
- Code and rate: billing_code, billing_code_type, revenue_code, billing_class, setting,
  final_rate_amount and final_rate_type (after their transforms), negotiated_dollar,
  negotiated_percentage, gross_charge, discounted_cash_rate, estimated_allowed_amount,
  min_standard_charge, max_standard_charge, contract_methodology.
- Medicare: **medicare_rate** (a Medicare rate on every row), medicare_pricing_type.
- Payer and plan: plan_name, payer_id, payer_name, parent_payer_name, payer_product_network,
  payer_class_id and payer_class_name.
- Provider: provider_name, **provider_npi** (required non-null), **provider_id** (Turquoise id),
  hospital_type, **health_system_name**, **health_system_id**.
- Geography: state, county, and CBSA FIPS; ZCTA; total_beds; lat and lon; CMS star rating.
- **There is no CCN column.** Linking goes through provider_npi.

**Cleaning decisions:**

| Decision | Turquoise | hpt_prices today |
|---|---|---|
| Per diem | Multiplied by CMS geometric mean LOS for the DRG. Kept only if the per-diem amount is at least 0.5x and below 3x the Medicare "day rate" (Medicare rate / GLOS); above 3x it is treated as a mislabeled case rate and taken as-is | Adopted 2026-09-13 for every MS-DRG: rate x Table 5 GMLOS, and at or above 3x Medicare's national per-day payment the rate is taken as a stay price (`per_diem_case_multiple()`). No 0.5x floor |
| Percent of total billed charges | percentage x gross charge (percent capped at 110; decimals and whole numbers normalized); negotiated dollar used when percent or gross is missing; dropped if gross > $500K | negotiated_dollar as posted |
| Estimated allowed amount | Fallback for "other" methodology (0 to $10M) | Not used |
| Rate-type priority | case rate, then % of charges, then per diem, then estimated allowed, then fee schedule, then other | All methodologies pooled |
| Outlier bounds | $3K to $500K; 0.6x to 10x Medicare; rates above 1.1x gross dropped when gross is plausible | Plausibility flag ($1 to $2M, 9-filled) |
| Plans | Prefer PPO/HMO medians within a payer; drop plan names containing "exchange" or "indemnity"; drop "other"-method plans naming Medicare, Medicaid, or Tricare | Regex payer typing; all plans counted |
| Weighting | Payer: weighted median by state covered lives (Policy Reporter). Provider: median across providers weighted by bed count | Unweighted three-stage median (contract, then hospital, then state) |
| Revenue codes | Kept only with an MS-DRG, inpatient revenue codes (1xx/2xx), and codes seen more than 10 times | Not used for DRGs |

**Against hpt_prices** (commercial DRG 807, 2026-07-21 snapshot; `docs/childbirth_methods.md`):
our national median across hospitals is $8,584 (each hospital counts once; no bed or covered-lives
weights) against their "right around $10K", and our within-hospital cesarean/vaginal ratio is 1.42
against their "about 50%" more.

**Headline results** (commercial only, from the published post):
- An uncomplicated vaginal delivery (MS-DRG 807) costs "right around $10K" nationally; the range
  runs from about $5K (rural Tennessee) to about $70K (a complicated C-section in the Hamptons).
- "C-sections ... are generally about 50% more expensive than vaginal deliveries."
- Urban counties are "nearly 50% higher" than rural.
- New York and San Francisco run about 60% above the national median.
- The standard deviation for MS-DRG 807 is about $4.3K; for MS-DRG 786 it is about $13K.
- No Medicaid or traditional Medicare prices are analyzed. Medicare appears only as a cleaning
  bound.

## 5. Coverage against our hospital universe

Turquoise's hospital list is not available, since the replication data is locked, so overlap
cannot be computed hospital by hospital. What can be compared:

| | Hospitals | Notes |
|---|---|---|
| Our roster, short-term acute + CAH | 4,489 | CMS Hospital General Information |
| Ours: at least one delivery MS-DRG | 2,232 | CCNs from the 2026-07-21 Trilliant extract via facility_ccn.parquet (unambiguous matches); 318 of them CAHs |
| Ours: commercial inpatient delivery DRG | 2,179 | Trilliant's payer_type, setting not outpatient |
| Turquoise delivery sample | 2,889 providers | Short-term acute + CAH, commercial inpatient, May 2025 |
| Overlap / only ours / only Turquoise | Not computable | Needs their provider_npi list |
| NPI match feasibility | 2,224 of 2,232 (99.6%) | Our CCNs with at least one NPI in npi_ccn_crosswalk.parquet, so a provider_npi join should work |
| CCN match | Via NPI only | Turquoise carries no CCN |
| Health-system enrichment | Theirs: health_system_name and id on every row. Ours: AHRQ CHSP system on 1,990 of 2,232 (89%) | Theirs could fill the 11% gap |

**Why their count is higher.** They count Turquoise providers, which may be NPI- or location-level,
not CCN. They also map APR-DRG 560-1/560-4, which covers APR-only states such as New York and
Maryland; our code-type gating drops APR-DRG. And they may have parsed more files. The APR-DRG gap
is worth fixing on our side too: map APR-DRG 560 (vaginal) and 540 (cesarean) severity 1 to 807 and
788.

## 6. Comparison plan once data or access exists (not run)

With provider-level delivery rates (from the replication ZIP if the author shares it, or rates.sql
through Community Tier):

1. **Link.** provider_npi to our npi_ccn_crosswalk.parquet to get the CCN (99.6% of our delivery
   CCNs have an NPI). Keep one-to-many NPI-CCN cases flagged. Fall back to name, state, and ZIP
   against hospital_universe.csv and report the match rate.
2. **Per-hospital commercial price for DRG 807 and 788.**
   - Theirs: final_rate_amount collapsed as in their analysis.qmd (PPO/HMO preference, then the
     covered-lives weighted median).
   - Ours: v_hospital_rate unit medians (contract median, then hospital median) from the rebuilt
     hpt.duckdb.
   - Report the Spearman correlation, the median ratio theirs/ours, and the share within ±10%.
3. **Isolate method from data.** Recompute ours with their transforms (per-diem x GLOS within the
   0.5x-3x Medicare day-rate window; percent-of-charges x gross; $3K-$500K and 0.6x-10x Medicare
   bounds) to separate method differences from data differences.
4. **Cesarean premium.** Within-hospital 788/807 ratio in both datasets; they report about 1.5x.
5. **State medians.** Ours hospital-weighted vs theirs bed-weighted (hos_beds is in our roster, so
   we can also bed-weight ours).
6. **Medicare benchmark check.** Their per-row medicare_rate against our IPPS benchmark (standard
   federal payment at the hospital's wage index) for the same CCN and DRG. Expect theirs to be
   higher at teaching and DSH hospitals if it includes add-ons.
7. **Health systems.** Attach their health_system_id to fill our AHRQ gaps, then compare
   system-level price dispersion.

## 7. Bottom line

- **Methods: useful now.** Their per-diem, percent-of-charges, and outlier logic is a documented,
  defensible reference for our childbirth cleaning. Their APR-DRG crosswalk points to a coverage
  gap in ours.
- **Data: not available without contact.** Every replication ZIP is locked. Paths: email the
  author, or apply for Community Tier (hey.turquoise.health/community-waitlist).
- **Redistribution:** treat anything obtained as non-redistributable until terms are confirmed.
- **Not claims data:** it can't answer clinician-level volume or practice questions, but it can
  supply an independent hospital price layer and health-system IDs keyed by NPI.
