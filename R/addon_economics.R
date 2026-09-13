#' Add-on procedure economics
#'
#' Is it worth adding a small secondary procedure at the time of a primary one
#' when the added room minutes can displace primary cases? Two cases:
#'   A: IUD insertion (58300 + device) at bariatric surgery (MS-DRG 621; 620, 43775, 43644)
#'   B: endometrial biopsy (58100 + pathology 88305) at colonoscopy (45378, G0121, G0105)
#'
#' Notation (see docs/addon_methods.md):
#'   R_P  facility payment per primary case (HPT state x insurance median)
#'   R_S  facility payment the hospital collects for the secondary bundle
#'   C_S  secondary contribution = R_S - variable costs of the add-on
#'   T_P  room minutes per primary case, including turnover
#'   dT   room minutes the add-on adds
#'   u    probability the freed minutes would have held another primary case
#'   m    contribution-margin share of the primary payment
#'
#'   opportunity-cost framing: net = C_S - u * (dT / T_P) * m * R_P
#'   room-cost framing:        net = C_S - dT * (room + anesthesia cost per minute)
#'
#' The two framings are alternatives: displacement already prices the room
#' minutes, so a per-minute room cost is never added on top of it.
#'
#' Parameters live in config/addon_parameters.csv. Revenue comes from
#' compute_state_medians() output (R/state_medians.R).

addon_parameter_path <- function() {
  base::file.path(base::getOption("hpt_repo_root", "."), "config", "addon_parameters.csv")
}

#' Insurance types analyzed (gross charges are list prices, not revenue)
addon_insurance_types <- function() {
  base::c(
    "commercial", "medicare_advantage", "medicare", "medicaid", "exchange",
    "tricare_va", "workers_comp", "self_pay", "self_pay_cash", "other"
  )
}

# ---- parameters -------------------------------------------------------------

#' Load the parameter table and put every cost in reference-year dollars
#'
#' Adds `inflation_factor` and the adjusted `base`, `low`, `high` columns;
#' the source columns (`base_value`, `low_value`, `high_value`) stay nominal.
load_addon_parameters <- function(path = addon_parameter_path()) {
  params <- readr::read_csv(
    path,
    show_col_types = FALSE,
    col_types = readr::cols(
      base_value = readr::col_double(), low_value = readr::col_double(),
      high_value = readr::col_double(), dollar_year = readr::col_integer(),
      provisional = readr::col_logical(), .default = readr::col_character()
    ),
    na = base::c("", "NA")
  )

  required <- base::c(
    "parameter", "case", "description", "base_value", "unit", "low_value", "high_value",
    "distribution", "dollar_year", "price_index", "source", "provisional", "notes"
  )
  missing_columns <- base::setdiff(required, base::names(params))
  if (base::length(missing_columns) > 0L) {
    base::stop("Parameter file is missing column(s): ", base::paste(missing_columns, collapse = ", "))
  }
  if (base::anyDuplicated(params$parameter) > 0L) {
    base::stop("Duplicate parameter name(s): ", base::paste(params$parameter[base::duplicated(params$parameter)], collapse = ", "))
  }
  if (base::any(base::is.na(params$base_value))) {
    base::stop("Every parameter needs a base_value.")
  }
  out_of_order <- !base::is.na(params$low_value) & !base::is.na(params$high_value) &
    (params$low_value > params$base_value | params$base_value > params$high_value)
  if (base::any(out_of_order)) {
    base::stop("low <= base <= high fails for: ", base::paste(params$parameter[out_of_order], collapse = ", "))
  }
  bad_distribution <- !params$distribution %in% base::c("fixed", "triangular", "beta", "gamma")
  if (base::any(bad_distribution)) {
    base::stop("Unknown distribution for: ", base::paste(params$parameter[bad_distribution], collapse = ", "))
  }

  params$inflation_factor <- addon_inflation_factor(params, params$dollar_year, params$price_index)
  params |>
    dplyr::mutate(
      base = .data$base_value * .data$inflation_factor,
      low = .data$low_value * .data$inflation_factor,
      high = .data$high_value * .data$inflation_factor
    )
}

#' CPI ratio from each dollar year to the reference year
#'
#' Index values are rows of the parameter table itself
#' (cpi_medical_care_<year>, cpi_all_items_<year>).
addon_inflation_factor <- function(params, dollar_year, price_index) {
  reference_year <- params$base_value[params$parameter == "reference_dollar_year"]
  if (base::length(reference_year) != 1L) {
    base::stop("Parameter table needs exactly one reference_dollar_year row.")
  }

  purrr::map2_dbl(dollar_year, price_index, function(year, index) {
    if (base::is.na(year) || base::is.na(index) || index == "none" || year == reference_year) {
      return(1)
    }
    series <- base::switch(index, medical_care = "cpi_medical_care_", all_items = "cpi_all_items_",
      base::stop("Unknown price_index: ", index)
    )
    from <- params$base_value[params$parameter == base::paste0(series, year)]
    to <- params$base_value[params$parameter == base::paste0(series, reference_year)]
    if (base::length(from) != 1L || base::length(to) != 1L) {
      base::stop("No ", series, " row for ", year, " or ", reference_year, ".")
    }
    to / from
  })
}

#' Named vector of one scenario's parameter values (reference-year dollars)
addon_parameter_values <- function(params, which = base::c("base", "low", "high")) {
  which <- base::match.arg(which)
  values <- params[[which]]
  values[base::is.na(values)] <- params$base[base::is.na(values)]
  stats::setNames(values, params$parameter)
}

# ---- case definitions -------------------------------------------------------

#' One row per case variant: which codes and which parameters it uses
#'
#' Case A's base primary price is MS-DRG 621 (obesity O.R. procedure without
#' CC/MCC): CPT-coded 43775/43644 facility lines in hospital MRFs are often
#' partial (national Medicare 43775 median $1,062 against $12,932 for DRG 621),
#' so they are sensitivity variants. DRG variants use the sleeve OR slot, the
#' most common bariatric operation.
#'
#' `secondary_procedure` and `secondary_item` are the two components of the
#' add-on bundle (A: 58300 + device; B: 58100 + 88305). `variable_cost_params`
#' is a ";"-separated list of parameters summed into the add-on's variable cost.
addon_case_definitions <- function() {
  a_costs <- function(device) {
    base::paste(
      base::paste0("iud_acquisition_cost_", device), "iud_insertion_supply_cost",
      "combined_emb_anesthesia_drug_increment_cost", "coordination_cost",
      sep = ";"
    )
  }
  b_costs <- "emb_pathology_cost;emb_disposable_supply_cost;combined_emb_anesthesia_drug_increment_cost;coordination_cost"

  tibble::tribble(
    ~case, ~variant, ~base_variant, ~primary_code, ~secondary_procedure, ~secondary_item, ~slot_param, ~added_minutes_param, ~utilization_param, ~margin_param, ~block_param, ~variable_cost_params,
    "A", "drg621_mirena", TRUE, "621", "58300", "J7298", "sleeve_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7298"),
    "A", "drg620_mirena", FALSE, "620", "58300", "J7298", "sleeve_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7298"),
    "A", "drg621_liletta", FALSE, "621", "58300", "J7297", "sleeve_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7297"),
    "A", "drg621_paragard", FALSE, "621", "58300", "J7300", "sleeve_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7300"),
    "A", "sleeve_cpt_mirena", FALSE, "43775", "58300", "J7298", "sleeve_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7298"),
    "A", "bypass_cpt_mirena", FALSE, "43644", "58300", "J7298", "bypass_or_slot_minutes", "iud_added_minutes_at_surgery", "utilization_A", "contribution_margin_bariatric", "or_block_minutes", a_costs("J7298"),
    "B", "diagnostic_45378", TRUE, "45378", "58100", "88305", "colonoscopy_slot_minutes", "combined_emb_added_minutes", "utilization_B", "contribution_margin_colonoscopy", "endoscopy_block_minutes", b_costs,
    "B", "screening_G0121", FALSE, "G0121", "58100", "88305", "colonoscopy_slot_minutes", "combined_emb_added_minutes", "utilization_B", "contribution_margin_colonoscopy", "endoscopy_block_minutes", b_costs,
    "B", "screening_high_risk_G0105", FALSE, "G0105", "58100", "88305", "colonoscopy_slot_minutes", "combined_emb_added_minutes", "utilization_B", "contribution_margin_colonoscopy", "endoscopy_block_minutes", b_costs
  )
}

#' Payment-fraction parameter for a case, component, and insurance type
#'
#' Uses `pay_frac_<case>_<component>__<insurance_type>` when that override
#' exists, else the default `pay_frac_<case>_<component>`.
addon_pay_fraction_param <- function(case, component, insurance_type, param_names) {
  override <- base::paste0("pay_frac_", case, "_", component, "__", insurance_type)
  dplyr::if_else(override %in% param_names, override, base::paste0("pay_frac_", case, "_", component))
}

# ---- revenue lookup ---------------------------------------------------------

#' Facility rate for one code, with fallback to the national median
#'
#' The state x insurance median is used when at least `min_hospitals`
#' hospitals back it; otherwise the national (state == "US") median for the
#' same insurance type; otherwise `fallback_rate` (a parameter); otherwise NA.
#'
#' @param grid Tibble of state, insurance_type.
#' @return `grid` plus rate, source ("state", "national", "parameter",
#'   "missing"), n_hospitals, p25, p75, thin_national.
addon_lookup_rate <- function(medians, grid, code, min_hospitals = 3L, fallback_rate = NA_real_) {
  facility <- medians |>
    dplyr::filter(.data$fee_type == "facility", .data$code == !!code) |>
    dplyr::select("state", "insurance_type", "median_price", "p25", "p75", "n_hospitals")
  if (base::anyDuplicated(facility[base::c("state", "insurance_type")]) > 0L) {
    base::stop("More than one facility median per state x insurance type for code ", code)
  }

  state_rows <- facility |> dplyr::filter(.data$state != "US")
  national <- facility |>
    dplyr::filter(.data$state == "US") |>
    dplyr::select("insurance_type", us_price = "median_price", us_p25 = "p25", us_p75 = "p75", us_n = "n_hospitals")

  grid |>
    dplyr::left_join(state_rows, by = base::c("state", "insurance_type")) |>
    dplyr::left_join(national, by = "insurance_type") |>
    dplyr::mutate(
      use_state = !base::is.na(.data$median_price) & .data$n_hospitals >= min_hospitals,
      source = dplyr::case_when(
        .data$use_state ~ "state",
        !base::is.na(.data$us_price) ~ "national",
        !base::is.na(fallback_rate) ~ "parameter",
        TRUE ~ "missing"
      ),
      rate = dplyr::case_when(
        .data$source == "state" ~ .data$median_price,
        .data$source == "national" ~ .data$us_price,
        .data$source == "parameter" ~ fallback_rate,
        TRUE ~ NA_real_
      ),
      rate_p25 = dplyr::case_when(.data$source == "state" ~ .data$p25, .data$source == "national" ~ .data$us_p25, TRUE ~ .data$rate),
      rate_p75 = dplyr::case_when(.data$source == "state" ~ .data$p75, .data$source == "national" ~ .data$us_p75, TRUE ~ .data$rate),
      rate_n_hospitals = dplyr::case_when(.data$source == "state" ~ .data$n_hospitals, .data$source == "national" ~ .data$us_n, TRUE ~ NA_real_),
      thin_national = .data$source == "national" & .data$us_n < min_hospitals
    ) |>
    dplyr::select("state", "insurance_type", "rate", "source", "rate_p25", "rate_p75", "rate_n_hospitals", "thin_national")
}

#' Revenue inputs for every case variant x state x insurance type
#'
#' The grid is every state in `medians` (plus "US") crossed with
#' `insurance_types`, so a state with no data of its own still gets a row
#' that falls back to the national medians.
addon_rates <- function(medians, params, cases = addon_case_definitions(),
                        insurance_types = addon_insurance_types(), min_hospitals = 3L) {
  states <- base::sort(base::unique(base::c(medians$state, "US")))
  grid <- tidyr::expand_grid(state = states, insurance_type = insurance_types)
  fallback <- function(code) {
    value <- params$base[params$parameter == base::paste0("fallback_rate_", code)]
    if (base::length(value) == 1L) value else NA_real_
  }
  lookup <- function(code, prefix) {
    rates <- addon_lookup_rate(medians, grid, code, min_hospitals, fallback(code))
    base::names(rates)[-(1:2)] <- base::paste0(prefix, "_", base::names(rates)[-(1:2)])
    rates
  }

  purrr::pmap_dfr(cases, function(...) {
    case_row <- tibble::tibble(...)
    grid |>
      dplyr::left_join(lookup(case_row$primary_code, "primary"), by = base::c("state", "insurance_type")) |>
      dplyr::left_join(lookup(case_row$secondary_procedure, "procedure"), by = base::c("state", "insurance_type")) |>
      dplyr::left_join(lookup(case_row$secondary_item, "item"), by = base::c("state", "insurance_type")) |>
      dplyr::mutate(!!!base::as.list(case_row))
  }) |>
    dplyr::relocate(base::names(cases))
}

# ---- core equations ---------------------------------------------------------

#' Net value per add-on, opportunity-cost framing
addon_net_value <- function(C_S, R_P, dT, T_P, u, m) {
  C_S - u * (dT / T_P) * m * R_P
}

#' Net value per add-on, room-cost framing
addon_room_cost_net_value <- function(C_S, dT, cost_per_minute) {
  C_S - dT * cost_per_minute
}

#' Break-even added minutes dT* (net = 0)
#'
#' NA when C_S <= 0 (never worth it, at any dT); Inf when nothing is
#' displaced (u, m, or R_P is zero) and C_S > 0.
addon_breakeven_minutes <- function(C_S, R_P, T_P, u, m) {
  denominator <- u * m * R_P
  dplyr::case_when(
    base::is.na(C_S) | base::is.na(denominator) ~ NA_real_,
    C_S <= 0 ~ NA_real_,
    denominator <= 0 ~ Inf,
    TRUE ~ C_S * T_P / denominator
  )
}

#' Break-even utilization u* (net = 0)
#'
#' Values above 1 mean the add-on pays even in a fully booked room. NA when
#' C_S <= 0 (not worth it even with slack capacity).
addon_breakeven_utilization <- function(C_S, R_P, dT, T_P, m) {
  denominator <- (dT / T_P) * m * R_P
  dplyr::case_when(
    base::is.na(C_S) | base::is.na(denominator) ~ NA_real_,
    C_S <= 0 ~ NA_real_,
    denominator <= 0 ~ Inf,
    TRUE ~ C_S / denominator
  )
}

#' Break-even added minutes under the room-cost framing
addon_breakeven_minutes_room_cost <- function(C_S, cost_per_minute) {
  dplyr::if_else(C_S <= 0, NA_real_, C_S / cost_per_minute)
}

#' Revenue per minute of the add-on relative to the primary case
addon_revenue_per_minute_ratio <- function(R_S, dT, R_P, T_P) {
  (R_S / dT) / (R_P / T_P)
}

#' Parameter lookup for evaluate(): a named vector (one scenario) or a
#' matrix with one row per evaluated row (PSA)
addon_lookup_values <- function(values, names) {
  if (base::is.null(base::dim(values))) {
    missing_names <- base::setdiff(base::unique(names[!base::is.na(names)]), base::names(values))
    if (base::length(missing_names) > 0L) {
      base::stop("Missing parameter(s): ", base::paste(missing_names, collapse = ", "))
    }
    out <- base::unname(values[names])
  } else {
    column <- base::match(names, base::colnames(values))
    if (base::any(base::is.na(column) & !base::is.na(names))) {
      base::stop("Missing parameter(s): ", base::paste(base::unique(names[base::is.na(column) & !base::is.na(names)]), collapse = ", "))
    }
    out <- values[base::cbind(base::seq_along(names), column)]
  }
  out[base::is.na(names)] <- 0
  out
}

#' Apply one parameter scenario to the revenue inputs
#'
#' @param rates From addon_rates().
#' @param values Named vector from addon_parameter_values(), or a matrix
#'   with `nrow(rates)` rows and one column per parameter (PSA draws).
addon_evaluate <- function(rates, values) {
  param_names <- if (base::is.null(base::dim(values))) base::names(values) else base::colnames(values)
  value_of <- function(names) addon_lookup_values(values, names)

  frac_procedure_param <- addon_pay_fraction_param(rates$case, "procedure", rates$insurance_type, param_names)
  frac_item_param <- addon_pay_fraction_param(rates$case, "item", rates$insurance_type, param_names)

  cost_names <- stringr::str_split(rates$variable_cost_params, ";")
  n_costs <- base::max(base::lengths(cost_names))
  variable_cost <- base::rep(0, base::nrow(rates))
  for (j in base::seq_len(n_costs)) {
    variable_cost <- variable_cost + value_of(base::vapply(cost_names, function(x) x[j], base::character(1)))
  }

  rates |>
    dplyr::mutate(
      pay_frac_procedure = value_of(frac_procedure_param),
      pay_frac_item = value_of(frac_item_param),
      R_P = .data$primary_rate,
      R_S_listed = .data$procedure_rate + .data$item_rate,
      R_S = .data$pay_frac_procedure * .data$procedure_rate + .data$pay_frac_item * .data$item_rate,
      variable_cost = variable_cost,
      C_S = .data$R_S - .data$variable_cost,
      C_S_listed = .data$R_S_listed - .data$variable_cost,
      T_P = value_of(.data$slot_param),
      dT = value_of(.data$added_minutes_param),
      u = value_of(.data$utilization_param),
      m = value_of(.data$margin_param),
      room_cost_per_minute = value_of(base::rep("direct_room_cost_per_minute", dplyr::n())) +
        value_of(base::rep("anesthesia_cost_per_minute", dplyr::n())),
      lost_primary_per_addon = .data$u * .data$dT / .data$T_P,
      displacement_cost = .data$lost_primary_per_addon * .data$m * .data$R_P,
      net_value = addon_net_value(.data$C_S, .data$R_P, .data$dT, .data$T_P, .data$u, .data$m),
      net_value_room_cost = addon_room_cost_net_value(.data$C_S, .data$dT, .data$room_cost_per_minute),
      net_value_listed_rate = addon_net_value(.data$C_S_listed, .data$R_P, .data$dT, .data$T_P, .data$u, .data$m),
      dT_star = addon_breakeven_minutes(.data$C_S, .data$R_P, .data$T_P, .data$u, .data$m),
      u_star = addon_breakeven_utilization(.data$C_S, .data$R_P, .data$dT, .data$T_P, .data$m),
      dT_star_room_cost = addon_breakeven_minutes_room_cost(.data$C_S, .data$room_cost_per_minute),
      revenue_per_minute_primary = .data$R_P / .data$T_P,
      revenue_per_minute_addon = .data$R_S / .data$dT,
      revenue_per_minute_ratio = addon_revenue_per_minute_ratio(.data$R_S, .data$dT, .data$R_P, .data$T_P),
      primary_fallback = .data$state != "US" & .data$primary_source != "state",
      secondary_fallback = .data$state != "US" & (.data$procedure_source != "state" | .data$item_source != "state"),
      worth_it = .data$net_value > 0
    )
}

#' Base-case table: one row per case variant x state x insurance type
addon_value_by_state <- function(medians, params, cases = addon_case_definitions(),
                                 insurance_types = addon_insurance_types(), min_hospitals = 3L) {
  addon_rates(medians, params, cases, insurance_types, min_hospitals) |>
    addon_evaluate(addon_parameter_values(params, "base")) |>
    dplyr::select(
      "case", "variant", "base_variant", "primary_code", "secondary_procedure", "secondary_item",
      "state", "insurance_type",
      "R_P", "primary_source", primary_n_hospitals = "primary_rate_n_hospitals",
      procedure_rate_listed = "procedure_rate", "procedure_source",
      item_rate_listed = "item_rate", "item_source",
      "R_S_listed", "pay_frac_procedure", "pay_frac_item", "R_S", "variable_cost", "C_S",
      "T_P", "dT", "u", "m", "lost_primary_per_addon", "displacement_cost",
      "net_value", "net_value_room_cost", "net_value_listed_rate",
      "dT_star", "u_star", "dT_star_room_cost",
      "revenue_per_minute_primary", "revenue_per_minute_addon", "revenue_per_minute_ratio",
      "primary_fallback", "secondary_fallback", "primary_thin_national", "worth_it"
    ) |>
    dplyr::arrange(.data$case, .data$variant, .data$state != "US", .data$state, .data$insurance_type)
}

# ---- integer capacity -------------------------------------------------------

#' Primary cases that fit in a block when a fraction f of cases get the add-on
#'
#' floor(B / (T_P + f * dT)); a tiny tolerance keeps exact fits (480 / 60)
#' from flooring down on floating-point error.
addon_cases_per_day <- function(block_minutes, T_P, dT, f) {
  base::floor(block_minutes / (T_P + f * dT) + 1e-9)
}

#' Add-ons that fit in the end-of-day slack before a primary case is lost
addon_free_addons_per_day <- function(block_minutes, T_P, dT) {
  cases <- addon_cases_per_day(block_minutes, T_P, 0, 0)
  base::floor((block_minutes - cases * T_P) / dT + 1e-9)
}

#' Day-level revenue and contribution with and without add-ons
#'
#' @return Tibble, one row per f: primary cases, add-ons, day revenue and
#'   day contribution, and their change against f = 0.
addon_day_value <- function(block_minutes, T_P, dT, f, R_P, R_S, C_S, m) {
  cases <- addon_cases_per_day(block_minutes, T_P, dT, f)
  cases_without <- addon_cases_per_day(block_minutes, T_P, dT, 0)
  addons <- f * cases

  tibble::tibble(
    f = f,
    primary_cases = cases,
    addons = addons,
    primary_cases_lost = cases_without - cases,
    day_revenue = cases * R_P + addons * R_S,
    day_contribution = cases * m * R_P + addons * C_S,
    revenue_change = .data$day_revenue - cases_without * R_P,
    contribution_change = .data$day_contribution - cases_without * m * R_P
  )
}

# ---- sensitivity ------------------------------------------------------------

#' Parameters a case row depends on (for the one-way analysis)
addon_row_parameters <- function(case_row, param_names) {
  base::c(
    case_row$slot_param, case_row$added_minutes_param, case_row$utilization_param, case_row$margin_param,
    addon_pay_fraction_param(case_row$case, "procedure", case_row$insurance_type, param_names),
    addon_pay_fraction_param(case_row$case, "item", case_row$insurance_type, param_names),
    stringr::str_split(case_row$variable_cost_params, ";")[[1]]
  )
}

#' One-way (tornado) sensitivity of the opportunity-cost net value
#'
#' Each parameter goes to its low and high value with the others at base.
#' Prices go to the interhospital p25 and p75 of the median they came from
#' (spread across hospitals, not sampling uncertainty).
addon_tornado <- function(rates, params) {
  base_values <- addon_parameter_values(params, "base")
  low_values <- addon_parameter_values(params, "low")
  high_values <- addon_parameter_values(params, "high")
  base_net <- addon_evaluate(rates, base_values)$net_value

  purrr::map_dfr(base::seq_len(base::nrow(rates)), function(i) {
    row <- rates[i, ]
    used <- base::unique(addon_row_parameters(row, base::names(base_values)))
    used <- used[low_values[used] != high_values[used]]

    parameter_rows <- purrr::map_dfr(used, function(p) {
      at <- function(value) {
        scenario <- base_values
        scenario[p] <- value
        addon_evaluate(row, scenario)$net_value
      }
      tibble::tibble(
        parameter = p, low_input = low_values[[p]], base_input = base_values[[p]], high_input = high_values[[p]],
        net_at_low = at(low_values[[p]]), net_at_high = at(high_values[[p]])
      )
    })

    price_rows <- purrr::map_dfr(
      base::list(
        base::c("R_P (hospital IQR)", "primary_rate"),
        base::c("R_S procedure (hospital IQR)", "procedure_rate"),
        base::c("R_S item (hospital IQR)", "item_rate")
      ),
      function(spec) {
        at <- function(suffix) {
          shifted <- row
          shifted[[spec[2]]] <- row[[base::paste0(base::sub("_rate$", "", spec[2]), "_rate_", suffix)]]
          addon_evaluate(shifted, base_values)$net_value
        }
        tibble::tibble(
          parameter = spec[1],
          low_input = row[[base::paste0(base::sub("_rate$", "", spec[2]), "_rate_p25")]],
          base_input = row[[spec[2]]],
          high_input = row[[base::paste0(base::sub("_rate$", "", spec[2]), "_rate_p75")]],
          net_at_low = at("p25"), net_at_high = at("p75")
        )
      }
    )

    dplyr::bind_rows(parameter_rows, price_rows) |>
      dplyr::mutate(
        case = row$case, variant = row$variant, state = row$state, insurance_type = row$insurance_type,
        base_net = base_net[i], swing = base::abs(.data$net_at_high - .data$net_at_low),
        .before = 1
      )
  }) |>
    dplyr::filter(.data$swing > 0) |>
    dplyr::arrange(.data$case, .data$variant, .data$insurance_type, dplyr::desc(.data$swing))
}

#' Draw one parameter n times from its distribution
#'
#' triangular(low, base, high); beta and gamma by method of moments with
#' mean = base and sd = (high - low) / 3.92; fixed = base.
addon_draw_parameter <- function(n, distribution, base_value, low, high) {
  if (distribution == "fixed" || base::is.na(low) || base::is.na(high) || low == high) {
    return(base::rep(base_value, n))
  }
  sd <- (high - low) / 3.92

  base::switch(distribution,
    triangular = {
      p <- stats::runif(n)
      cut <- (base_value - low) / (high - low)
      base::ifelse(
        p < cut,
        low + base::sqrt(p * (high - low) * (base_value - low)),
        high - base::sqrt((1 - p) * (high - low) * (high - base_value))
      )
    },
    beta = {
      spread <- base_value * (1 - base_value) / sd^2 - 1
      if (base_value <= 0 || base_value >= 1 || spread <= 0) {
        base::stop("Beta moments are infeasible for base ", base_value, " and sd ", sd)
      }
      stats::rbeta(n, base_value * spread, (1 - base_value) * spread)
    },
    gamma = {
      if (base_value <= 0) base::stop("Gamma needs a positive base value.")
      stats::rgamma(n, shape = (base_value / sd)^2, rate = base_value / sd^2)
    }
  )
}

#' Matrix of PSA draws, one column per parameter (reference-year dollars)
addon_draw_parameters <- function(params, n = 5000L, seed = 20260912L) {
  base::set.seed(seed)
  draws <- base::vapply(
    base::seq_len(base::nrow(params)),
    function(i) addon_draw_parameter(n, params$distribution[i], params$base[i], params$low[i], params$high[i]),
    base::numeric(n)
  )
  base::matrix(draws, nrow = n, dimnames = base::list(NULL, params$parameter))
}

#' Probabilistic sensitivity analysis over the given rate rows
#'
#' Prices stay at their medians; parameters vary jointly and independently.
#' @return List: `summary` (one row per rate row) and `draws` (long).
addon_psa <- function(rates, params, n = 5000L, seed = 20260912L) {
  draws <- addon_draw_parameters(params, n, seed)
  n_rows <- base::nrow(rates)
  expanded <- rates[base::rep(base::seq_len(n_rows), times = n), ]
  values <- draws[base::rep(base::seq_len(n), each = n_rows), , drop = FALSE]

  evaluated <- addon_evaluate(expanded, values) |>
    dplyr::mutate(draw = base::rep(base::seq_len(n), each = n_rows))

  summary <- evaluated |>
    dplyr::group_by(.data$case, .data$variant, .data$state, .data$insurance_type) |>
    dplyr::summarise(
      draws = dplyr::n(),
      mean_net_value = base::mean(.data$net_value),
      net_value_p025 = stats::quantile(.data$net_value, 0.025, names = FALSE),
      net_value_p975 = stats::quantile(.data$net_value, 0.975, names = FALSE),
      prob_worth_it = base::mean(.data$net_value > 0),
      prob_worth_it_room_cost = base::mean(.data$net_value_room_cost > 0),
      prob_worth_it_listed_rate = base::mean(.data$net_value_listed_rate > 0),
      prob_contribution_positive = base::mean(.data$C_S > 0),
      .groups = "drop"
    )

  base::list(
    summary = summary,
    draws = evaluated |> dplyr::select("draw", "case", "variant", "state", "insurance_type", "C_S", "net_value", "net_value_room_cost", "net_value_listed_rate")
  )
}

# ---- payer and patient perspective ------------------------------------------

#' Payer and patient view of combining, one row per evaluated row
#'
#' Payer: payment for the add-on in the combined setting (collected facility
#' share plus a facility-setting professional fee) against a standalone
#' office encounter (office procedure fee + E/M visit + device or pathology).
#' Patient: office visits and time avoided, and the expected delay imposed on
#' displaced primary patients. No health outcomes are monetized.
addon_system_perspective <- function(evaluated, values) {
  n <- base::nrow(evaluated)
  value_of <- function(name) addon_lookup_values(values, base::rep(name, n))
  is_a <- evaluated$case == "A"
  # NA names look up as 0, so the device only counts for case A rows
  device_cost <- addon_lookup_values(values, dplyr::if_else(is_a, base::paste0("iud_acquisition_cost_", evaluated$secondary_item), NA_character_))
  pathology_cost <- addon_lookup_values(values, dplyr::if_else(is_a, NA_character_, "emb_pathology_cost"))

  evaluated |>
    dplyr::mutate(
      payer_combined_payment = .data$R_S + dplyr::if_else(
        is_a, value_of("iud_insertion_professional_payment_facility"), value_of("emb_office_professional_cost_facility")
      ),
      payer_standalone_payment = dplyr::if_else(
        is_a, value_of("office_iud_insertion_professional_payment"), value_of("emb_office_professional_cost")
      ) + value_of("office_visit_em_cost") + device_cost + pathology_cost,
      payer_saving_per_addon = .data$payer_standalone_payment - .data$payer_combined_payment,
      visits_avoided = dplyr::if_else(is_a, value_of("avoided_standalone_visits_A"), value_of("avoided_standalone_visits_B")),
      patient_time_saved_usd = .data$visits_avoided * value_of("patient_time_opportunity_cost_per_visit"),
      displaced_primary_per_100_addons = 100 * .data$lost_primary_per_addon,
      patient_delay_days_per_addon = .data$lost_primary_per_addon *
        dplyr::if_else(is_a, value_of("delay_days_per_displaced_case_A"), value_of("delay_days_per_displaced_case_B"))
    ) |>
    dplyr::select(
      "case", "variant", "state", "insurance_type", "R_S", "payer_combined_payment", "payer_standalone_payment",
      "payer_saving_per_addon", "visits_avoided", "patient_time_saved_usd",
      "displaced_primary_per_100_addons", "patient_delay_days_per_addon"
    )
}
