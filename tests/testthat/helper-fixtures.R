#' Shared test fixtures. testthat::test_dir() changes the working directory
#' to tests/testthat/, so resolve paths against the repo root captured in
#' tests/testthat.R.

repo_root_path <- function() {
  base::getOption("hpt_repo_root", ".")
}

fixture_path <- function(...) {
  base::file.path(repo_root_path(), "tests", "testthat", "fixtures", ...)
}

test_codebook <- function() {
  load_codebook(base::file.path(repo_root_path(), "config", "codebook.csv"))
}
