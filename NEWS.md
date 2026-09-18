# NEWS

User-facing highlights. For the exhaustive technical log, see [`CHANGELOG.md`](CHANGELOG.md). For
methods and every cleaning rule, see [`docs/appendix.md`](docs/appendix.md).

## 2026-09-18 (the hospitals we could not see were mostly Medicaid)

**518 hospitals post a delivery price only in the other code system, and 355 of them deliver
babies.** We added the ability to read
those prices last night without knowing how many hospitals it would reach. The answer is 518, and
they are not a random sample: they are overwhelmingly hospitals in states whose Medicaid programs
pay that way, and they charge less than the hospitals we could already see.

**But their prices cannot be read as the same number.** Checking hospitals that publish in both code
systems showed the other system's price is about half the usual one for the same delivery. So the
lower average that appears when you include them is partly a different set of hospitals and partly a
different way of writing the price, and those two cannot be separated here. We are not quoting that
average anywhere.

**The cesarean premium does not budge.** A cesarean still costs 1.42 times a vaginal delivery at the
same hospital, on a Medicaid sample half again as large. A ratio that lands in exactly the same place
on a different set of hospitals is the best sign yet that it reflects how contracts are written.

**A mistake worth naming.** The two versions of the childbirth analysis wrote the same filenames, so
the second run quietly replaced the first. That made a coverage gain look like a 14% price drop until
we checked. They now write separate files and can be compared directly.

## 2026-09-17 (reaching the hospitals that price births a different way)

**Some hospitals were invisible in the birth prices.** Medicaid programs in several states pay by
a different grouper, APR-DRG, and hospitals there post delivery prices only that way. Our rules
match a code only when the hospital says which code system it used, which is what keeps an
APR-DRG 742 out of the MS-DRG 742 results, and it also meant these hospitals had no delivery
price at all.

**They can now be included, carefully and separately.** The two delivery APR-DRGs at their
uncomplicated severity can stand in for the usual codes at a hospital that posts nothing else.
Such a price never replaces a real one, every row is labelled with where it came from, and the
headline numbers stay as they were. Turquoise Health treats these codes the same way.

**How many hospitals this adds is not known yet.** Measuring it means re-reading the source data,
which needs the external drive. Until then the option is off by default.

## 2026-09-14 (what a birth costs, and the midwifery question, designed properly)

**What hospitals charge for a birth.** For an uncomplicated vaginal delivery, commercial insurers
pay a median of $8,584, 1.72 times what Medicare's standard formula would pay the same hospital.
Medicaid pays $5,396, 1.08 times Medicare. A cesarean runs $12,465 commercial and $7,643 Medicaid.
This covers 1,602 hospitals that deliver babies.

**The cesarean always costs about 42% more, and it looks set by formula.** Inside a hospital, the
cesarean price is 1.42 times the vaginal price for both commercial and Medicaid, and higher at 96%
of hospitals. That is exactly the ratio of Medicare's own weights for the two DRGs, which suggests
most contracts are written as multiples of Medicare's weights. We call the gap a facility price
differential, not savings: it leaves out physician fees, later care, and outcomes.

**Per-diem contracts are now priced as a stay.** Some hospitals price inpatient care per day, so
they looked several times cheaper than hospitals paid per case. Those rates are now multiplied by
Medicare's typical length of stay, unless they are already stay-sized. This moved the national
commercial price for non-cancer uterine surgery (DRG 742) from $24,361 to $25,133 and barely
touched anything else.

**Midwives and hospital prices: no link.** Hospitals surrounded by more midwives do not charge
differently for births, and their cesarean premium is the same. That was always the weaker
question: prices are contracts, not how often cesareans happen.

**The better question now has a locked design.** Do places with more midwives have fewer
first-time, low-risk cesareans (the NTSV rate)? What would that difference mean for facility
prices? The plan is in `docs/childbirth_analytic_spec.md`, and the code is written and tested. The
county birth data can only come from CDC WONDER's website, so the last step is ten manual exports.
The analysis stops and prints the exact query for any that are missing.

**A mistake caught in the midwife counts.** The midwife list covers 40 states. Hospitals near the
other 11 (including New Jersey, Delaware, and Rhode Island) were counted as having no midwives
across the border. They are now left out instead of miscounted.

## 2026-09-13 (the code goes public; the data stays private)

**The pipeline's code now has a public home.** github.com/mufflyt/hpt_prices_public holds the code,
tests, tools, and the guide to downloading the Trilliant data, and its tests run automatically on
every change. Everything built from the data stays in this private repository: prices, figures,
results, and the documents that quote them. Trilliant's terms do not allow that material to be
redistributed. One command, `tools/export_public.sh`, rebuilds the public copy, and it refuses to
publish if a price read from Trilliant would slip through. To make that possible, the handful of
real prices that sat in the code (the known answers the validation checks against, and a few
examples in comments) moved into a private file.

**A bug that would have stopped the pipeline on your other computer.** Pointing the pipeline at a
data folder with `HPT_DATA_DIR` did not actually stop it from looking for the external drive, so on
any machine without that drive it failed at the first step. The public copy's first automated test
run caught it; it is fixed, and a test keeps it fixed.

**The helper scripts are in the repository now.** The scripts that downloaded and unpacked the
Trilliant file, generated the test fixtures, and built the private-equity system list were written
during the build and lived only in a temporary folder. They are now in `tools/`, with the download
walked through in `docs/trilliant_download.md`, so the whole pipeline can be rebuilt on another
machine.

## 2026-09-13 (cleaner prices, maps, and a harder look at the figures)

**IUD insertion was three products wearing one code.** A hospital can list CPT 58300 as a clinic
insertion (a couple of hundred dollars), as an operating-room case line (tens of thousands in gross
charges), or as an outpatient-surgery case rate priced for the whole surgical encounter. Mixing them
made state IUD prices swing from $70 to $4,000. Two rules now keep only the insertion itself: OR case
lines are recognized by a gross charge far above the code's typical one, and case-rate rows are
dropped for the two office procedures (endometrial biopsy and IUD insertion). The national commercial
facility price for IUD insertion fell from $551 to $417. One thing no rule can fix: HCA lists 58300
only at surgical-case prices, with no gross charge to tell the lines apart.

**Physician fees were hiding in facility prices.** Most hospital files leave the billing class
blank, and blank used to mean "facility". Unlabeled physician fees for colonoscopy, around $300,
were being averaged with facility fees near $1,000. Blank rows whose charge is at physician-fee level
are now set aside. The national commercial facility price for colonoscopy rose from $2,070 to $2,220,
and the Medicare facility median now matches the official Medicare outpatient rate (1.008x). Iowa,
South Dakota, and West Virginia no longer show commercial colonoscopy prices below Medicare.

**Two payers and three "states" were mislabelled.** ConnectiCare and Buckeye Commercial are
commercial insurers whose names matched Medicaid plan brands; Connecticut's $5,657 "Medicaid"
colonoscopy price came from them. Trilliant's state field sometimes held "PO" (from "PO Box") or a
street quadrant such as "NW", which had created three states that do not exist.

**What the cleaning changed, and what it did not.** `docs/cleanup_impact.md` compares every
headline output against a rebuild of the pre-cleanup code from the same inputs. The cleaning moved
prices (colonoscopy commercial +7%, IUD commercial -24%) and narrowed the state spread (commercial
p90/p10 2.69 to 2.10). No conclusion changed direction. Adding an endometrial biopsy to a commercial
colonoscopy is still worth it, but by less: $115 per add-on instead of $149, with a break-even of 16
added minutes instead of 21 (the base case is 5). Adding an IUD to bariatric surgery still loses money
for every payer, by the same amount.

**Colonoscopy prices mapped against Medicare.** Each hospital's price is divided by what Medicare's
outpatient system would pay that same hospital, adjusted for local wages. Medicare Advantage pays
almost exactly Medicare everywhere (national 1.00x, nearly identical across states). Commercial
insurers pay 2.3x Medicare nationally, and state medians differ about twofold. Medicaid pays 0.78x
nationally and varies most, about 4.6-fold across states. Still, state explains only a fifth of the
difference between hospitals: most of the variation is between hospitals in the same state. Giving
each health system one vote per state keeps this pattern, but a few state rankings (West Virginia,
North Carolina, Vermont, Kansas, Georgia, and Connecticut's Medicare Advantage outlier) turn out to be
one large system rather than a state effect.

**The figures were reviewed and revised.**

- The add-on figures now call price-transparency rates what they are, a proxy for payment, and the
  day-capacity figure counts whole cases, marking the case where the day's slack runs out and a
  primary case is displaced. The figure revision itself changed no numbers: on the cleaned data,
  adding an endometrial biopsy to a commercial colonoscopy gains about $115 per add-on, and adding an
  IUD to bariatric surgery loses money for every payer.
- The private-equity comparison got honest confidence intervals. Clustering by health system with a
  wild cluster bootstrap shows that strict private-equity ownership rests on 1 to 3 health systems,
  so those estimates are descriptive, not evidence. Of 50 estimates with enough systems for an
  interval, 4 remain significant (12 did before).
- The state ranking chart is now a landscape figure with one panel per Census region and commercial
  and Medicaid on the same row, readable at screen size.

**For the endometrial biopsy manuscript** (emb_colonoscopy), the payer multipliers are unchanged
except commercial D&C, which moved from 1.666 to 1.626.

## 2026-09-13 (D&C, hysteroscopy, and a crosswalk bug)

D&C (58120) and hysteroscopy with sampling (58558) joined the codebook, and a new step computes
payer-to-Medicare ratios within each hospital. Those ratios replaced the flat, provisional payer
multipliers in the emb_colonoscopy model (Medicaid 0.70x, commercial 1.75x) with measured ones.

A crosswalk bug was found and fixed: one billing vendor hosts reports for 516 hospitals at URLs that
differ only in the query string, and dropping the query string had linked about 300 hospitals to
other hospitals' files. National medians barely moved; the affected hospitals did.

## 2026-09-13 (the national run)

The full Trilliant snapshot (80 GB, verified byte for byte against the server's checksum) now runs
end to end: 7.2 million rate rows for the target codes from 4,923 files covering 7,916 facilities.
Known answers from Denver Health and HCA Houston Healthcare Southeast reproduce to the cent, Medicare
medians land within a few percent of the official Medicare rates, and payer types agree with
Trilliant's own labels 93% of the time. The database build went from 35 minutes to 97 seconds.

## 2026-09-12 (database, medians, and the add-on question)

The extracted prices became a DuckDB database with state-by-insurance medians for colonoscopy,
endometrial biopsy, IUD insertion, and bariatric surgery, a 32-check validation suite, and an
economic model asking whether an add-on procedure is worth the room time it takes from the next
primary case.

## 2026-09-12 (first build)

The project started: a codebook of colonoscopy, endometrial biopsy, IUD, vaginal hysterectomy, and
uterine-surgery DRG codes checked against the 2026 Medicare fee schedule; an extract from Trilliant
Health's consolidated copy of every hospital's price file; a crosswalk to CMS hospital IDs; and a
crawler for the hospitals Trilliant is missing.
