#!/usr/bin/env Rscript
options(repos = c(CRAN = "https://cran.uib.no/"))
suppressPackageStartupMessages({
  if (!requireNamespace("lintr", quietly = TRUE)) {
    stop("Package 'lintr' is required. Install it with install.packages('lintr').", call. = FALSE)
  }
})

files <- commandArgs(trailingOnly = TRUE)
if (!length(files)) {
  quit(status = 0)
}

linters <- lintr::linters_with_defaults(
  line_length_linter = lintr::line_length_linter(120),
  object_name_linter = NULL,
  commented_code_linter = NULL
)
lints <- unlist(lapply(files, lintr::lint, linters = linters), recursive = FALSE)
if (length(lints)) {
  for (lint in lints) {
    print(lint)
  }
  quit(status = 1)
}
