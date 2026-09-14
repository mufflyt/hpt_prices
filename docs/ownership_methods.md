# Private-equity ownership and negotiated hospital prices

Question: do private-equity (PE) owned hospitals post higher negotiated prices than
other hospitals for the same procedure, in the same state, for the same payer type?

Code: `R/ownership.R`, `analysis/13_ownership_prices.R`, `tests/testthat/test-ownership.R`,
and the sourced system list `config/pe_hospital_systems.csv`. Outputs go to
`HPT_DATA_DIR/output/` (listed at the end).

**Short answer.** PE here means hospitals whose system is controlled by a PE fund as of
July 2026. That is almost entirely Lifepoint Health and ScionHealth, both owned by Apollo
funds. Adjusted for state and hospital covariates, these hospitals post higher commercial
prices than nonprofit hospitals for office-type gynecologic and endoscopic procedures:
- colonoscopy (45378): +28%;
- endometrial biopsy (58100): +54%;
- IUD insertion (58300): +149%;
- hysteroscopy (58558): +14%.

They post about the same price for D&C (58120, -3%), and lower prices for inpatient
bariatric surgery (MS-DRG 621 -22%, sleeve 43775 -48%).

Strict PE rests on 2 or 3 health systems in every commercial cell, so no interval is
valid: these are exploratory point estimates that describe Apollo's hospitals, not PE in
general. Under the broad definition (4 to 7 systems), only commercial sleeve gastrectomy
is lower by the wild cluster bootstrap (-53%, p=0.01).
Hospitals held by creditor or distressed-debt funds (Quorum, Pipeline), which CMS's own
PE flag picks up, are a separate group and have too few prices to estimate.

## Data sources

| Source | Release / date | Use |
|---|---|---|
| `config/pe_hospital_systems.csv` (this project) | verified 2026-09-13 against sources dated 2015 to 2026-08 | PE systems, owners, dates, status as of 2026-07, citations |
| CMS Hospital All Owners (data.cms.gov) | "Hospital All Owners : 2026-08-01", modified 2026-08-19, `Hospital_All_Owners_2026.07.31.csv` (146,859 rows, 9,161 enrollments), sha256 `f5acfff543cda1236b343a8be6c42fd608865f4e389c28bdef8de7bd815b251f` | current owners by enrollment; CMS PE flag |
| CMS Hospital Enrollments | "Hospital Enrollments : 2026-08-01", `Hospital_Enrollments_2026.07.31.csv` | ENROLLMENT ID to CCN |
| CMS Hospital General Information (roster, `dim_hospital`) | downloaded 2026-09-12 | hospital type, roster ownership |
| AHRQ Compendium of US Health Systems, 2023 hospital linkage | 2023 | health system (cluster), beds |
| Kim et al. (2026) PE hospital deal list | GitHub `sungilkim94/Kim-PE-Data` commit `d1796fd`, downloaded 2026-09-13 to `reference/kim_pe_deals/` with provenance | cross-check only |
| `hpt.duckdb` | build of 2026-09-13 with per-diem DRG conversion (after the fee-type, case-line, and file-state validation fixes): 11,499,113 rates, 4,016 files, 3,371 CCNs | negotiated rates |

### Public PE-hospital datasets checked

- **PESP Private Equity Hospital Tracker.** Private Equity Stakeholder Project, 2026
  update published 2026-07-20, based on CMS data from December 2025: about 447 PE-owned
  hospitals, keyed by CCN.
  - It lives in an Airtable shared view
    (`https://airtable.com/appd2resSxUkpguFP/shrojR480lmH8vKpu/tbl058jjL6qNMqzkM`), and a
    data dictionary is at `https://pestakeholder.org/hospital-tracker-data-dictionary/`.
  - The site says "All content (c) 2026 Private Equity Stakeholder Project PESP. All rights
    reserved." It has no data license and no download link, so it was **not scraped or
    downloaded**.
  - Its method counts growth equity, joint ventures, family offices (Equity Group
    Investments for Ardent; Mitchell Family Office) and creditor owners (GoldenTree and
    Davidson Kempner for Quorum) as PE. It lists Apollo (Lifepoint, ScionHealth, about 200
    locations), One Equity Partners (Ernest, 35), EGI (Ardent, 28), Webster (Oceans and
    Haven, 28), Bain (Surgery Partners, 18), Stanton Road (Reunion, 14), Mitchell Family
    Office (12), Patient Square (Summit, 11), Blue Wolf/Leavitt/Peloton (13), WCAS
    (Emerus, 9), and Enhanced Healthcare Partners (NeuroPsychiatric, 6).
  - For a paper, ask PESP (contact: Eileen O'Grady) for the file and permission. This
    list is built independently from primary sources.
- **Kim et al. (2026), "A Practitioner's Guide to Using Data on Private Equity Hospital
  Acquisitions", Health Affairs Scholar (doi:10.1093/haschl/qxag071).**
  - What it is: a deal-level list of 723 hospital-deal rows (559 short-term acute
    hospitals, deals from 2000 to 2024) with CCN, deal type, announcement, closing and exit
    dates, and source links.
  - Terms: public on GitHub, with no license file. The README says the list is "provided
    as a public good" and asks users to cite the paper.
  - Limits: it names no PE sponsor, and many rows have no exit recorded. Of its 254
    hospitals without an exit, 67 are in our list. The rest are mostly deals Kim et al.
    code but our list does not count as PE ownership in July 2026: the 2018 PIPE in public
    Community Health Systems (107), Quorum hospitals that were sold before or after its
    2020 bankruptcy (24), a 2017 Baylor Scott & White growth-equity row (16), and Steward
    (14, bankrupt in 2024).
  - Use here: a cross-check, not a source of current status.
- **Lown Institute hospital ownership dataset** (2020-2025, CCN-keyed, updated
  2026-08-20). It is behind a form, limited to "personal and academic noncommercial
  purposes", and has no PE field. Not used.
- **CMS Hospital All Owners PE flag.** Public domain, used below. It marks only 3 roster
  hospitals (see "What the CMS flag contains").

## The PE system list (`config/pe_hospital_systems.csv`)

Each row is one hospital system: owner, owner type, classification as of 2026-07-31,
acquisition date, status, an owner-name regex for Hospital All Owners, hand include and
exclude CCN lists, and one or two citable sources with a verbatim quote. Every cited
page was fetched and its quote read during research, and the key facts behind the classification were re-checked by hand on
2026-09-13: the Lifepoint 8-K, the Ardent and Surgery Partners proxies, the Quorum
reports, the WCAS page, and the OEP page.

Classification:
- **strict**: a PE fund controls the system as of July 2026.
- **ambiguous**, with a reason:
  - `family_office`: Ardent (EGI-AM 54.0% of a public company) and Mitchell Family Office.
  - `public_pe_minority`: Surgery Partners (Bain 38.2%).
  - `growth_equity_jv`: Legent (General Atlantic and HSS).
  - `vc_operating_company`: Summa (HATCo / General Catalyst).
  - `undisclosed_stake` or `minority_or_advisory`: NeuroPsychiatric Hospitals; Reunion.
  - `creditor`: Quorum, Pipeline, and other hospitals where GoldenTree or Davidson Kempner
    distressed funds hold 5% or more.
- **exclude**: not PE owned in July 2026 (kept in the file so the decision is visible).

| System | Owner (as of 2026-07) | Class | Acquired | CCNs (roster) | Acute/CAH | Priced | Key source |
|---|---|---|---|---|---|---|---|
| Lifepoint Health | Apollo funds | strict | 2018-11-16 | 128 (77) | 56 | 35 | LifePoint 8-K Ex. 99.1, SEC, 2018-11-16; PESP 2026-08-21 |
| ScionHealth | Apollo funds | strict | 2021-12-23 | 79 (13) | 13 | 7 | Lifepoint release 2021-12-23; PESP 2026-08-21 |
| Ernest Health | One Equity Partners | strict | 2018-10 | 39 (0) | 0 | 0 | MPT 8-K, SEC, 2018-11-01; OEP portfolio "Current" |
| Oceans Healthcare (+ Haven) | Webster Equity Partners | strict | 2022-02-01 | 30 (30) | 0 | 0 | Comvest release 2025-03-05 |
| Summit BHC | Patient Square Capital | strict | 2021-11-24 | 11 (11) | 0 | 0 | Patient Square release 2021-11-24 |
| ClearSky Health | Blue Wolf, Peloton, Leavitt | strict | 2019-04 | 14 (0) | 0 | 0 | Peloton release 2019; Leavitt "Active" |
| Emerus | Welsh Carson XII | strict (JV hospitals) | 2015-09 | 9 (8) | 8 | 0 | WCAS profile "Current" |
| OrthoNebraska | InTandem Capital | strict (provisional) | 2023-08-02 | 1 (1) | 1 | 1 | InTandem release 2023-08-02 |
| NeuroPsychiatric Hospitals | Enhanced Healthcare Partners | ambiguous: undisclosed stake | 2020-09-30 | 8 (8) | 0 | 0 | EHP release 2020-09-30 |
| Ardent Health | EGI-AM 54.0% (public) | ambiguous: family office | 2015-08-04 | 29 (26) | 26 | 18 | Ardent DEF 14A, SEC, 2026-04-08 |
| Surgery Partners | Bain Capital 38.2% (public) | ambiguous: public, PE minority | 2017-08-31 | 17 (17) | 17 | 14 | SGRY DEF 14A, SEC, 2026-04-23 |
| Legent Health | General Atlantic + HSS JV | ambiguous: growth equity JV | 2025-10 | 4 (4) | 4 | 3 | GA release 2025-10-15; Legent 2026-02-03 |
| Perimeter / American Health Partners | Mitchell Family Office | ambiguous: family office | 2021-04-14 | 12 (12) | 0 | 0 | AHP 2021-04-14 |
| Summa Health | HATCo (General Catalyst) | ambiguous: VC operating company | 2025-10 | 1 (1) | 1 | 1 | Ohio AG 2025-06-18 |
| Reunion Rehabilitation | Stanton Road (advisory) | ambiguous: minority | 2021 | 16 (0) | 0 | 0 | SRC portfolio; Ernest deal 2026-05-27 |
| Quorum Health | GoldenTree (majority), Davidson Kempner | ambiguous: creditor | 2020-07-07 | 12 (12) | 12 | 1 | Healthcare Dive 2026-05-22 |
| Pipeline Health | DK / Deerfield / Stanton Road (post-2023 holders unverified) | ambiguous: creditor | 2023-01-13 | 4 (4) | 4 | 4 | Bankruptcy Doc. 216, 2022-10-20 |
| Other distressed-fund holdings | GoldenTree, Davidson Kempner | ambiguous: creditor | | 16 (16) | 16 | 5 | CMS All Owners; EU Law Live 2020-06-01 |
| Steward | none (Cerberus exited 2020; bankrupt 2024) | exclude | | | | | Cerberus 2024-09-19 |
| Prospect Medical | founders (Leonard Green exited about 2021; Chapter 11 2025) | exclude | | | | | INET WP 189; WHYY 2025-04-21 |
| Healthcare Systems of America, HCA, CarePoint, CORE Institute, Central Louisiana Surgical | not PE in 2026-07 | exclude | | | | | see file |

"Priced" counts acute and critical-access hospitals with at least one price in the
model sample. Dates in the file give the exact source for each row.

Status notes (all dated and sourced in the file):
- Lifepoint took 8 community hospitals from ScionHealth on 2026-06-02, so both stay
  under Apollo.
- Quorum sold Scenic Mountain (450653) to Shannon Health on 2026-04-01, so it is
  excluded. Alta Vista (321312) is still in the CMS file but not on quorumhealth.com;
  it is kept.
- Quorum's move to nonprofit status is expected in fall 2026, after the reference date.
- Ernest's purchase of Reunion was signed 2026-05-27 and had not closed by the
  reference date.
- ClearSky announced a recapitalization on 2026-05-05 without naming the investor.
- Bain's Surgery Partners take-private offer was rejected on 2025-06-17.
- Ardent has been public since 2024-07-18; EGI-AM still holds 54.0% (2026-03-26).

Not verified (the web-search budget ran out): Americore and Noble Health. Neither
appears in PESP's tracker, so neither is listed.

### Mapping systems to CCNs

A hospital belongs to a system when an owner with an ownership role in Hospital All
Owners (the 2026-08 release, so current as of about July 2026) matches the system's
owner regex. Example: `^LIFEPOINT|^DSB ACQUISITION|...` for Lifepoint;
`^KNIGHT HEALTH|^KINDRED ...` for ScionHealth. The include list adds hospitals the CMS
file does not yet show (Summa 360020, whose HATCo sale is not in the file), and the
exclude list removes hospitals sold since (Scenic Mountain).

Matching on owner names follows each CCN's current legal owners. The alternatives were
worse:
- **CHSP 2023 system names** predate recent sales and include hospitals a system only
  manages. CHSP "Quorum Health Corporation" lists 28 hospitals, and 20 of them have no
  Quorum or GoldenTree owner in the 2026-08 CMS file (hospitals Quorum sold, and Quorum
  Health Resources management clients). CHSP "Pipeline Health" still lists the Chicago
  and Dallas hospitals sold in 2022-2023.
- **Roster names** are ambiguous: "SUMMIT" and "HAVEN" match unrelated hospitals.

CHSP matches are still reported as a cross-check (`in_chsp`, and `chsp_only` rows in
`pe_system_ccn_map.csv`). Lifepoint agrees closely: 59 of the 60 CHSP Lifepoint
hospitals match by owner name. 4 CHSP Lifepoint or ScionHealth CCNs have no Apollo-side
owner in the 2026-08 CMS file: Norton Clark, TriHealth Clinton Regional, The Medical
Center at Russellville, and Southwestern Medical Center. Pipeline has 3 CHSP-only CCNs,
all sold in 2022-2023.

When a CCN matches two systems, strict beats ambiguous and ambiguous beats creditor. The
share held by the matched owner is kept (`pe_system_max_pct`).

## Definitions used in the models

Ownership groups: `nonprofit` (reference), `pe`, `cms_pe_flag`, `distressed_fund`,
`for_profit_non_pe`, `government`. Non-PE groups come from the CMS roster ownership
field.

| Definition | `pe` group | Separate groups |
|---|---|---|
| `pe_strict` | strict systems | `cms_pe_flag` (CMS PE flag, not strict), `distressed_fund` (creditor systems) |
| `pe_broad` | strict + ambiguous non-creditor (Ardent, Surgery Partners, Legent, Summa, MFO, NPH, Reunion) | `cms_pe_flag`, `distressed_fund` |
| `pe_broad_all` | every listed system, including creditor-owned, plus the CMS flag | none |
| `cms_flag` | CMS PE flag with an ownership role | none |
| `fund_name` | CMS PE flag or an owner name marking an investment fund; relabeled from the earlier "PE or fund". Most of its hospitals are **distressed-fund owned** (Quorum, Pipeline), so it is not a PE measure. | none |
| `researcher_list` (optional) | `pe_strict` plus CCNs in `HPT_PE_CCN_LIST` | as `pe_strict` |

## What the CMS flag contains

- 41 of 9,161 enrollments (0.4%) have an owner flagged PRIVATE EQUITY COMPANY. All 138
  such rows are indirect interests (role 35), except one security interest (role 37).
- 38 of the 41 are rehabilitation or long-term care hospitals, mostly Ernest Health
  under One Equity Partners VII funds. These are not in the roster.
- The 3 roster hospitals flagged PE are all Pipeline Health in Los Angeles County:
  - East Los Angeles Doctors Hospital (050641);
  - Memorial Hospital of Gardena (050468);
  - Community Hospital of Huntington Park (050091).
  Their flagged owners are Davidson Kempner distressed-debt funds, Deerfield Private
  Design Fund IV, and holding vehicles. The three share one price file.
- The flag misses every Apollo hospital. Lifepoint rows are all "N", no row names
  Apollo, and the Lifepoint ownership chain ends at "DSB ACQUISITION LLC", which is
  flagged INVESTMENT FIRM.
- It also flags a lender: "MPT OF BOISE HOSPITAL LLC", which holds a 54% security
  interest in Vibra Boise.
- Other checks:
  - Prospect: owned through Ivy Holdings; not flagged.
  - Steward: 2 rows, not flagged.
  - Ardent: not flagged.
  - Quorum: GoldenTree rows are flagged INVESTMENT FIRM, not PE.
- Vanguard and BlackRock are flagged INVESTMENT FIRM as 5%+ owners of the public chains,
  so that flag is no PE proxy either.
- Roster ownership has errors too:
  - some HCA hospitals are listed as nonprofit or government;
  - PECOS's own proprietary/nonprofit field disagrees with the roster for about 320
    hospitals.

## Prices

`ownership_price_sql()` applies the rules of `R/state_medians.R`, one facility price per
CCN x code x payer type:
- plausible negotiated dollars only;
- facility fees only (the stored `fee_type`; blank-billing-class rows at a professional-level
  gross are left out);
- `rate_row_filter_sql()`: outpatient procedures drop explicitly inpatient rows and
  operating-room case lines, and EMB and IUD insertion drop case-rate and per-diem rows;
- median within each payer/plan contract, then median across the hospital's contracts;
- cash: median discounted cash price over distinct charge lines;
- files in `output/median_excluded_file_ids.csv` (45 at the final run) are excluded;
- CCN-matched rates only.

A test rebuilds `compute_state_medians()` exactly from these hospital prices.
`outpatient_concepts()` includes `dc` (58120) and `hysteroscopy_sampling` (58558), so
explicitly inpatient rows are dropped for those codes too.

Codes: 45378, 58100, 58300, 58120, 58558, 43775, MS-DRG 621. Payer types: commercial,
Medicare Advantage, Medicaid, exchange, cash. Sample: acute and critical-access
hospitals.

## Model

For each code x payer type x definition:

    log(price) ~ ownership group + state FE + hospital type + system member + bed band

- **Reference group:** nonprofit. Bed band comes from AHRQ CHSP 2023. The adjusted
  difference is 100 x (exp(beta) - 1), and each CI limit is exponentiated on its own, so
  intervals are asymmetric in % and symmetric on the forest plot's log axis (checked:
  `add_pct_columns()` never uses 100 x beta).
- **One model per PE definition.** Groups within a model are mutually exclusive (PE,
  CMS-flagged, distressed fund, for-profit, government, nonprofit). Strict PE is nested in
  broad PE, so the two are never in one regression; "For-profit, not PE" in the forest plot
  comes from the strict model.
- **Standard errors:** cluster-robust CRV1 (sandwich `vcovCL`, HC1) with t intervals on
  G - 1 degrees of freedom, kept in the results CSV (`ci_low`, `ci_high`, `p_value`).
  `fixest` and `fwildclusterboot` are not installed, so the lm + sandwich path runs.
- **Small-cluster inference:** for the plotted groups (PE strict, PE broad, for-profit not
  PE), a wild cluster restricted (WCR) bootstrap: null imposed, Webb six-point weights
  drawn per health system, 9,999 draws, seeded per coefficient, CRV1 t statistics. The CI
  is the set of null values the bootstrap test does not reject (test inversion);
  `wcr_p_value`, `wcr_ci_low`, `wcr_ci_high`. `wild_cluster_bootstrap()` uses the fast
  cluster-sum algebra of Roodman, Nielsen, MacKinnon and Webb (2019): after partialling
  out the other regressors, every cluster's bootstrap score is linear in the weights and
  in the null value, so each point of the inversion costs O(B). Tests check it against
  `sandwich` (identical CRV1 SE), against brute-force refits (identical p value), and
  for size (5% test rejects 1% to 10% of 200 null data sets).
- **Exploratory estimates:** a group drawn from fewer than 5 health systems
  (`min_treated_clusters()`) is `exploratory`: point estimate only, no interval in the
  plot. With so few treated clusters even the wild bootstrap is unreliable (the restricted
  version under-rejects, the unrestricted over-rejects; MacKinnon and Webb 2017, 2018).
- **Not a payment comparison:** Medicare does not cover IUD insertion (58300: OPPS E1,
  PFS N), and Medicare Advantage follows Medicare coverage, so 58300 x Medicare Advantage
  estimates are flagged `payment_comparison = FALSE` and left out of the plot.
- **Clusters:** the listed PE system for hospitals in one, otherwise the CHSP system,
  otherwise the hospital. Clustering on the current owner puts Lifepoint's joint-venture
  hospitals in one cluster even when CHSP lists them under the partner.
- **Groups not estimated:** any group with fewer than 3 hospitals.
- **Flags:** `low_pe_n` (fewer than 10 PE hospitals), `few_pe_clusters` (fewer than 5
  PE clusters), `exploratory`, `payment_comparison`. Every row reports `n_group` and
  `n_group_clusters` (hospitals and health systems in the group) and `n_hospitals` and
  `n_clusters` (the whole cell).
- **Single-system groups:** when a group sits in one cluster the point estimate is kept
  and the CI is NA.
- **`group_clusters`** lists the largest clusters in each group, so you can see what
  drives each estimate.

## Results (final run of 2026-09-13 on the final `hpt.duckdb`)

Adjusted % difference vs nonprofit hospitals in the same state, with the 95% wild
cluster restricted bootstrap CI and p value; n = group hospitals; sys = health-system
clusters among them. Exploratory = fewer than 5 systems, no interval.

| Code | Payer | PE strict | PE broad | For-profit, not PE |
|---|---|---|---|---|
| 45378 colonoscopy | commercial | +28%, exploratory; n=39, 3 sys | +14% (-37% to +42%; p=0.54); n=67, 7 sys | +3% (-19% to +20%; p=0.73); n=363, 99 sys |
| 45378 colonoscopy | medicaid | +10%, exploratory; n=11, 2 sys | +28% (-35% to +115%; p=0.17); n=24, 5 sys | -10% (-33% to +19%; p=0.47); n=204, 57 sys |
| 58100 EMB | commercial | +54%, exploratory; n=7, 2 sys | +16% (-56% to +93%; p=0.71); n=15, 5 sys | +66% (-24% to +188%; p=0.49); n=267, 78 sys |
| 58100 EMB | medicaid | not estimated (n=1) | +120%, exploratory; n=4, 4 sys | -2% (-19% to +20%; p=0.84); n=126, 43 sys |
| 58300 IUD insertion | commercial | +149%, exploratory; n=9, 2 sys | +95%, exploratory; n=14, 4 sys | +80% (-16% to +192%; p=0.26); n=245, 74 sys |
| 58300 IUD insertion | medicaid | not estimated (n=1) | +87%, exploratory; n=3, 3 sys | +23% (-26% to +76%; p=0.64); n=113, 43 sys |
| 58120 D&C | commercial | -3%, exploratory; n=25, 3 sys | -6% (-41% to +53%; p=0.54); n=29, 5 sys | -5% (-29% to +13%; p=0.64); n=268, 74 sys |
| 58120 D&C | medicaid | -11%, exploratory; n=3, 2 sys | +20%, exploratory; n=5, 4 sys | -34% (-53% to -5%; p=0.03); n=140, 43 sys |
| 58558 hysteroscopy | commercial | +14%, exploratory; n=37, 3 sys | +7% (-36% to +152%; p=0.66); n=44, 5 sys | -0% (-26% to +19%; p=1.00); n=302, 81 sys |
| 58558 hysteroscopy | medicaid | -28%, exploratory; n=9, 2 sys | -23%, exploratory; n=12, 4 sys | -33% (-57% to -5%; p=0.03); n=168, 47 sys |
| MS-DRG 621 | commercial | -22%, exploratory; n=18, 3 sys | -27% (-53% to +26%; p=0.08); n=30, 5 sys | -12% (-20% to +1%; p=0.06); n=350, 90 sys |
| MS-DRG 621 | medicaid | +49%, exploratory; n=4, 1 sys | +43%, exploratory; n=8, 3 sys | +6% (-27% to +54%; p=0.70); n=165, 46 sys |
| 43775 sleeve | commercial | -48%, exploratory; n=12, 3 sys | -53% (-73% to -26%; p=0.01); n=19, 6 sys | -14% (-40% to +9%; p=0.26); n=248, 55 sys |
| 43775 sleeve | medicaid | not estimated (n=2) | +88%, exploratory; n=3, 3 sys | -32% (-59% to +33%; p=0.31); n=80, 23 sys |

What the bootstrap changes:
- **Strict PE is exploratory in every cell** (1 to 3 systems: Lifepoint and ScionHealth
  supply nearly all hospitals). Its CRV1 intervals looked significant for colonoscopy,
  EMB, IUD insertion, hysteroscopy, sleeve, and MS-DRG 621 (commercial); none of that survives
  as inference. The directions are descriptive.
- **Broad PE (4 to 7 systems in commercial cells):** only commercial sleeve gastrectomy
  (-53%, p=0.01) stays below 0.05; MS-DRG 621 is -27% (p=0.08). Across payers, CRV1 had 4
  significant non-exploratory broad-PE cells, the bootstrap 1.
- **For-profit, not PE** has 14 to 99 systems, but HCA is 122 to 123 of its hospitals in
  every commercial cell, so cluster sizes are very unequal and the bootstrap widens
  intervals where HCA drives the estimate: commercial IUD insertion +80% goes from
  p=0.01 (CRV1) to p=0.26, EMB +66% from 0.05 to 0.49. Medicaid D&C (-34%) and
  hysteroscopy (-33%) stay significant (p=0.03).
- Across the 93 plotted estimates, 43 are exploratory. Of the other 50, 4 are significant at
  0.05 by the bootstrap and 12 by CRV1.

The distressed-fund group (Quorum and other GoldenTree / Davidson Kempner hospitals, plus
Coast Plaza) has at most 2 priced hospitals per cell and is not estimated. Forrest City
and Mesa View publish through apps.para-hcfs.com script URLs, and their own files list
only 88305 among our codes. The previous build cross-linked other hospitals' para-hcfs
files to them; the final build does not.
Medicare Advantage, exchange, and cash cells are in `ownership_model_results.csv`.
Strict-PE cash prices exist only for Lifepoint hospitals (one cluster), so their
estimates have no CI. They are large: colonoscopy +42% (35 hospitals), IUD insertion +539%
(4), D&C +86% (18), hysteroscopy +51% (30).

### Robustness

**Within-state matched comparison** (`ownership_within_state.csv`): the median across
states of (median PE price / median nonprofit price - 1), over states with both groups.

| Code | Payer | PE strict | PE broad |
|---|---|---|---|
| 45378 colonoscopy | commercial | +24%, 20 states, higher in 65% | -7%, 25 states, 48% |
| 45378 colonoscopy | Medicaid | +5%, 8 states, 50% | +14%, 14 states, 57% |
| 58100 EMB | commercial | +39%, 6 states, 67% | +18%, 9 states, 56% |
| 58100 EMB | Medicaid | +26%, 1 state, 100% | +106%, 4 states, 100% |
| 58300 IUD insertion | commercial | +578%, 7 states, 86% | +345%, 10 states, 70% |
| 58300 IUD insertion | Medicaid | -23%, 1 state, 0% | -5%, 3 states, 33% |
| 58120 D&C | commercial | -21%, 16 states, 38% | -16%, 18 states, 39% |
| 58120 D&C | Medicaid | -21%, 3 states, 33% | +20%, 5 states, 60% |
| 58558 hysteroscopy | commercial | 0%, 20 states, 50% | +1%, 23 states, 52% |
| 58558 hysteroscopy | Medicaid | -50%, 7 states, 14% | -48%, 10 states, 20% |
| MS-DRG 621 | commercial | -24%, 18 states, 17% | -22%, 25 states, 20% |
| MS-DRG 621 | Medicaid | +42%, 4 states, 75% | +30%, 8 states, 62% |
| 43775 sleeve | commercial | -25%, 10 states, 40% | -39%, 11 states, 36% |
| 43775 sleeve | Medicaid | +322%, 2 states, 100% | +321%, 3 states, 67% |

The commercial IUD comparison rests on few states (7 strict, 10 broad) and few PE
hospitals (9 strict), so its size is not robust.

**By system** (`pe_system_price_ratios.csv`): each hospital's price divided by the
median nonprofit price in its state; median [IQR] across the system's hospitals.
Hospitals follow their owners in the CMS file, so the 8 community hospitals that moved
from ScionHealth to Lifepoint on 2026-06-02 still count as ScionHealth; both are Apollo.
Lifepoint drives the strict result, and the ambiguous systems pull the other way.
- **Commercial colonoscopy:**
  - Lifepoint +44% [-19%, +105%] (n=32);
  - Ardent +1% (n=18);
  - ScionHealth +9% (n=6);
  - Surgery Partners -31% (n=6);
  - Pipeline -59% (n=4, one shared file);
  - Legent -21% (n=3).
- **Commercial IUD insertion:**
  - ScionHealth +507% (n=5);
  - Lifepoint +249% (n=4);
  - Surgery Partners -20% (n=4).
  The case-line and case-rate rules left far fewer Lifepoint IUD prices (4 hospitals, down
  from 20 before them), so this cell is small.
- **Medicaid:** Ardent is higher for colonoscopy (+163%, n=10); Lifepoint is about level
  (+5%, n=10). No Apollo hospital has a Medicaid IUD insertion price in the final build.

**Raw medians** (`ownership_summary.csv`), commercial, nonprofit vs strict PE:

| Code | Nonprofit | Strict PE |
|---|---|---|
| 45378 | $2,252 (1,370) | $2,365 (39) |
| 58100 | $414 (1,222) | $405 (7) |
| 58300 | $417 (1,127) | $998 (9) |
| 58120 | $4,664 (1,128) | $2,876 (25) |
| 58558 | $5,055 (1,222) | $4,430 (37) |
| MS-DRG 621 | $22,295 (1,222) | $17,321 (18) |
| 43775 | $10,340 (792) | $4,645 (12) |

**The earlier CMS-only definitions:**
- `cms_flag` (3 Pipeline hospitals, one shared file) and `fund_name` (mostly Quorum and
  Pipeline) both show lower commercial prices.
- That reflects distressed, safety-net hospitals, not PE buyout owners.
- Report them as "CMS-flagged" and "distressed-fund owned", not as PE.

**Kim et al. cross-check:** see "Public PE-hospital datasets checked" above.

## Limitations

- **PE here mostly means Apollo.** Under the strict definition, Lifepoint and
  ScionHealth make up nearly all priced PE hospitals. The estimates describe those two
  systems' contracting; they are not a general PE effect. With 1 to 3 strict-PE
  clusters, no interval is valid, so strict-PE estimates are reported as exploratory point
  estimates. Lean on the direction across codes, the within-state comparisons, and the
  per-system ratios.
- **Ownership classification is a judgment call.** The strict/ambiguous line (family
  office, public company with a PE minority, joint ventures, creditor ownership) follows
  the rules set for this analysis and is documented per system. PESP counts several ambiguous systems as
  PE. Lifepoint and Emerus hospitals are often joint ventures with nonprofits.
- **Current owners, not acquisition timing.** The list is a cross-section as of July
  2026. It cannot separate the effect of acquisition from the selection of which
  hospitals Apollo bought (rural, sole-community hospitals with market power).
- **Specialty hospitals.** The broad group adds surgical hospitals (Surgery Partners,
  Legent, OrthoNebraska). Hospital type only distinguishes acute from critical access.
- **Roster ownership errors** and **stale CHSP systems and beds** (2023).
- **List prices, not paid amounts;** percent-of-charge contracts without dollars drop out.
- **Charge-line packaging** (clinic vs operating-room lines) can move 58100 and 58300;
  the case-line and case-rate rules (R/state_medians.R) remove most of it, but HCA's
  58300 lines at outpatient-surgery rates remain and weigh on the for-profit group.
- **Coverage.** CCN-matched files only. Some listed hospitals have no prices (Emerus: 0 of
  8; Quorum: 1 of 12).
- **Multiple testing.** 7 codes x 5 payers x 5 definitions x up to 5 contrasts; no
  adjustment. Treat isolated significant cells as hypothesis-generating.
- **Unverified items.** Americore and Noble; the post-2023 equity holders of Pipeline;
  whether InTandem still controlled OrthoNebraska in 2026; the Perimeter buyer.

## Outputs (`HPT_DATA_DIR/output/`)

| File | Contents |
|---|---|
| `pe_system_ccn_map.csv` | every system x CCN match: method (owner_name, include_ccns, chsp_only), matched owner share, CHSP agreement, priced |
| `pe_system_counts.csv` | hospitals per system by method, roster, acute/CAH, priced, CHSP agreement |
| `pe_system_price_ratios.csv` | each system's prices vs same-state nonprofit medians |
| `ownership_classification.csv` | one row per roster CCN: CMS PE markers, PE system, one group column per definition |
| `ownership_pe_owners.csv` | owners behind the CMS PE flag and fund names |
| `ownership_counts.csv` | hospitals by ownership group x hospital type and x state |
| `ownership_hospital_prices.parquet` | facility price per CCN x code x payer type, with ownership columns |
| `ownership_model_results.csv` | adjusted differences, CRV1 and wild cluster bootstrap CIs and p values, n and clusters per group and cell, cluster mix, exploratory and payment-comparison flags |
| `ownership_summary.csv` | raw medians, IQR, n by group |
| `ownership_within_state.csv` | within-state matched comparison |
| `figures/ownership_forest.png` | forest plot: PE strict, PE broad, non-PE for-profit |

These files hold rates derived from the Trilliant download; they stay on the data drive
under the same terms as the rest of the project (README, Sources).
