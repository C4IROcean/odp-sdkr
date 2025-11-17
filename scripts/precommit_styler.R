#!/usr/bin/env Rscript
options(repos = c(CRAN = "https://cran.uib.no/"))
suppressPackageStartupMessages({
  if (!requireNamespace("styler", quietly = TRUE)) {
    stop("Package 'styler' is required. Install it with install.packages('styler').", call. = FALSE)
  }
})

files <- commandArgs(trailingOnly = TRUE)
if (!length(files)) {
  quit(status = 0)
}

for (path in files) {
  styler::style_file(path)
}
