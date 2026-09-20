#!/usr/bin/env Rscript
#' SGS abstract: negotiated-price variation for prolapse and incontinence surgery.
#'
#' Seven urogynecology CPTs (57288 sling, 57120 colpocleisis, 57260/57265
#' anterior +/- posterior repair, 57282/57283 colpopexy, 57425 laparoscopic
#' sacrocolpopexy) queried directly from the lake's `current_charges` view --
#' these codes are deliberately NOT in config/codebook.csv, so this analysis
#' runs its own SQL (analysis/19_sgs_urogyn_prices.sql) rather than the
#' codebook extract pipeline. Hospital MRF data only; no Trilliant directory
#' tables are read.
#'
#' Analytic unit: each hospital's median negotiated rate per CPT, after
#' excluding professional-fee rows, inpatient-only rows, and rates outside
#' $100-$200,000. Outputs (all under HPT_DATA_DIR/output/sgs_urogyn/, never
#' committed): attrition ledger, cross-hospital spread (+ facility-only
#' sensitivity), within-hospital payer spread, cash-vs-negotiated, state sling
#' medians, and three PNGs (dot-strip figure, Table 1, state lollipop).
#'
#' Env vars: HPT_LAKE_DIR (default: HPT_DATA_DIR/lake, falling back to
#' HPT_DATA_DIR/trilliant/<HPT_TRILLIANT_SNAPSHOT>/lake), HPT_TRILLIANT_SNAPSHOT.

base::source("R/00_source_all.R")
suppressPackageStartupMessages({
  base::library(data.table)
  base::library(ggplot2)
  base::library(scales)
})

## ---- locate the lake -------------------------------------------------------
lake_dir <- base::Sys.getenv("HPT_LAKE_DIR", unset = "")
if (!base::nzchar(lake_dir)) {
  snapshot <- base::Sys.getenv("HPT_TRILLIANT_SNAPSHOT", unset = "20260721")
  candidates <- base::c(hpt_path("lake"),
                        base::file.path(hpt_path("trilliant", snapshot), "lake"))
  lake_dir <- candidates[base::file.exists(base::file.path(candidates, "catalog.duckdb"))][1]
}
if (base::is.na(lake_dir) || !base::file.exists(base::file.path(lake_dir, "catalog.duckdb"))) {
  base::stop("No lake found. Set HPT_LAKE_DIR to a directory holding catalog.duckdb + metadata.ducklake.")
}
require_duckdb_cli()

## ---- run the SQL (writes the CSVs) -----------------------------------------
out_dir <- hpt_path("output", "sgs_urogyn")
base::dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
sql <- base::paste(base::readLines("analysis/19_sgs_urogyn_prices.sql"), collapse = "\n")
sql <- base::gsub("{{OUT}}", base::paste0(out_dir, "/"), sql, fixed = TRUE)
run_duckdb_sql(sql,
               database = base::file.path(lake_dir, "catalog.duckdb"),
               read_only = TRUE,
               init = trilliant_init_sql(lake_dir))
base::message("SQL extract complete -> ", out_dir)

## ---- shared figure vocabulary ----------------------------------------------
proc_lab <- base::c(
  "57120" = "Colpocleisis",
  "57260" = "Anterior repair",
  "57265" = "Anterior + posterior repair",
  "57288" = "Midurethral sling",
  "57282" = "Colpopexy, extraperitoneal",
  "57283" = "Colpopexy, intraperitoneal",
  "57425" = "Laparoscopic sacrocolpopexy")
ink <- "#1f2733"; muted <- "#5b6572"; accent <- "#2E6FAC"
dollar0 <- scales::label_dollar(accuracy = 1)
snapshot_label <- "June 2026"

d    <- data.table::fread(base::file.path(out_dir, "hosp_rates_for_figure.csv"))
spr  <- data.table::fread(base::file.path(out_dir, "primary_spread.csv"))
pay  <- data.table::fread(base::file.path(out_dir, "payer_spread.csv"))
cash <- data.table::fread(base::file.path(out_dir, "cash_vs_negotiated.csv"))
st   <- data.table::fread(base::file.path(out_dir, "state_sling.csv"))
d[, cpt := base::as.character(cpt)]; spr[, cpt := base::as.character(cpt)]
pay[, cpt := base::as.character(cpt)]; cash[, cpt := base::as.character(cpt)]

## ---- Figure 1: dot-strip of hospital medians per procedure -----------------
ord <- spr[base::order(p50), cpt]
lab_full <- base::sprintf("%s (%s)", proc_lab, base::names(proc_lab))
base::names(lab_full) <- base::names(proc_lab)
d[, proc := factor(lab_full[cpt], levels = lab_full[ord])]
spr[, proc := factor(lab_full[cpt], levels = lab_full[ord])]
spr[, lab := base::sprintf("median $%s   ×%.1f spread", scales::comma(p50), ratio_90_10)]
n_rng <- base::range(spr$hospitals)

base::set.seed(42)
fig1 <- ggplot(d, aes(x = rate, y = proc)) +
  geom_jitter(height = 0.28, width = 0, size = 0.7, alpha = 0.35,
              colour = accent, stroke = 0) +
  geom_segment(data = spr, aes(x = p50, xend = p50,
                               y = base::as.numeric(proc) - 0.38,
                               yend = base::as.numeric(proc) + 0.38),
               colour = ink, linewidth = 1.1) +
  geom_text(data = spr, aes(x = 60000, label = lab),
            hjust = 0, colour = muted, size = 9, size.unit = "pt") +
  scale_x_log10(labels = dollar0,
                breaks = c(1000, 2500, 5000, 10000, 25000, 50000),
                expand = expansion(mult = c(0.01, 0.42)),
                guide = guide_axis(check.overlap = TRUE)) +
  labs(title = "The same operation, a fivefold price difference",
       subtitle = base::sprintf(
         "Each dot is one US hospital's median payer-negotiated rate (n = %s–%s hospitals per procedure).\nBlack bar = national median. Hospital price-transparency files, %s; professional-fee and inpatient-only rows excluded.",
         scales::comma(n_rng[1]), scales::comma(n_rng[2]), snapshot_label),
       x = "Negotiated rate (log scale)", y = NULL) +
  theme_minimal(base_size = 12.5) +
  theme(plot.title = element_text(size = rel(1.25), face = "bold", colour = ink),
        plot.title.position = "plot",
        plot.subtitle = element_text(colour = muted, size = rel(0.82),
                                     lineheight = 1.15, margin = margin(b = 14)),
        axis.text.y = element_text(colour = ink, size = rel(0.95)),
        axis.text.x = element_text(colour = muted),
        axis.title.x = element_text(colour = muted, margin = margin(t = 8)),
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "#e3e7ec", linewidth = 0.4),
        plot.margin = margin(14, 18, 10, 14))
ggsave(base::file.path(out_dir, "figure1_price_variation.png"), fig1,
       width = 11, height = 6.2, dpi = 300, bg = "white")

## ---- Table 1 as PNG ---------------------------------------------------------
tb <- base::merge(base::merge(spr, pay[, .(cpt, median_within_hosp_ratio)], by = "cpt"),
                  cash[, .(cpt, med_cash_to_negotiated)], by = "cpt")
tb <- tb[base::order(p50)]
tb[, procedure := base::sprintf("%s (%s)", proc_lab[cpt], cpt)]
disp <- tb[, .(
  Procedure = procedure,
  Hospitals = scales::comma(hospitals),
  `10th pctile` = dollar0(p10),
  Median = dollar0(p50),
  `90th pctile` = dollar0(p90),
  `90:10 ratio` = base::sprintf("%.1f x", ratio_90_10),
  `Within-hospital\npayer ratio` = base::sprintf("%.1f x", median_within_hosp_ratio),
  `Cash /\nnegotiated` = base::sprintf("%.2f", med_cash_to_negotiated))]

nr <- base::nrow(disp); nc <- base::ncol(disp)
long <- data.table::melt(base::cbind(disp, row = base::seq_len(nr)), id.vars = "row",
                         variable.name = "col", value.name = "txt")
long[, x := base::as.integer(col)]
hdr <- data.table::data.table(row = 0, txt = base::names(disp), x = base::seq_len(nc))
colw <- base::c(3.4, 1.05, 1.15, 1.05, 1.15, 1.05, 1.45, 1.15)
xpos <- base::cumsum(colw) - colw / 2
long[, hj := base::ifelse(x == 1, 0, 1)]; hdr[, hj := base::ifelse(x == 1, 0, 1)]
long[, xp := base::ifelse(hj == 0, xpos[x] - colw[x]/2 + 0.05, xpos[x] + colw[x]/2 - 0.05)]
hdr[,  xp := base::ifelse(hj == 0, xpos[x] - colw[x]/2 + 0.05, xpos[x] + colw[x]/2 - 0.05)]
tot <- base::sum(colw)

tbl <- ggplot() +
  geom_rect(data = data.table::data.table(row = base::seq(1, nr, 2)),
            aes(xmin = 0, xmax = tot, ymin = -row - 0.5, ymax = -row + 0.5),
            fill = "#f2f5f8") +
  geom_text(data = long, aes(x = xp, y = -row, label = txt, hjust = hj),
            colour = ink, size = 10.5, size.unit = "pt") +
  geom_text(data = hdr, aes(x = xp, y = 0.15, label = txt, hjust = hj),
            colour = muted, fontface = "bold", size = 10, size.unit = "pt",
            lineheight = 0.85, vjust = 0) +
  annotate("segment", x = 0, xend = tot, y = -0.45, yend = -0.45, colour = ink, linewidth = 0.6) +
  annotate("segment", x = 0, xend = tot, y = -nr - 0.55, yend = -nr - 0.55, colour = ink, linewidth = 0.6) +
  labs(title = "Table 1. Hospital-negotiated prices for prolapse and incontinence surgery",
       subtitle = base::paste0(
         "Per-hospital median negotiated rates from US hospital price-transparency files (", snapshot_label, "); professional-fee and\n",
         "inpatient-only entries excluded. Within-hospital payer ratio = median hospital's highest-to-lowest insurer rate.\n",
         "Cash / negotiated = median ratio of discounted cash price to negotiated rate among hospitals reporting both.")) +
  coord_cartesian(xlim = c(0, tot), ylim = c(-nr - 0.9, 1.15), clip = "off") +
  theme_void() +
  theme(plot.title = element_text(size = 13.5, face = "bold", colour = ink, margin = margin(b = 6)),
        plot.title.position = "plot",
        plot.subtitle = element_text(size = 9, colour = muted, lineheight = 1.25, margin = margin(b = 12)),
        plot.margin = margin(16, 20, 12, 20))
ggsave(base::file.path(out_dir, "table1_urogyn_prices.png"), tbl,
       width = 10.5, height = 4.4, dpi = 300, bg = "white")

## ---- Figure 2: state-level sling lollipop -----------------------------------
st <- st[base::order(median_rate)]
st[, lab := base::sprintf("%s  (%d)", hospital_state, hospitals)]
st[, lab := factor(lab, levels = lab)]
natl_med <- spr[cpt == "57288", p50]

fig2 <- ggplot(st, aes(x = median_rate, y = lab)) +
  geom_vline(xintercept = natl_med, linetype = "22", colour = muted, linewidth = 0.45) +
  geom_segment(aes(x = 0, xend = median_rate, yend = lab),
               colour = accent, alpha = 0.45, linewidth = 0.7) +
  geom_point(colour = accent, size = 2.6) +
  geom_text(data = st[base::c(1, .N)], aes(label = dollar0(median_rate)),
            nudge_x = 900, hjust = 0, colour = ink, fontface = "bold",
            size = 9.5, size.unit = "pt") +
  annotate("text", x = natl_med + 250, y = 2.2, hjust = 0, colour = muted,
           size = 9, size.unit = "pt",
           label = base::paste0("national median ", dollar0(natl_med))) +
  scale_x_continuous(labels = dollar0, expand = expansion(mult = c(0, 0.12)),
                     breaks = base::seq(0, 15000, 2500),
                     guide = guide_axis(check.overlap = TRUE)) +
  labs(title = "Where a midurethral sling costs six times more",
       subtitle = base::sprintf(
         "State median of hospital-negotiated rates for CPT 57288; states with at least 5 reporting hospitals\n(hospital count in parentheses). Hospital price-transparency files, %s.",
         snapshot_label),
       x = "Median negotiated rate", y = NULL) +
  theme_minimal(base_size = 11.5) +
  theme(plot.title = element_text(size = rel(1.25), face = "bold", colour = ink),
        plot.title.position = "plot",
        plot.subtitle = element_text(colour = muted, size = rel(0.85), lineheight = 1.2, margin = margin(b = 12)),
        axis.text.y = element_text(colour = ink, size = rel(0.82)),
        axis.text.x = element_text(colour = muted),
        axis.title.x = element_text(colour = muted, margin = margin(t = 8)),
        panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "#e3e7ec", linewidth = 0.4),
        plot.margin = margin(14, 18, 10, 14))
ggsave(base::file.path(out_dir, "figure2_state_sling_prices.png"), fig2,
       width = 8, height = 9.5, dpi = 300, bg = "white")

base::message("Wrote figures + tables under ", out_dir)
