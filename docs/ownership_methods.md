# Private-equity ownership and negotiated hospital prices

Question: do private-equity (PE) owned hospitals post higher negotiated prices than
other hospitals for the same procedure, in the same state, for the same payer type?

Code: `R/ownership.R`, `analysis/13_ownership_prices.R`, `tests/testthat/test-ownership.R`,
and the sourced system list `config/pe_hospital_systems.csv`. Outputs go to
`HPT_DATA_DIR/output/` (listed at the end).

**Short answer.** PE here means hospitals whose system is controlled by a PE fund as of
July 2026. That is almost entirely Lifepoint Health and ScionHealth, both owned by Apollo
funds. These hospitals post higher commercial prices than nonprofit hospitals in the same
state for office-type gynecologic and endoscopic procedures:
- colonoscopy (45378): +34%;
- endometrial biopsy (58100): +61%;
- IUD insertion (58300): +38%;
- hysteroscopy (58558): +19%.

They post about the same price for D&C (58120), and lower prices for inpatient bariatric
surgery (MS-DRG 621 -22%, sleeve 43775 -44%).

The pooled PE group rests on 3 health systems, so the confidence intervals understate the
real uncertainty, and the estimates describe Apollo's hospitals more than PE in general.
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
| `hpt.duckdb` | final build of 2026-09-13 05:31: 7,753,542 rates, 3,924 files, 3,303 CCNs, with 58120 and 58558 | negotiated rates |

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
- facility fees only;
- outpatient concepts (`outpatient_concepts()`) drop explicitly inpatient rows;
- median within each payer/plan contract, then median across the hospital's contracts;
- cash: median discounted cash price over distinct charge lines;
- files in `output/median_excluded_file_ids.csv` (42 at the final run) are excluded;
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
  difference is exp(beta) - 1.
- **Standard errors:** cluster-robust (sandwich `vcovCL`, HC1) with t intervals on G - 1
  degrees of freedom. `fixest` is not installed, so the lm + sandwich path runs.
- **Clusters:** the listed PE system for hospitals in one, otherwise the CHSP system,
  otherwise the hospital. Clustering on the current owner puts Lifepoint's joint-venture
  hospitals in one cluster even when CHSP lists them under the partner.
- **Groups not estimated:** any group with fewer than 3 hospitals.
- **Flags:** `low_pe_n` (fewer than 10 PE hospitals) and `few_pe_clusters` (fewer than 5
  PE clusters).
- **Single-system groups:** when a group sits in one cluster the point estimate is kept
  and the CI is NA.
- **`group_clusters`** lists the largest clusters in each group, so you can see what
  drives each estimate.

## Results (final run of 2026-09-13 on the 05:31 `hpt.duckdb`)

Adjusted % difference vs nonprofit hospitals in the same state (95% CI); n = group
hospitals; sys = clusters (health systems) among them. **With 3 to 8 PE clusters,
cluster-robust CIs are too narrow; read them as rough.** In `pe_strict`, Lifepoint supplies
69% to 82% of PE hospitals in the colonoscopy, IUD, D&C, and hysteroscopy commercial cells.
ScionHealth supplies 6 of the 8 in commercial EMB and 5 of 13 for sleeve. OrthoNebraska
adds one hospital in most cells. "NA" means one cluster, so no CI.

| Code | Payer | PE strict | PE broad | PE broad incl. creditor | CMS PE flag group | For-profit, not PE |
|---|---|---|---|---|---|---|
| 45378 colonoscopy | commercial | +34% (+14% to +58%); n=39, 3 sys | +18% (-7% to +48%); n=67, 7 sys | +12% (-15% to +46%); n=71, 8 sys | -50% (NA); n=3, 1 sys | +8% (-7% to +26%); n=377 |
| 45378 colonoscopy | Medicare Adv. | -11% (-32% to +17%); n=15, 3 sys | +17% (-14% to +59%); n=36, 7 sys | +15% (-13% to +52%); n=40, 8 sys | +6% (NA); n=3 | +23% (+3% to +47%); n=289 |
| 45378 colonoscopy | Medicaid | +15% (-11% to +48%); n=11, 2 sys | +33% (+6% to +66%); n=24, 5 sys | +34% (+8% to +67%); n=28, 6 sys | +44% (NA); n=3 | -6% (-26% to +20%); n=213 |
| 45378 colonoscopy | exchange | +15% (-1% to +33%); n=19, 3 sys | -5% (-25% to +19%); n=32, 6 sys | -10% (-29% to +13%); n=36, 7 sys | -43% (NA); n=3 | +20% (+3% to +39%); n=266 |
| 58100 EMB | commercial | +61% (+36% to +90%); n=8, 3 sys | +13% (-25% to +71%); n=16, 6 sys | -8% (-45% to +53%); n=20, 7 sys | -60% (NA); n=3 | +62% (+10% to +140%); n=281 |
| 58100 EMB | Medicaid | not estimated (n=2) | +261% (+135% to +454%); n=5, 5 sys | +145% (+37% to +337%); n=9, 6 sys | +52% (NA); n=3 | -6% (-22% to +13%); n=142 |
| 58300 IUD insertion | commercial | +38% (-5% to +99%); n=26, 3 sys | +31% (-4% to +80%); n=31, 5 sys | +5% (-38% to +77%); n=35, 6 sys | -81% (NA); n=3 | +89% (+37% to +162%); n=289 |
| 58300 IUD insertion | Medicaid | +269% (+150% to +444%); n=6, 2 sys | +293% (+171% to +471%); n=8, 4 sys | +122% (-11% to +450%); n=12, 5 sys | -26% (NA); n=3 | +36% (+2% to +83%); n=145 |
| 58120 D&C | commercial | -2% (-19% to +19%); n=25, 3 sys | -6% (-22% to +13%); n=29, 5 sys | -7% (-22% to +10%); n=33, 6 sys | -18% (NA); n=3 | +2% (-13% to +20%); n=282 |
| 58120 D&C | Medicaid | +17% (-44% to +147%); n=3, 2 sys | +49% (-17% to +167%); n=5, 4 sys | +87% (-2% to +256%); n=9, 5 sys | +150% (NA); n=3 | -30% (-47% to -8%); n=151 |
| 58558 hysteroscopy | commercial | +19% (+5% to +36%); n=37, 3 sys | +12% (-6% to +34%); n=44, 5 sys | +9% (-10% to +32%); n=48, 6 sys | -19% (NA); n=3 | +8% (-10% to +28%); n=311 |
| 58558 hysteroscopy | Medicaid | -22% (-45% to +11%); n=9, 2 sys | -16% (-42% to +22%); n=12, 4 sys | +19% (-45% to +160%); n=16, 5 sys | +225% (NA); n=3 | -31% (-48% to -9%); n=174 |
| MS-DRG 621 | commercial | -22% (-30% to -12%); n=18, 3 sys | -27% (-37% to -15%); n=30, 5 sys | -26% (-36% to -14%); n=35, 7 sys | -10% (NA); n=3 | -12% (-20% to -4%); n=350 |
| MS-DRG 621 | Medicaid | +49% (NA); n=4, 1 sys | +43% (+13% to +81%); n=8, 3 sys | +54% (+11% to +114%); n=13, 5 sys | +95% (NA); n=3 | +6% (-17% to +36%); n=165 |
| 43775 sleeve | commercial | -44% (-62% to -19%); n=13, 3 sys | -51% (-65% to -31%); n=20, 6 sys | -49% (-62% to -33%); n=24, 7 sys | -43% (NA); n=3 | -13% (-31% to +10%); n=253 |

The distressed-fund group (Quorum and other GoldenTree / Davidson Kempner hospitals, plus
Coast Plaza) has only 1 to 2 priced hospitals per cell and is not estimated. Forrest City
and Mesa View publish through apps.para-hcfs.com script URLs, and their own files list
only 88305 among our codes. The previous build cross-linked other hospitals' para-hcfs
files to them; the final build does not.
Medicare Advantage, exchange, and cash cells are in `ownership_model_results.csv`.
Strict-PE cash prices exist only for Lifepoint hospitals (one cluster), so their
estimates have no CI. They are large: colonoscopy +75%, IUD insertion +566%, D&C +116%,
hysteroscopy +100%.

### Robustness

**Within-state matched comparison** (`ownership_within_state.csv`): the median across
states of (median PE price / median nonprofit price - 1), over states with both groups.

| Code | Payer | PE strict | PE broad |
|---|---|---|---|
| 45378 colonoscopy | commercial | +26%, 20 states, higher in 65% | -6%, 25 states, 48% |
| 45378 colonoscopy | Medicaid | +3%, 8 states, 50% | +12%, 14 states, 57% |
| 58100 EMB | commercial | +81%, 7 states, 86% | +18%, 10 states, 60% |
| 58300 IUD insertion | commercial | +63%, 17 states, 71% | +45%, 20 states, 65% |
| 58120 D&C | commercial | -21%, 16 states, 38% | -14%, 18 states, 39% |
| 58558 hysteroscopy | commercial | +8%, 20 states, 55% | +13%, 23 states, 61% |
| MS-DRG 621 | commercial | -24%, 18 states, 17% | -22%, 25 states, 20% |
| 43775 sleeve | commercial | -31%, 11 states, 36% | -43%, 12 states, 33% |

**By system** (`pe_system_price_ratios.csv`): each hospital's price divided by the
median nonprofit price in its state; median [IQR] across the system's hospitals.
Hospitals follow their owners in the CMS file, so the 8 community hospitals that moved
from ScionHealth to Lifepoint on 2026-06-02 still count as ScionHealth; both are Apollo.
Lifepoint drives the strict result, and the ambiguous systems pull the other way.
- **Commercial colonoscopy:**
  - Lifepoint +62% [-16%, +144%] (n=32);
  - ScionHealth +10% (n=6);
  - Ardent +1% (n=18);
  - Surgery Partners -30% (n=6);
  - Legent -21% (n=3);
  - Pipeline -59% (n=4, one shared file).
- **Commercial IUD insertion:**
  - Lifepoint +66% (n=20);
  - ScionHealth +277% (n=5);
  - Surgery Partners -36% (n=4).
- **Medicaid:** Ardent is higher for colonoscopy (+175%, n=10). Lifepoint is higher for
  IUD insertion (+604%, n=5, a small cell).

**Raw medians** (`ownership_summary.csv`), commercial, nonprofit vs strict PE:

| Code | Nonprofit | Strict PE |
|---|---|---|
| 45378 | $2,159 (1,483) | $2,365 (39) |
| 58100 | $477 (1,317) | $772 (8) |
| 58300 | $554 (1,258) | $936 (26) |
| 58120 | $4,286 | $2,876 |
| 58558 | $4,822 | $4,430 |
| MS-DRG 621 | $22,242 | $17,321 |
| 43775 | $9,751 | $4,726 |

**The earlier CMS-only definitions:**
- `cms_flag` (3 Pipeline hospitals, one shared file) and `fund_name` (mostly Quorum and
  Pipeline) both show lower commercial prices.
- That reflects distressed, safety-net hospitals, not PE buyout owners.
- Report them as "CMS-flagged" and "distressed-fund owned", not as PE.

**Kim et al. cross-check:** see "Public PE-hospital datasets checked" above.

## Limitations

- **PE here mostly means Apollo.** Under the strict definition, Lifepoint and
  ScionHealth make up nearly all priced PE hospitals. The estimates describe those two
  systems' contracting; they are not a general PE effect. With 3 PE clusters,
  cluster-robust CIs are too narrow, and a wild cluster bootstrap would not rescue
  inference with so few treated clusters. Treat the CIs as descriptive, and lean on the
  direction across codes, the within-state comparisons, and the per-system ratios.
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
- **Charge-line packaging** (clinic vs operating-room lines) can move 58100 and 58300.
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
| `ownership_model_results.csv` | adjusted differences, CIs, n and clusters per group, cluster mix, flags |
| `ownership_summary.csv` | raw medians, IQR, n by group |
| `ownership_within_state.csv` | within-state matched comparison |
| `figures/ownership_forest.png` | forest plot: PE strict, PE broad, non-PE for-profit |

These files hold rates derived from the Trilliant download; they stay on the data drive
under the same terms as the rest of the project (README, Sources).
