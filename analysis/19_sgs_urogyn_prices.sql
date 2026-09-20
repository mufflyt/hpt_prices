-- SGS abstract: negotiated-price variation for prolapse and incontinence surgery.
-- Template run by analysis/19_sgs_urogyn_prices.R, which replaces {{OUT}} with the
-- output directory (trailing slash included) and executes against the lake's
-- catalog.duckdb with the DuckLake attached read-only.
--
-- Queries current_charges (hospital MRF data) only; no Trilliant directory tables.

CREATE TEMP VIEW uro AS
SELECT
  canonical_id,
  hospital_state,
  cpt,
  avg_negotiated_rate,
  min_negotiated_rate,
  max_negotiated_rate,
  discounted_cash,
  payer_count,
  replace(lower(coalesce(enriched_billing_class, billing_class, 'unknown')), '"', '') AS bclass,
  replace(lower(coalesce(enriched_setting, setting, 'unknown')), '"', '')             AS setting
FROM current_charges
WHERE cpt IN ('57288','57282','57283','57425','57120','57260','57265');

-- Attrition ledger (reported in the abstract's methods)
COPY (
  SELECT * FROM (
    SELECT 1 AS step, 'all rows, 7 CPTs' AS stage, COUNT(*) AS rows, COUNT(DISTINCT canonical_id) AS hospitals FROM uro
    UNION ALL
    SELECT 2, 'has negotiated rate', COUNT(*), COUNT(DISTINCT canonical_id) FROM uro WHERE avg_negotiated_rate IS NOT NULL
    UNION ALL
    SELECT 3, 'rate in $100-$200k sanity window', COUNT(*), COUNT(DISTINCT canonical_id)
      FROM uro WHERE avg_negotiated_rate BETWEEN 100 AND 200000
    UNION ALL
    SELECT 4, 'excl. professional-fee rows', COUNT(*), COUNT(DISTINCT canonical_id)
      FROM uro WHERE avg_negotiated_rate BETWEEN 100 AND 200000 AND bclass <> 'professional'
    UNION ALL
    SELECT 5, 'excl. inpatient-only rows (primary analytic set)', COUNT(*), COUNT(DISTINCT canonical_id)
      FROM uro WHERE avg_negotiated_rate BETWEEN 100 AND 200000 AND bclass <> 'professional' AND setting <> 'inpatient'
    UNION ALL
    SELECT 6, 'sensitivity: facility-class only', COUNT(*), COUNT(DISTINCT canonical_id)
      FROM uro WHERE avg_negotiated_rate BETWEEN 100 AND 200000 AND bclass = 'facility' AND setting <> 'inpatient'
  ) ORDER BY step
) TO '{{OUT}}attrition.csv' (HEADER);

CREATE TEMP VIEW primary_set AS
SELECT * FROM uro
WHERE avg_negotiated_rate BETWEEN 100 AND 200000
  AND bclass <> 'professional' AND setting <> 'inpatient';

-- Per-hospital median negotiated rate per CPT (the analytic unit)
CREATE TEMP TABLE hosp_rate AS
SELECT cpt, canonical_id, any_value(hospital_state) AS hospital_state,
       MEDIAN(avg_negotiated_rate) AS rate,
       MEDIAN(discounted_cash) FILTER (WHERE discounted_cash BETWEEN 100 AND 200000) AS cash
FROM primary_set GROUP BY cpt, canonical_id;

-- Primary result: cross-hospital spread per CPT
COPY (
  SELECT cpt, COUNT(*) AS hospitals,
    ROUND(QUANTILE_CONT(rate,0.10)) AS p10,
    ROUND(QUANTILE_CONT(rate,0.25)) AS p25,
    ROUND(QUANTILE_CONT(rate,0.50)) AS p50,
    ROUND(QUANTILE_CONT(rate,0.75)) AS p75,
    ROUND(QUANTILE_CONT(rate,0.90)) AS p90,
    ROUND(QUANTILE_CONT(rate,0.90)/QUANTILE_CONT(rate,0.10),1) AS ratio_90_10
  FROM hosp_rate GROUP BY cpt ORDER BY p50
) TO '{{OUT}}primary_spread.csv' (HEADER);

-- Sensitivity: facility billing class only
COPY (
  WITH hosp AS (
    SELECT cpt, canonical_id, MEDIAN(avg_negotiated_rate) AS rate
    FROM uro
    WHERE avg_negotiated_rate BETWEEN 100 AND 200000
      AND bclass = 'facility' AND setting <> 'inpatient'
    GROUP BY cpt, canonical_id)
  SELECT cpt, COUNT(*) AS hospitals, ROUND(QUANTILE_CONT(rate,0.50)) AS p50,
         ROUND(QUANTILE_CONT(rate,0.90)/QUANTILE_CONT(rate,0.10),1) AS ratio_90_10
  FROM hosp GROUP BY cpt ORDER BY p50
) TO '{{OUT}}facility_only_sensitivity.csv' (HEADER);

-- Within-hospital payer spread
COPY (
  WITH payer AS (
    SELECT cpt, canonical_id,
           MEDIAN(max_negotiated_rate / min_negotiated_rate) AS payer_ratio
    FROM primary_set
    WHERE min_negotiated_rate >= 100 AND max_negotiated_rate <= 200000
      AND max_negotiated_rate >= min_negotiated_rate AND payer_count >= 2
    GROUP BY cpt, canonical_id)
  SELECT cpt, COUNT(*) AS hospitals,
         ROUND(QUANTILE_CONT(payer_ratio,0.50),1) AS median_within_hosp_ratio,
         ROUND(QUANTILE_CONT(payer_ratio,0.75),1) AS p75_within_hosp_ratio
  FROM payer GROUP BY cpt ORDER BY cpt
) TO '{{OUT}}payer_spread.csv' (HEADER);

-- Cash vs negotiated (hospitals reporting both)
COPY (
  SELECT cpt, COUNT(*) AS hospitals_both,
         ROUND(MEDIAN(cash)) AS med_cash, ROUND(MEDIAN(rate)) AS med_negotiated,
         ROUND(MEDIAN(cash / rate),2) AS med_cash_to_negotiated,
         ROUND(100.0 * COUNT(*) FILTER (WHERE cash < rate) / COUNT(*)) AS pct_cash_below_negotiated
  FROM hosp_rate WHERE cash IS NOT NULL GROUP BY cpt ORDER BY cpt
) TO '{{OUT}}cash_vs_negotiated.csv' (HEADER);

-- State-level median for the sling (states with >= 5 hospitals)
COPY (
  SELECT hospital_state, COUNT(*) AS hospitals, ROUND(MEDIAN(rate)) AS median_rate
  FROM hosp_rate WHERE cpt = '57288' AND hospital_state IS NOT NULL AND len(hospital_state)=2
  GROUP BY hospital_state HAVING COUNT(*) >= 5 ORDER BY median_rate DESC
) TO '{{OUT}}state_sling.csv' (HEADER);

-- Per-hospital medians for the figures
COPY (SELECT cpt, canonical_id, hospital_state, ROUND(rate,2) AS rate FROM hosp_rate)
TO '{{OUT}}hosp_rates_for_figure.csv' (HEADER);
