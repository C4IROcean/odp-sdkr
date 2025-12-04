#' Ocean Data Platform (ODP) R SDK
#'
#' Lightweight helpers for authenticating against the HubOcean API, inspecting
#' dataset metadata, streaming Arrow RecordBatches, and materialising data into
#' common R structures like `data.frame`s and tibbles.
#'
#' @section Getting help:
#' Run `help(package = "odp")`, `browseVignettes("odp")`, or `??odp` for
#' walkthroughs covering installation, authentication, streaming helpers, and
#' aggregations from scripts or notebooks. Hosted docs can be found in our
#' official portal <https://docs.hubocean.earth/r_sdk/>. When installing from a local checkout,
#' build vignettes (`remotes::install_local(..., build_vignettes = TRUE)`) so that
#' `vignette("odp")` and friends are available.
#'
#' @section Articles:
#' - ODP R SDK overview: <https://docs.hubocean.earth/r_sdk/>
#' - `vignette("odp")` introduces installation, authentication, and cursors.
#' - `vignette("odp-tabular")` focuses on working with tabular datasets: streaming,
#'   filtering, projections, and aggregations.
#'
#' @docType package
#' @name odp
#' @aliases odp-package OceanDataPlatform
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
