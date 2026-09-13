# Add-on procedures: is the extra room time worth it?

Code: `R/addon_economics.R`, `analysis/12_addon_value.R`, `config/addon_parameters.csv`,
`tests/testthat/test-addon.R`.

## Question

When a gynecologist adds a small procedure to another service's case, the hospital
earns the add-on's payment but spends room minutes that could have held another primary
case. Two cases:

| Case | Primary | Add-on bundle |
|---|---|---|
| A | Bariatric surgery priced at MS-DRG 621, O.R. procedures for obesity without CC/MCC (sensitivity: DRG 620; CPT 43775 sleeve; CPT 43644 bypass) | IUD insertion 58300 + device (J7298 Mirena; variants J7297 Liletta, J7300 Paragard) |
| B | Diagnostic colonoscopy, CPT 45378 (variants: screening G0121, high-risk screening G0105) | Endometrial biopsy 58100 + surgical pathology 88305 |

**Why DRG 621 is case A's base primary price.** CPT-coded 43775/43644 facility lines in
hospital MRFs are often partial. The national Medicare median for 43775 is $1,062,
against $12,932 for DRG 621, which matches the FY2026 IPPS payment. Elective bariatric
surgery is mostly an inpatient DRG stay (Medicare: status C, inpatient only). DRG 620
(with CC) is a sensitivity, and so are the CPT codes. DRG variants use the sleeve OR
slot, because sleeve is the most common operation.

The main analysis takes the hospital's view with a capacity limit. A separate section
covers the payer and patient view.

## Model

### Revenue

- **Source.** Prices are facility-fee medians from `compute_state_medians()`. Each is a
  two-stage median: per hospital, then across hospitals, by state x insurance type x
  code.
- **Fallback.** Each price uses the state median when at least `min_hospitals` (3)
  hospitals back it. Otherwise it falls back to the national (`state == "US"`) median
  for the same insurance type. A code with no national median can use a sourced
  parameter; the only one is 88305, at the OPPS rate.
- **Recording.** Every price records its source (`state`, `national`, `parameter`,
  `missing`). The output has `primary_fallback` and `secondary_fallback` flags.
- **Collected share.** An HPT negotiated rate is the standalone price of a code. When
  the add-on is billed with the primary, the hospital collects only part of it.
  Define:

  R_S = f_proc x rate(58300 or 58100) + f_item x rate(device or 88305)

  The collected shares `f` are parameters. They default by case and component, and
  some insurance types have their own values:
  - Medicare inpatient DRG pays nothing extra for an IUD. The ICD-10-PCS insertion
    codes do not affect DRG 619-621, and 58300 and the J-codes are non-covered
    (status N / E1).
  - Medicare OPPS pays 58100 at 50%. It is a status T procedure ranked below 45378,
    so the multiple-procedure discount applies. 88305 (status Q1) is packaged.
- **Standalone-rate scenario.** R_S_listed is the add-on paid at its standalone rates
  (f = 1). It is reported as the optimistic scenario.

### Hospital net value per add-on

With T_P = room minutes per primary case including turnover, dT = added minutes,
u = probability the freed minutes would have held another primary case, and
m = contribution-margin share of the primary payment:

```
C_S  = R_S - variable costs of the add-on
       (A: device + supplies + anesthetic drug increment + coordination;
        B: pathology processing + supplies + anesthetic drug increment + coordination)

opportunity-cost framing:  net = C_S - u * (dT / T_P) * m * R_P
room-cost framing:         net = C_S - dT * (direct room cost + anesthesia cost per minute)

break-even added minutes   dT* = C_S * T_P / (u * m * R_P)
break-even utilization     u*  = C_S / ((dT / T_P) * m * R_P)     (u* > 1: worth it even fully booked)
room-cost break-even       dT*_room = C_S / cost per minute
revenue per minute ratio   (R_S / dT) / (R_P / T_P)
```

- **Two framings.** They are alternatives, never added together: displacement
  already prices the minutes.
  - The opportunity-cost framing charges only the lost margin, because a displaced
    case loses its contribution, not its whole payment.
  - The room-cost framing ignores displacement and charges the minutes at an average
    cost.
- **When C_S <= 0**, no dT or u makes the add-on pay. dT* and u* are then reported as
  NA.

### Integer capacity

A block of B minutes holds `floor(B / (T_P + f * dT))` primary cases when a share f of
cases get the add-on. `addon_day_value()` reports day revenue and day contribution
against f = 0.

`addon_free_addons_per_day()` counts the add-ons that fit in the end-of-day slack
before a case is lost. It shows that a few minutes often cost nothing until
f x dT uses up the slack.

### Payer and patient view

Payer, combined setting:
- the collected add-on facility payment R_S;
- plus a facility-setting professional fee.

Payer, standalone office encounter:
- the office procedure fee;
- plus an E/M visit;
- plus the device (A) or pathology (B).

Patient:
- office visits avoided, times the patient time cost per visit;
- expected displaced primary cases per 100 add-ons (100 x u x dT / T_P);
- expected days of delay per add-on (displaced cases x days of delay per displaced
  case).

No health outcomes are monetized.

### Sensitivity

**One-way (tornado).** Each parameter goes to its low and high value while the others
stay at base. Prices go to the interhospital p25 and p75 of the median they came from.
Run for national commercial and medicaid.

**Probabilistic (PSA).** 5,000 joint independent draws, seed 20260912.
- Distributions:
  - triangular(low, base, high);
  - beta and gamma by method of moments, with mean = base and sd = (high - low) / 3.92;
  - fixed.
- Prices stay at their national medians.
- Triangular draws use base as the mode, so a skewed range moves the PSA mean away
  from the base case. An example is the device's collected share for commercial
  bariatric cases (0, mode 0.1, 1).

All costs are in 2026 dollars:
- medical-care costs are rescaled with CPI-U Medical Care;
- the patient time cost is rescaled with CPI-U All Items.

## Parameters

The full table, with complete citations and notes, is `config/addon_parameters.csv`.
Several parameters are reused from `emb_colonoscopy config/model_parameters.csv @ 471e067`:
- `combined_emb_added_minutes`
- `direct_room_cost_per_minute`
- `anesthesia_cost_per_minute`
- `combined_emb_anesthesia_drug_increment_cost`
- `coordination_cost`
- `emb_pathology_cost`
- `emb_disposable_supply_cost`
- `emb_office_professional_cost` (and `_facility`)
- `office_visit_em_cost`
- `patient_time_opportunity_cost_per_visit`

"Prov." marks provisional parameters, meaning no defensible direct source.

| Parameter | Case | Base | Range | Dist. | Dollar year to 2026 | Prov. | Source (short) |
|---|---|---|---|---|---|---|---|
| `colonoscopy_slot_minutes` | B | 55 min | 40 to 65 | triangular | | no | Almeida 2016 PMID 27446830; Soderberg 2023 PMID 36923210; Day 2014 PMID 24796958; Kidambi 2024 PMID 39411629; corroborated by ONCE (Frissora 2025) PMID 40821478 |
| `sleeve_or_slot_minutes` | A | 145 min | 115 to 180 | triangular | | no | Clapp 2023 PMID 36752855 (MBSAQIP median 68 min operative); Sanford 2015 PMID 25802066; El Chaar 2023 PMID 37804468; Hoffman 2018 PMID 30518428 |
| `bypass_or_slot_minutes` | A | 190 min | 160 to 265 | triangular | | no | Clapp 2023 (median 113 min); Inaba 2019 PMID 31128998; Sanford 2015 |
| `iud_added_minutes_at_surgery` | A | 10 min | 5 to 20 | triangular | | **yes** | None found; O'Flynn O'Brien 2019 PMID 30633980 (office insertion 6-9 min) plus repositioning |
| `combined_emb_added_minutes` | B | 5 min | 1 to 12 | triangular | | no | Huang 2011 PMC3014510 (reused); corroborated by ONCE (Frissora 2025) PMID 40821478 |
| `or_block_minutes` | A | 480 min | 240 to 600 | fixed | | no | Pandit & Dexter 2009 PMID 19448221 |
| `endoscopy_block_minutes` | B | 480 min | 240 to 600 | fixed | | no | Dexter, Epstein, Penning 2020 PMID 31195226; Day 2014 |
| `utilization_A` | A | 0.25 | 0 to 0.75 | beta | | **yes** | Judgment; Dexter 1995 PMID 7486114; Dexter 2003 PMID 14500168; Alvarez 2019 PMID 29794842 |
| `utilization_B` | B | 0.50 | 0.1 to 0.9 | beta | | **yes** | Judgment; Hubers 2020 PMID 31899692; Shim 2024 PMID 38916225; Joseph 2016 PMID 27200481; Li 2026 PMID 42337220 |
| `contribution_margin_bariatric` | A | 0.48 | 0.127 to 0.626 | beta | | no | Mou 2023 PMID 37308762; Eappen 2013 PMID 23592104 |
| `contribution_margin_colonoscopy` | B | 0.50 | 0.2 to 0.8 | beta | | **yes** | Derived: Henry 2007 PMID 17665271 cost vs OPPS 2026 and RAND 2024 multiplier |
| `iud_acquisition_cost_J7298` | A | $1,156.79 | 983.27 to 1,272.44 | triangular | 2024 to $1,218.22 | no | Bayer WAC letter, Dec 2023 |
| `iud_acquisition_cost_J7297` | A | $887.36 | 50 to 931.73 | triangular | 2025 to $908.28 | **yes** | Derived from Louisiana Medicaid 2025 fee schedule; 340B $50 |
| `iud_acquisition_cost_J7300` | A | $1,187.00 | 1,008.95 to 1,187 | triangular | 2026 | no | CooperSurgical WAC letter, Nov 2025 |
| `iud_insertion_supply_cost` | A | $28.79 | 10 to 50 | triangular | 2026 | **yes** | Proxy: CMS 2026 PE inputs for 58100 |
| `emb_disposable_supply_cost` | B | $28.79 | 24.47 to 33.11 | gamma | 2026 | no | CMS 2026 PE inputs (reused) |
| `emb_pathology_cost` | B | $50.75 | 35.43 to 67.41 | gamma | 2024 to $53.44 | no | CMS PUF 2024, 88305 (reused) |
| `combined_emb_anesthesia_drug_increment_cost` | both | $0 | 0 to 25 | triangular | | no | Huang 2011 (reused) |
| `coordination_cost` | both | $22.08 | 9.38 to 38.09 | gamma | 2025 to $22.60 | **yes** | O*NET wage x practitioner time (reused) |
| `direct_room_cost_per_minute` | both | $20.90 | 8.36 to 33.44 | gamma | 2014 to $28.51 | no | Childers & Maggard-Gibbons 2018 PMID 29490366 (reused) |
| `anesthesia_cost_per_minute` | both | $3.42 | 0.48 to 6.36 | gamma | 2014 to $4.67 | no | Childers & Maggard-Gibbons 2018 (reused) |
| `pay_frac_A_procedure` / `_item` (default) | A | 0 / 0.10 | 0 to 0.5 / 0 to 1 | triangular | | **yes** | UHC OPG 2026 exhibit; Anthem facility policy; Medi-Cal and AHCCCS device carve-outs |
| `pay_frac_A_*__medicare` | A | 0 / 0 | fixed | fixed | | no | 42 CFR 412.2; MS-DRG v43.1 Appendix E; PFS status N; OPPS E1 |
| `pay_frac_A_*__medicare_advantage` | A | 0 / 0 | 0 to 0.5 | triangular | | **yes** | Assumed to follow Medicare |
| `pay_frac_A_*__medicaid` | A | 0 / 0 | fixed / 0 to 1 | fixed / triangular | | no | CMCS bulletin 2016; ACOG 2023; Medi-Cal; AHCCCS |
| `pay_frac_B_procedure` / `_item` (default) | B | 0.5 / 0.5 | 0 to 1 | triangular | | **yes** | UHC, Cigna, Anthem multiple-procedure policies |
| `pay_frac_B_*__medicare` | B | 0.5 / 0 | fixed | fixed | | no | OPPS Addendum B July 2026 (58100 T; 88305 Q1); Claims Processing Manual ch. 4 section 10.5 |
| `pay_frac_B_*__medicare_advantage` | B | 0.5 / 0 | 0 to 1 | triangular | | **yes** | Assumed to follow OPPS |
| `fallback_rate_88305` | B | $53.24 | fixed | fixed | 2026 | no | OPPS Addendum B July 2026, APC 5671 |
| `office_iud_insertion_professional_payment` | A | $105.55 | fixed | fixed | 2026 | no | PFS RVU26C: 3.16 RVU x $33.4009 |
| `iud_insertion_professional_payment_facility` | A | $43.76 | fixed | fixed | 2026 | no | PFS RVU26C: 1.31 RVU x $33.4009 |
| `emb_office_professional_cost` (`_facility`) | B | $97.03 ($60.05) | p25 to p75 | gamma | 2024 | no | CMS PUF 2024 (reused) |
| `office_visit_em_cost` | both | $88.76 | 83.86 to 93.53 | gamma | 2024 to $93.47 | no | CMS PUF 2024, 99213 (reused) |
| `patient_time_opportunity_cost_per_visit` | both | $43 | fixed | fixed | 2010 to $65.63 | **yes** | Ray 2015 PMID 26295356 (reused) |
| `avoided_standalone_visits_A` / `_B` | A / B | 1 | 1 to 2 | triangular | | **yes** | Assumption |
| `delay_days_per_displaced_case_A` / `_B` | A / B | 30 days | 7 to 90 | triangular | | **yes** | Assumption; wait-time context from Alvarez 2019, Eng 2019, Hubers 2020, Shim 2024 |

**ONCE (Frissora et al. 2025, PMID 40821478).** This prospective study of combined screening in 20
Lynch syndrome patients under propofol reports an average combined procedure time of 42 minutes (range
27-59) and total OR time of 54 minutes (range 37-93) for a session of EMB, upper endoscopy when
indicated, and colonoscopy, with the EMB performed first and "typically" taking under 10 minutes. It does
not define OR time, report component times, or say how many patients had upper endoscopy. So it cannot
narrow either input. It corroborates both: an EMB of under 10 minutes sits inside the 1-12 minute range
(base 5, Huang 2011, n = 42), and a triple-screen session of 54 minutes bounds colonoscopy alone from
above, consistent with the 40-65 minute slot including turnover. Base values and ranges are unchanged.

CPI values are also rows in the table:
- Medical Care: 2014 435.292, 2024 563.841, 2025 580.102 (BLS API v2, retrieved
  2026-09-12); 2010 388.436 and July 2026 593.781 (from emb_colonoscopy).
- All Items: 2010 218.056, July 2026 332.813 (from emb_colonoscopy).

The 2014 value replaces the interpolated placeholder (431.9) still in emb_colonoscopy.

## National results (Trilliant lake, three-stage medians, run 2026-09-13)

**Data.**
- Prices are facility medians computed in three stages: per contract, then per
  hospital, then per state.
- Hospitals behind the national medians:
  - 45378: 2,319 (commercial) to 799 (Medicare);
  - DRG 621: 1,782 (commercial) to 839 (Medicare);
  - 58100: 1,937 commercial;
  - 58300: 1,903 commercial;
  - J7298: 1,653 commercial;
  - 88305: 2,750 commercial.
- 52 state-level units (50 states, DC, PR). In the base variants, most state rows use
  their own state's prices:
  - 45378 commercial: 48 of 52 use state prices for all three codes;
  - DRG 621 commercial: 47 of 52.
  - The rest fall back to national and are flagged (`primary_fallback`,
    `secondary_fallback`).

**Case A: IUD + Mirena at bariatric surgery, priced at MS-DRG 621.** Values are 2026
USD per add-on.

| Insurance | R_P (DRG 621) | R_S collected | C_S | Displacement cost | Net value | Room-cost framing | Standalone-rate scenario | PSA P(worth it) |
|---|---|---|---|---|---|---|---|---|
| commercial | $20,334 | $210 | -$1,059 | $168 | **-$1,228** | -$1,391 | +$1,235 | 0.16 |
| exchange | $19,451 | $166 | -$1,104 | $161 | **-$1,265** | -$1,436 | +$815 | 0.06 |
| medicare | $12,932 | $0 | -$1,270 | $107 | **-$1,377** | -$1,601 | +$96 | 0 |
| medicare_advantage | $12,588 | $0 | -$1,270 | $104 | **-$1,374** | -$1,601 | -$13 | 0 |
| medicaid | $12,403 | $0 | -$1,270 | $103 | **-$1,372** | -$1,601 | +$10 | 0 |
| self_pay_cash | $21,792 | $198 | -$1,071 | $180 | **-$1,252** | -$1,403 | +$859 | 0.11 |

- **Break-even.** C_S is negative for every insurance type, so no added-minutes value
  (dT*) or utilization (u*) makes the add-on pay. OR time is not the problem.
- **Revenue per minute.** The add-on earns 0 to 0.19 times the DRG case's revenue per
  minute.
- **Where the loss comes from.** The device costs about $1,218 (Mirena WAC, 2026
  dollars). Traditional Medicare never pays for it, and it is packaged in most DRG and
  case-rate contracts. Displacement adds only $100 to $180 per add-on.
- **Sensitivity variants** are all negative nationally for every insurance type:
  - DRG 620 (with CC): -$1,239 commercial, -$1,379 Medicaid.
  - CPT 43775: -$1,138 commercial, -$1,285 Medicaid.
- **States.** 0 of 52 states are net-positive for commercial or Medicaid, in any case
  A variant. In the standalone-rate scenario, 50 states are positive for commercial
  and 37 for Medicaid.
- **Top 3 one-way drivers (commercial):**
  1. The device's collected share: -$1,438 to +$665. This is the only parameter that
     can flip the sign.
  2. Utilization u (0 to 0.75): -$1,059 to -$1,564.
  3. Device acquisition cost: -$1,045 to -$1,349.
  For Medicaid the order is the same: device carve-out (up to -$158), u, device cost.
- **PSA** (5,000 draws): P(worth it) is 0.16 commercial, 0.06 exchange, 0.11 cash, 0.20
  workers' comp, and 0 for Medicaid, Medicare and Medicare Advantage.
  - It is never above 0.32 for any insurance type at the DRG 621 price.
  - For commercial, every positive draw has a device collected share of at least
    0.48.
  - Self-pay is the exception: its national 58300 median is an outlier ($3,767, 64
    hospitals).
- **Day model.**
  - A 480-minute OR fits 3 bariatric cases (145 min each) with 45 min of slack, so
    four 10-minute IUDs fit without losing a case. Even at f = 1 the day loses only
    the add-ons' own contribution (-$3,178 commercial).
  - At 20 minutes, a case is lost once more than 75% of cases get an IUD (-$11,879 per
    day at f = 1, commercial).
- **Payer and patient.** A standalone office insertion costs the payer about $1,417
  (insertion $105.55, device $1,218, visit $93.47). Combined, the payer pays $44 to
  $278 ($44 when the add-on is fully packaged), so its "saving" is $1,139 to $1,373.
  - That saving is mostly the device the hospital absorbs: a cost shift, not a
    resource saving.
  - The patient avoids one visit ($65.63 of time).
  - At u = 0.25 there are 1.7 displaced bariatric cases per 100 add-ons, or 0.52
    patient-days of delay per add-on.

**Case B: EMB + pathology at colonoscopy (45378).** Values are 2026 USD per add-on.

| Insurance | R_P | R_S collected | C_S | Net value | dT* (min) | u* | Room-cost framing | PSA P(worth it) |
|---|---|---|---|---|---|---|---|---|
| commercial | $2,079 | $307 | $202 | **+$155** | 21.4 | 2.14 | +$36 | 0.89 |
| exchange | $1,554 | $232 | $127 | **+$92** | 18.0 | 1.80 | -$39 | 0.81 |
| self_pay_cash | $1,619 | $245 | $140 | **+$103** | 19.0 | 1.90 | -$26 | 0.86 |
| medicaid | $772 | $127 | $22 | **+$4** | 6.3 | 0.62 | -$144 | 0.43 |
| medicare | $952 | $103 | -$2 | **-$23** | never | never | -$168 | 0.02 |
| medicare_advantage | $946 | $103 | -$2 | **-$23** | never | never | -$167 | 0.37 |

- **Break-even.**
  - Commercial, exchange and cash pay even in a fully booked unit (u* > 1). Their
    break-even is 18 to 21 added minutes, against a 5-minute base.
  - The add-on earns 1.6 to 1.8 times the colonoscopy's revenue per minute.
  - Medicaid breaks even at 6.3 minutes or u = 0.62.
  - Medicare and Medicare Advantage lose money at any dT: 58100 at 50% with 88305
    packaged gives $103, which does not cover $105 of pathology processing, supplies
    and coordination.
- **States net-positive (base case):**
  - commercial 52 of 52 (range +$3 to +$1,669);
  - Medicaid 33 of 52;
  - Medicare 1;
  - Medicare Advantage 0.
  Under the room-cost framing: commercial 34, Medicaid 5.
- **Top 3 one-way drivers**, the same order for commercial and Medicaid:
  1. The 58100 collected share: -$80 to +$389 commercial; -$92 to +$101 Medicaid.
  2. The interhospital spread (p25 to p75) of the 58100 price: +$38 to +$470
     commercial.
  3. The 88305 collected share.
  Added minutes and u come next.
- **Day model.**
  - A 480-minute room fits 8 colonoscopies (55 min each) with 40 min of slack, so an
    EMB on every case (8 x 5 min) fits exactly. The day gains the add-ons' own
    contribution (+$1,618 commercial, +$175 Medicaid at f = 1).
  - At 12 minutes, a colonoscopy is lost once more than 41% of cases get an EMB.
    Commercial is still +$376 at f = 1; Medicaid is -$232.
- **Payer and patient.**
  - Combining costs commercial payers more than an office EMB ($370 vs $249), because
    hospital facility rates exceed office fees.
  - It saves Medicare, Medicare Advantage and Medicaid $59 to $83.
  - The patient avoids one visit. At u = 0.5 there are 4.5 displaced colonoscopies per
    100 add-ons, or 1.4 patient-days of delay per add-on.

**Bottom line.**
- **A:** from the hospital's side, placing an IUD at bariatric surgery is not worth it
  in any state or for any insurance type, unless the contract pays for the device. It
  is worth it only at a 340B-level device cost, or with a device carve-out paying
  close to the standalone rate. The OR minutes barely matter.
- **B:** the added minutes almost never displace a colonoscopy in practice. EMB at
  colonoscopy is worth it for commercial, exchange and cash patients in every state,
  roughly break-even for Medicaid, and a small loss under Medicare, where OPPS halves
  58100 and packages pathology.
- **Payers and patients** gain in both cases (one fewer visit). For case A the payer's
  gain is largely the hospital's device loss.

## Outputs (under `HPT_DATA_DIR/output/`)

| File | Contents |
|---|---|
| `addon_value_by_state.csv` | Every variant x state x insurance type, with:<br>- prices and their sources and fallback flags;<br>- collected shares, R_S, C_S, T_P, dT, u, m;<br>- the three net values (opportunity cost, room cost, standalone rate);<br>- dT*, u*, room-cost dT*, revenue per minute. |
| `addon_tornado.csv` | One-way results, national commercial and medicaid, for the DRG 621, DRG 620, CPT 43775, and 45378 variants. |
| `addon_day_capacity.csv` | Integer-capacity day model at base and high added minutes. |
| `addon_psa_summary.csv` | Mean and 95% interval of net value; P(worth it) under each framing. |
| `addon_system_perspective.csv` | Payer payments combined vs standalone, visits and time avoided, displaced cases and delay. |
| `addon_state_summary.csv` | Per variant x insurance type: states using their own prices, and states net-positive under each framing. |
| `figures/addon_threshold_{minutes,utilization}_{A,B}.png` | Net value vs dT and vs u, faceted by insurance type. |
| `figures/addon_tornado.png`, `figures/addon_day_capacity.png` | Tornado and day-model figures. |

Run: `Rscript analysis/12_addon_value.R` (national data: about 25 s, 0.5 GB peak memory). Set `ADDON_PSA_DRAWS` to
change the number of draws.

## Limitations

**What the prices measure.**
- HPT facility rates are prices, not costs. A negotiated rate is not the amount paid:
  it excludes patient cost sharing, denials, outlier payments, and contract terms
  (multiple-procedure rules, carve-outs) that the MRF does not show. The collected
  shares stand in for those terms.
- Professional fees are mostly absent from hospital MRFs. The hospital view uses
  facility fees only. The payer view uses PFS/PUF professional fees from CMS, not HPT.
- Bariatric prices may be case rates or DRG-based. CPT-coded 43775 "facility" rates
  are often partial (national Medicare $1,062 against $12,932 for DRG 621), so
  MS-DRG 621 is the base-case primary price and the CPT codes are sensitivities.
  A DRG price covers the whole stay, while the displaced-case margin applies to the
  OR slot; the model does not separate out bed-day capacity.

**Model structure.**
- Margin applies one share m to each payer's own rate, which implies variable cost
  scales with price. The displaced case is assumed to have the same payer as the
  add-on patient; with a real payer mix, displacement cost would be a mix-weighted
  margin.
- u is a judgment. Dexter's OR-management work suggests small increments rarely
  convert into lost cases. They show up as overtime or released time instead, which
  the room-cost framing and the day model capture.
- Contribution margin for colonoscopy has no direct source, and bariatric margin
  comes from one academic center (abstract only) plus 2010 all-surgery payer ratios.
- One device per variant. 340B hospitals (Liletta at about $50) change case A
  entirely: see the J7297 low value.

**Evidence gaps and scope.**
- The added minutes for an IUD at bariatric surgery are unsourced, and no study times
  IUD placement during an unrelated surgery. The bypass and sleeve slots are
  syntheses of published operative, in-room, and turnover times.
- Room cost per minute (Childers 2018) comes from California hospital ORs in FY2014,
  not endoscopy suites. The patient time cost comes from 2003-2010 ATUS data, with
  the dollar year inferred.
- PSA parameters are independent, and prices are held at their medians. The PSA shows
  parameter uncertainty, not interhospital price variation (the tornado shows that).
- Health outcomes are not modeled: a timelier IUD, an avoided unintended pregnancy,
  earlier endometrial diagnosis, or harm from a delayed colonoscopy or bariatric
  surgery.
- The 2014 CPI placeholder in emb_colonoscopy was corrected here (435.292) but not
  in that repository.
