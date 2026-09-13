# NEWS

User-facing highlights. For the exhaustive technical log, see [`CHANGELOG.md`](CHANGELOG.md). For
methods and every cleaning rule, see [`docs/appendix.md`](docs/appendix.md).

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
