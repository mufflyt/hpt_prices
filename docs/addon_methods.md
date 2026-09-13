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
- **Payment proxy.** Every payment in the model is an HPT negotiated facility rate used
  as a proxy for payment. It is not a claims or remittance amount.
- **Expected paid share.** An HPT negotiated rate is the standalone price of a code.
  When the add-on is billed with the primary, contract terms (multiple-procedure
  rules, packaging, carve-outs) mean only part of it is paid. Define:

  R_S = f_proc x rate(58300 or 58100) + f_item x rate(device or 88305)

  The paid shares `f` (`pay_frac_*` parameters) are assumptions about those terms.
  They default by case and component, and some insurance types have their own values:
  - Medicare inpatient DRG pays nothing extra for an IUD. The ICD-10-PCS insertion
    codes do not affect DRG 619-621, and 58300 and the J-codes are non-covered
    (status N / E1).
  - Medicare OPPS pays 58100 at 50%. It is a status T procedure ranked below 45378,
    so the multiple-procedure discount applies. 88305 (status Q1) is packaged.
- **Full-rate scenario (upper bound).** R_S_listed is the add-on paid its full
  standalone negotiated rates (f = 1). It changes only the add-on's revenue; the
  displaced case is still charged its contribution margin. It is blanked
  (`addon_mask_full_rate()`) where the payer does not cover the add-on: Medicare does
  not cover 58300 or the IUD J-codes (OPPS Addendum B status E1, read from
  `load_opps_rates()`), and Medicare Advantage follows Medicare coverage, so a posted
  Medicare rate for them is not a payment anyone makes. The expected-share framing
  already sets those payments to 0.

### Hospital net value per add-on

With T_P = room minutes per primary case including turnover, dT = added minutes,
u = probability the added minutes displace otherwise productive room time (they would
otherwise have held another primary case), and m = contribution-margin share of the
primary negotiated rate:

```
C_S  = R_S - variable costs of the add-on
       (A: device + supplies + anesthetic drug increment + coordination;
        B: pathology processing + supplies + anesthetic drug increment + coordination)

displaced-case framing:    net = C_S - u * (dT / T_P) * m * R_P
full-rate scenario:        the same with C_S at the full standalone rates (upper bound)
room-cost framing:         net = C_S - dT * (direct room cost + anesthesia cost per minute)

break-even added minutes   dT* = C_S * T_P / (u * m * R_P)
break-even utilization     u*  = C_S / ((dT / T_P) * m * R_P)     (u* > 1: worth it even fully booked)
room-cost break-even       dT*_room = C_S / cost per minute
revenue per minute ratio   (R_S / dT) / (R_P / T_P)
```

- **Two framings.** They are alternatives, never added together: displacement
  already prices the minutes.
  - The displaced-case (opportunity-cost) framing charges the foregone contribution
    margin of the displaced case, m x R_P, not its whole payment.
  - The room-cost framing ignores displacement and charges the minutes at an
    accounting cost: Childers 2018's direct cost (staff salaries and supplies,
    excluding indirect overhead), treated as fully variable. Staff are usually paid
    for the whole block, so this overstates the short-run incremental cost of a few
    added minutes; read it as an accounting room-cost framing, not a marginal cost.
- **Figure labels.** Blue: displaced-case margin, add-on paid its expected share of the
  negotiated rate (the base case). Green: displaced-case margin, add-on paid its full
  negotiated rate (upper bound). Orange: accounting room cost per minute, add-on paid
  its expected share.
- **When C_S <= 0**, no dT or u makes the add-on pay. dT* and u* are then reported as
  NA.

### Integer capacity (one room day)

A block of B minutes holds n = floor(B / T_P) primary cases. A single day has a whole
number of cases, so `addon_day_value()` steps through k = 0..n, the number of the day's
scheduled cases that get the add-on. With k add-ons the block holds the largest c <= n
with c x T_P + min(k, c) x dT <= B (`addon_primary_cases_with_addons()`); the displaced
case is one without an add-on, so min(k, c) add-ons are still done. It reports day
revenue and contribution against k = 0; the figure labels each drop "1 primary case
displaced".

`addon_free_addons_per_day()` counts the add-ons that fit in the end-of-day slack
before a case is lost. It shows that a few minutes often cost nothing until k x dT uses
up the slack. `addon_cases_per_day()` keeps the continuous form, floor(B / (T_P + f x
dT)), as the average over many days in which a share f of cases get the add-on.

### Payer and patient view

Payer, combined setting:
- the expected add-on facility payment R_S;
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
  from the base case. An example is the device's paid share for commercial bariatric
  cases (0, mode 0.1, 1).
- The tornado figure labels each bar with a plain-language name and the range tested
  (`addon_tornado_labels()`); `addon_tornado.csv` keeps the parameter name beside it.

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
- Figures and tables below are from the run after the 2026-09-13 line-type cleanup
  (case lines, office-procedure case rates, inferred fee type, ConnectiCare and
  Buckeye payer rules).
- Hospitals behind the national medians:
  - 45378: 2,312 (commercial) to 569 (Medicare);
  - DRG 621: 1,969 (commercial) to 554 (Medicare);
  - 58100: 1,989 commercial;
  - 58300: 1,849 commercial;
  - J7298: 1,790 commercial;
  - 88305: 3,030 commercial.
- 55 state-level units in the medians (50 states, DC, PR, and three unrecognized
  state codes, NW, PO, SE, that come from facility records). In the base variants,
  most state rows use their own state's prices:
  - 45378 commercial: 48 of 55 use state prices for all three codes;
  - DRG 621 commercial: 48 of 55.
  - The rest fall back to national and are flagged (`primary_fallback`,
    `secondary_fallback`).

**Case A: IUD + Mirena at bariatric surgery, priced at MS-DRG 621.** Values are 2026
USD per add-on.

| Insurance | R_P (DRG 621) | R_S (expected paid share) | C_S | Displacement cost | Net value | Room-cost framing | Full-rate scenario | PSA P(worth it) |
|---|---|---|---|---|---|---|---|---|
| commercial | $21,154 | $211 | -$1,059 | $175 | **-$1,234** | -$1,390 | +$1,081 | 0.15 |
| exchange | $19,439 | $160 | -$1,110 | $161 | **-$1,271** | -$1,442 | +$669 | 0.04 |
| medicare | $12,907 | $0 | -$1,270 | $107 | **-$1,376** | -$1,601 | not covered | 0 |
| medicare_advantage | $12,804 | $0 | -$1,270 | $106 | **-$1,376** | -$1,601 | not covered | 0 |
| medicaid | $12,436 | $0 | -$1,270 | $103 | **-$1,373** | -$1,601 | -$5 | 0 |
| self_pay_cash | $22,314 | $198 | -$1,071 | $185 | **-$1,256** | -$1,403 | +$795 | 0.11 |

- **Break-even.** C_S is negative for every insurance type, so no added-minutes value
  (dT*) or utilization (u*) makes the add-on pay. OR time is not the problem.
- **Revenue per minute.** The add-on earns 0 to 0.14 times the DRG case's revenue per
  minute.
- **Where the loss comes from.** The device costs about $1,218 (Mirena WAC, 2026
  dollars). Traditional Medicare never pays for it, and it is packaged in most DRG and
  case-rate contracts. Displacement adds only $100 to $190 per add-on.
- **Sensitivity variants** are all negative nationally for every insurance type:
  - DRG 620 (with CC): -$1,247 commercial, -$1,380 Medicaid.
  - CPT 43775: -$1,139 commercial, -$1,284 Medicaid.
- **States.** 0 of 55 states are net-positive for commercial or Medicaid, in any case
  A variant. In the full-rate scenario, 52 states are positive for commercial and 24
  for Medicaid (not computed for Medicare or Medicare Advantage).
- **Top 3 one-way drivers (commercial):**
  1. The device's paid share: -$1,445 to +$665. This is the only parameter that can
     flip the sign.
  2. Utilization u (0 to 0.75): -$1,059 to -$1,584.
  3. Device acquisition cost: -$1,051 to -$1,356.
  For Medicaid the order is the same: device carve-out (up to -$158), u, device cost.
- **PSA** (5,000 draws): P(worth it) is 0.15 commercial, 0.04 exchange, 0.11 cash, 0.20
  workers' comp, and 0 for Medicaid, Medicare and Medicare Advantage.
  - It is never above 0.2 for any insurance type at the DRG 621 price.
- **Day model** (one 480-minute OR day, national commercial).
  - It fits 3 bariatric cases (145 min each) with 45 min of slack. With 10-minute
    IUDs, all 3 cases can get one without losing a case; the day loses only the
    add-ons' own contribution (-$3,176 at k = 3).
  - With 20-minute IUDs, the third IUD displaces a bariatric case: the day ends with 2
    cases and 2 IUDs (-$12,271 at k = 3).
- **Payer and patient.** A standalone office insertion costs the payer about $1,417
  (insertion $105.55, device $1,218, visit $93.47). Combined, the payer pays $44 to
  $255 ($44 when the add-on is fully packaged), so its "saving" is $1,163 to $1,373.
  - That saving is mostly the device the hospital absorbs: a cost shift, not a
    resource saving.
  - The patient avoids one visit ($65.63 of time).
  - At u = 0.25 there are 1.7 displaced bariatric cases per 100 add-ons, or 0.52
    patient-days of delay per add-on.

**Case B: EMB + pathology at colonoscopy (45378).** Values are 2026 USD per add-on.

| Insurance | R_P | R_S (expected paid share) | C_S | Net value | dT* (min) | u* | Room-cost framing | Full-rate scenario | PSA P(worth it) |
|---|---|---|---|---|---|---|---|---|---|
| commercial | $2,220 | $270 | $165 | **+$115** | 16.3 | 1.63 | -$1 | +$384 | 0.83 |
| exchange | $1,723 | $226 | $121 | **+$82** | 15.5 | 1.55 | -$45 | +$308 | 0.78 |
| self_pay_cash | $1,993 | $241 | $136 | **+$91** | 15.0 | 1.50 | -$30 | +$331 | 0.81 |
| medicaid | $753 | $112 | $7 | **-$10** | 2.1 | 0.21 | -$159 | +$102 | 0.31 |
| medicare | $958 | $101 | -$4 | **-$26** | never | never | -$170 | +$130 | 0.02 |
| medicare_advantage | $954 | $102 | -$2 | **-$24** | never | never | -$168 | +$134 | 0.36 |

- **Break-even.**
  - Commercial, exchange and cash pay even in a fully booked unit (u* > 1). Their
    break-even is 15 to 16 added minutes, against a 5-minute base.
  - The add-on earns 1.2 to 1.6 times the colonoscopy's revenue per minute.
  - Medicaid is just below break-even: it breaks even at 2.1 minutes or u = 0.21.
  - Medicare and Medicare Advantage lose money at any dT: 58100 at 50% with 88305
    packaged gives about $101, which does not cover $105 of pathology processing,
    supplies and coordination.
- **States net-positive (base case):**
  - commercial 51 of 55 (range -$42 to +$904);
  - Medicaid 24 of 55;
  - Medicare 0;
  - Medicare Advantage 0.
  Under the room-cost framing: commercial 27, Medicaid 6.
- **Top 3 one-way drivers**, the same order for commercial and Medicaid:
  1. The 58100 paid share: -$83 to +$312 commercial; -$92 to +$72 Medicaid.
  2. The interhospital spread (p25 to p75) of the 58100 price: +$24 to +$351
     commercial.
  3. The 88305 paid share.
  Added minutes and u come next.
- **Day model** (one 480-minute endoscopy day, national).
  - It fits 8 colonoscopies (55 min each) with 40 min of slack, so a 5-minute EMB on
    every case fits exactly. The day gains the add-ons' own contribution (+$1,320
    commercial, +$58 Medicaid at k = 8).
  - With 12-minute EMBs, the fourth EMB displaces a colonoscopy (commercial +$495 at
    k = 3 falls to -$450 at k = 4, and recovers to +$45 by k = 7; Medicaid ends at
    -$326).
- **Payer and patient.**
  - Combining costs commercial payers more than an office EMB ($333 vs $249), because
    hospital facility rates exceed office fees.
  - It saves Medicare, Medicare Advantage and Medicaid $74 to $85.
  - The patient avoids one visit. At u = 0.5 there are 4.5 displaced colonoscopies per
    100 add-ons, or 1.4 patient-days of delay per add-on.

**Bottom line.**
- **A:** from the hospital's side, placing an IUD at bariatric surgery is not worth it
  in any state or for any insurance type, unless the contract pays for the device. It
  is worth it only at a 340B-level device cost, or with a device carve-out paying
  close to the standalone rate. The OR minutes barely matter.
- **B:** the added minutes almost never displace a colonoscopy in practice. EMB at
  colonoscopy is worth it for commercial, exchange and cash patients in nearly every
  state, roughly break-even for Medicaid, and a small loss under Medicare, where OPPS
  halves 58100 and packages pathology.
- **Payers and patients** gain in both cases (one fewer visit). For case A the payer's
  gain is largely the hospital's device loss.

## Outputs (under `HPT_DATA_DIR/output/`)

| File | Contents |
|---|---|
| `addon_value_by_state.csv` | Every variant x state x insurance type, with:<br>- prices and their sources and fallback flags;<br>- paid shares, R_S, C_S, T_P, dT, u, m;<br>- the three net values (displaced-case, room cost, full rate; full rate blank where Medicare does not cover the add-on);<br>- dT*, u*, room-cost dT*, revenue per minute. |
| `addon_tornado.csv` | One-way results, national commercial and medicaid, for the DRG 621, DRG 620, CPT 43775, and 45378 variants, with a plain-language `label` and range. |
| `addon_day_capacity.csv` | One-room-day model, k = 0..n add-on cases, at base and high added minutes. |
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
  (multiple-procedure rules, carve-outs) that the MRF does not show. The paid shares
  stand in for those terms, and the rates serve only as a payment proxy.
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
- The room cost per minute is an accounting direct cost treated as fully variable,
  so the room-cost framing overstates the short-run incremental cost when staff are
  already paid for the block.
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
