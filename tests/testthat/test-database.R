#' Builds hpt.duckdb from a tiny canonical price fixture and checks the
#' schema, the ENUM normalization, the plausibility flag, the payer typing,
#' and the two-stage state medians.

price_fixture <- function() {
  conform_price_table(tibble::tibble(
    source = "own_crawl",
    mrf_file_id = base::c(base::rep("f1", 6), base::rep("f2", 3), "f3"),
    mrf_url = base::c(base::rep("https://a.org/1_a_standardcharges.csv", 6), base::rep("https://b.org/2_b_standardcharges.csv", 3), "https://c.org/3.csv"),
    hospital_name = base::c(base::rep("Alpha", 6), base::rep("Beta", 3), "Gamma"),
    license_state = base::c(base::rep("CO", 6), base::rep("CO", 3), NA),
    concept = "colonoscopy", code = "45378", code_system = "CPT", type_verified = TRUE,
    setting = base::c("outpatient", "Outpatient", "outpatient", "inpatient", "outpatient", "outpatient", "outpatient", "outpatient", "outpatient", "outpatient"),
    billing_class = base::c(NA, "Facility", NA, NA, "professional", NA, NA, NA, NA, NA),
    payer_name = base::c("Aetna", "Cigna", "Colorado Medicaid", "Aetna", "Aetna", "Humana", "Aetna", "UHC", "Health First Colorado Medicaid", "Aetna"),
    plan_name = base::c("PPO", "OAP", "", "PPO", "PPO", "Medicare Advantage HMO", "PPO", "PPO", "", "PPO"),
    negotiated_dollar = base::c(1000, 1400, 300, 5000, 250, 900, 2000, 2200, 0.01, 1500),
    gross = base::c(3000, 3000, 3000, 3000, 400, 3000, 5000, 5000, 5000, 2500),
    discounted_cash = base::c(1200, 1200, 1200, 1200, NA, 1200, 2500, 2500, 2500, 1000),
    methodology = base::c("fee schedule", "Fee Schedule", "case rate", "fee schedule", "fee schedule", "other", "fee schedule", "fee schedule", "fee schedule", "Percent of total billed charge")
  ))
}

testthat::test_that("database builds with ENUMs, plausibility flag, payer types, and CCN bridge", {
  dir <- base::tempfile("db")
  base::dir.create(dir)
  prices_path <- base::file.path(dir, "prices.parquet")
  arrow::write_parquet(price_fixture(), prices_path)

  crosswalk_path <- base::file.path(dir, "crosswalk.parquet")
  arrow::write_parquet(
    # f1 appears twice (two facilities sharing the file, matched by different
    # methods): the bridge must still hold one row. f3 matched no CCN but its
    # facility is in TX; 999999 is not in the roster and must be dropped.
    tibble::tibble(mrf_file_id = base::c("f1", "f1", "f2", "f3", "f2"), ccn = base::c("060011", "060011", "060024", NA, "999999"),
                   ccn_match_method = base::c("mrf_url", "npi", "mrf_url", NA, "name_address"), ccn_match_score = base::c(1, 0.8, 1, NA, 0.7),
                   ccn_conflict = FALSE, ccn_ambiguous = FALSE, state = base::c("CO", "CO", "CO", "TX", "CO")),
    crosswalk_path
  )
  universe <- tibble::tibble(
    facility_id = base::c("060011", "060024"), facility_name = base::c("Alpha", "Beta"), address = "x",
    citytown = "Denver", state = "CO", zip_code = "80204", hospital_type = "Acute Care Hospitals",
    hospital_ownership = "Government", health_sys_id = NA_character_, health_sys_name = "NorthShore \x96 Test"
  )
  db_path <- base::file.path(dir, "hpt.duckdb")

  build_hpt_database(prices_path, crosswalk_path, universe, test_codebook(), db_path = db_path)

  types <- duckdb_query(
    "SELECT column_name, data_type FROM duckdb_columns() WHERE table_name = 'fact_rate' AND column_name IN ('setting', 'billing_class', 'methodology', 'code_id')",
    database = db_path, read_only = TRUE
  )
  testthat::expect_true(base::all(stringr::str_detect(types$data_type[types$column_name != "code_id"], "^ENUM")))
  testthat::expect_equal(types$data_type[types$column_name == "code_id"], "SMALLINT")

  facts <- duckdb_query(
    "SELECT r.*, p.payer_type::VARCHAR AS payer_type FROM fact_rate r LEFT JOIN dim_payer p USING (payer_id)",
    database = db_path, read_only = TRUE
  )
  testthat::expect_equal(base::nrow(facts), 10)
  testthat::expect_equal(base::sum(!facts$plausible), 1)               # the $0.01 sentinel
  testthat::expect_setequal(base::unique(base::as.character(facts$setting)), base::c("outpatient", "inpatient"))
  testthat::expect_true("percent of total billed charges" %in% base::as.character(facts$methodology))
  testthat::expect_setequal(base::unique(facts$payer_type), base::c("commercial", "medicaid", "medicare_advantage"))

  # R duckdb 1.4.4 can open the file (v1.4.0 storage)
  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  base::on.exit(DBI::dbDisconnect(con), add = TRUE)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM v_hospital_rate")$n, 10)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT health_sys_name FROM dim_hospital LIMIT 1")$health_sys_name, "NorthShore – Test")

  medians <- compute_state_medians(db_path, out_dir = dir)
  co_commercial <- medians |> dplyr::filter(.data$state == "CO", .data$insurance_type == "commercial", .data$fee_type == "facility")
  # hospital medians: Alpha = median(1000, 1400) = 1200 (inpatient 5000 excluded); Beta = median(2000, 2200) = 2100
  testthat::expect_equal(co_commercial$median_price, 1650)
  testthat::expect_equal(co_commercial$n_hospitals, 2)
  # professional fee reported separately
  testthat::expect_equal(medians$median_price[medians$state == "CO" & medians$fee_type == "professional" & medians$insurance_type == "commercial"], 250)
  # unmatched file f3 counts as its own unit in TX, via the crosswalk facility state
  testthat::expect_true(base::any(medians$state == "TX"))
  bridge <- duckdb_query("SELECT * FROM bridge_file_ccn", database = db_path, read_only = TRUE)
  testthat::expect_equal(base::nrow(bridge), 2)                           # one row per (file, CCN); 999999 dropped
  testthat::expect_equal(bridge$ccn_match_method[bridge$ccn == "060011"], "mrf_url")
  # Beta's Medicaid rate was the implausible $0.01, so only Alpha contributes
  testthat::expect_equal(medians$n_hospitals[medians$state == "CO" & medians$insurance_type == "medicaid" & medians$fee_type == "facility"], 1)
})
