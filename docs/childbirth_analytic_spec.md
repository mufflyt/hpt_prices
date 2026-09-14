# Childbirth analytic specification (design lock, draft)

Status: design only. This file makes no empirical claims. The code on
`feat/childbirth-prices` (prices, per-diem conversion, midwifery presence)
is scaffolding, and its outputs are exploratory. There are no CDC-derived
numbers in the repository.

**Causal chain under study:** midwifery supply → NTSV cesarean utilization
→ implied facility price consequences. Prices enter only in the last step,
as an accounting translation.

## 1. Primary exposure

**Midwife supply per 1,000 births.** The numerator is active AMCB-certified
midwives (CNM and CM) from the NPI-linked roster
(`tracked_roster_active_primary_linked.csv`), placed at their NPPES practice
ZIP. The count covers midwives within 30 miles of the unit's
population-weighted centroid. The denominator is NVSS resident births in the
same catchment. Sensitivity radii are 15 and 60 miles. Secondary exposures:
a CABC-accredited birth center within 30 miles, and distance to the nearest
one.

**Excluded as an exposure: the CNM-attended share of births.** Birth
certificates name the delivering attendant, and cesareans are attended by
physicians. A higher CNM share therefore lowers the cesarean rate by
construction. That share is a descriptor or mediator, not an exposure.

## 2. Outcome

**NTSV cesarean rate (the NCHS "low-risk cesarean" rate).**
- Numerator: cesarean deliveries.
- Denominator: live births that are first births (Live Birth Order 1),
  singleton, at 37 weeks or more by obstetric estimate, and cephalic.
- Births with an unknown delivery method are excluded from the denominator.

The total cesarean rate is reported only as a secondary outcome, because it
mixes in repeat cesareans and case mix.

## 3. Geography: county of mother's residence

**Hospital level is not possible.** No public national source gives
hospital-level NTSV. CMS PC-02 is "Not Available" for every hospital.

**Occurrence geography is not possible.** Neither public data source reports
where births occurred:
- The NCHS public-use microdata "does not include geographic detail (e.g.,
  state or county of birth)" (2023 User Guide).
- CDC WONDER (Natality 2016-2024 expanded) offers only the mother's legal
  residence. It covers the nation, regions, divisions, states, and counties
  of 100,000+ population; smaller counties are pooled by state and cells of
  1-9 are suppressed.
- Occurrence and hospital identifiers exist only in restricted NCHS files,
  which require an application.

**HRRs cannot be built.** WONDER has no ZIP field.

**Why residence is the right geography, not just the available one.**
- The question is population-level: do people who live near more midwives
  have fewer low-risk first-birth cesareans, wherever they deliver? A
  residence-based rate answers exactly that.
- Occurrence rates at tertiary centers are distorted by referral inflow,
  though NTSV restriction limits this.

**Coverage and sensitivity.**
- Primary unit: WONDER-identified counties.
- Complete-coverage sensitivity: state of residence (51 units).
- Pooled "Unidentified Counties" rows are kept for state totals but are
  never modeled as counties.
- Connecticut 2022-2024 falls entirely into pooled rows (the planning-region
  break) and is analyzed at state level only.

**Known limitation.** Excluding small counties removes most rural counties.
Rural findings rest on the state analysis.

## 4. Unit of analysis

**Utilization model.** County of residence, with NTSV births pooled over
the study years:
- Binomial model (quasi-binomial or beta-binomial if overdispersed),
  weighted by NTSV births.
- State fixed effects.
- Wild cluster restricted bootstrap by state, using the existing
  `wild_cluster_bootstrap()`.

**Price step.** Hospital, only to describe the local facility price
differential: the negotiated price for DRG 788 (cesarean) minus DRG 807
(vaginal), by payer, averaged over L&D hospitals serving the county. There is
no hospital-level causal model.

## 5. Year alignment

| Input | Period |
|---|---|
| Prices (Trilliant snapshot 2026-07-21) | Rates posted 2025-2026 |
| Midwife roster | Current AMCB and NPPES |
| Natality | Pooled 2022-2024 |

- Pooling 2022-2024 stabilizes county rates and avoids 2020-2021.
- The WONDER release date is recorded at extraction.
- Stated assumption: midwife supply and prices are slow-moving, so a 1-3
  year lag is a cross-sectional approximation.
- A 2016-2019 outcome serves as a placebo or pre-period check. Current
  supply should not "predict" the past more strongly than the present.

## 6. Guarding against ecological overinterpretation

Findings may not be stated at the level of a person or a hospital:
- Not as "midwife care lowers a woman's cesarean risk".
- Not as "hospitals near midwives price lower".

**Supply may be endogenous.** Midwives cluster where hospitals employ them,
where midwife-led units exist, and in urban areas. Hospital-employed CNMs are
counted in local supply.

**Robustness checks:**
- MAUP: radii of 15, 30, and 60 miles, and county versus state units.
- The placebo outcome from section 5.
- A negative-control outcome: preterm birth share. Midwife supply should
  have little effect on it; an association would point to confounding.

**The price step is arithmetic, not an estimate.** Implied facility price
consequence = estimated change in NTSV cesarean rate x NTSV births x local
facility price differential. It is labeled the "implied facility price
differential". It is never called savings or value: it ignores professional
fees, downstream care, repeat cesareans, and outcomes.

## 7. Confounders

| Confounder | Source | Status |
|---|---|---|
| Parity | NTSV definition (first births only) | Handled by design |
| Maternal age | WONDER Age of Mother, direct age standardization | Available (query) |
| Race and Hispanic origin | WONDER Mother's Single Race 6, Hispanic Origin | Available (query); suppression risk |
| Payer mix | WONDER Source of Payment for Delivery; hospital Medicaid days from HCRIS | County available (query); HCRIS not loaded |
| Clinical risk | WONDER pre-pregnancy BMI, pre-pregnancy and gestational diabetes and hypertension | Available (query) |
| Rurality | RUCC 2023 | Loaded |
| State | Fixed effects | Available |
| Birth volume | NVSS resident births | Loaded |
| Regional obstetric supply | L&D hospitals within the radius (CMS SM-7) | Loaded; not yet aggregated to county |
| Obstetrician supply | NPPES taxonomy 207V or AHRF | Not built |
| MFM supply | NPPES taxonomy 207VM0101X | Not built |
| System ownership, PE | AHRQ CHSP, `pe_hospital_systems` | Loaded (hospital level) |
| Hospital type | CMS roster | Loaded (hospital level) |
| Teaching status, bed size | HCRIS (IME resident FTEs, beds) | Not built |

The hospital attributes (system ownership, hospital type, teaching status,
bed size) enter only through a county's hospitals as descriptors.

**Missing entirely:**
- hospital-level NTSV and case mix;
- occurrence-based rates;
- small-county rates;
- level of maternal care.

## Natality source decision and the exact WONDER query

**No reproducible download exists.**
- The public-use microdata lacks geography.
- The WONDER API rejects sub-national natality ("Only national data are
  available for this dataset when using the WONDER web service").
- There is no existing repository extract. The midwifery repo holds only
  CNM-attended births by county.

So a manual WONDER web export is required, archived with its query URL, the
Notes block, and a sha256 hash. The query is the same for every export;
only the "Group Results By" choice changes:

- **Dataset:** Natality, 2016-2024 expanded.
- **Group Results By:** County of Residence, then Delivery Method.
  - State of Residence instead, for the state file.
  - Add Age of Mother or Payment Source for the stratified files.
- **Years:** 2022, 2023, 2024. A second export covers 2016-2019 for the
  placebo.
- **Live Birth Order:** 1.
- **Plurality:** Single.
- **OE Gestational Age:** every category at 37 weeks or later (term, late term, post
  term).
- **Fetal Presentation:** Cephalic.
- **Delivery Method:** all values (unknown is dropped in code).
- **Other options:** show totals, show zero values, show suppressed values;
  export as tab-delimited.

`load_wonder_delivery_by_county()` already reads this layout.
