#' Ocean Data Platform (ODP) R SDK
#'
#' The Ocean Data Platform (ODP) is a hosted catalog of curated marine and
#' environmental datasets. This package provides light-weight helpers so you can
#' authenticate with your HubOcean account, navigate to a dataset, pick a table,
#' and stream rows straight into data frames or Arrow tables without leaving
#' your analysis workflow. The SDK currently focuses on read-only helpers. More
#' capabilities will arrive as the project matures.
#'
#' When you work with the SDK you will usually touch the following pieces:
#'
#' - `odp_client()` — holds your API key and issues authenticated requests
#' - dataset object — retrieved via `client$dataset("<dataset-id>")`
#' - table object — accessed via `dataset$table`
#' - cursor — returned from `table$select()` and responsible for paging data
#'
#' Status: This SDK is considered pre-release. Please reach out if you have any
#' issues, concerns, or ideas that would improve the experience.
#'
#' @section Requirements:
#'
#' - R 4.1 or newer
#' - Packages declared in `DESCRIPTION`
#' - A valid HubOcean API key exposed as `ODP_API_KEY` or passed directly to
#'   `odp_client()`
#'
#' @section Getting started:
#' The snippet below shows the full flow: install, authenticate, navigate to a
#' dataset, pick a table, and stream the columns you care about. Swap the dataset
#' id for the resources you have access to in the ODP catalog.
#'
#' ```r
#' install.packages("remotes")  # skip if already installed
#' remotes::install_github("C4IROcean/odp-sdkr")
#'
#' library(odp)
#'
#' client <- odp_client(api_key = "Sk_....")
#' dataset <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")
#' table <- dataset$table
#'
#' cursor <- table$select(
#'   filter = "depth > $min_depth",
#'   vars = list(min_depth = 300),
#'   columns = c("latitude", "longitude", "depth"),
#'   timeout = 15
#' )
#'
#' df <- cursor$dataframe()
#' ```
#'
#' @section Streaming rows in batches:
#' When working with a large table it can be helpful to consume batches
#' incrementally. The cursor pulls pages in the background as needed.
#'
#' ```r
#' cursor <- table$select()
#' while (!is.null(chunk <- cursor$next_batch())) {
#'   print(chunk$num_rows)
#' }
#'
#' df <- cursor$dataframe()
#' arrow_tbl <- cursor$arrow()
#' ```
#'
#' `collect()`/`dataframe()`/`tibble()`/`arrow()` only materialise batches that
#' have not been streamed yet. To obtain the full dataset after calling
#' `next_batch()`, create a fresh cursor and collect before iterating.
#'
#' @section Aggregations:
#' The SDK supports server-side aggregations so you can compute simple
#' statistics without transferring the full table.
#'
#' ```r
#' agg <- table$aggregate(
#'   group_by = "'TOTAL'",
#'   filter = "depth > 200",
#'   aggr = list(depth = "mean")
#' )
#' print(agg)
#' ```
#'
#' @section Metadata helpers:
#' Use `table$schema()` and `table$stats()` to inspect the structure and
#' high-level metadata of a dataset.
#'
#' ```r
#' schema <- table$schema()
#' str(schema)
#'
#' stats <- table$stats()
#' str(stats)
#' ```
#'
#' @section Optional dependencies:
#' `tibble` is optional and only needed if you plan to call `cursor$tibble()`.
#' Install optional packages as needed, e.g. `install.packages("tibble")`.
#'
#' @section Documentation and help:
#' Run `help(package = "odp")` or `??odp` for walkthroughs covering
#' installation, authentication, streaming helpers, and aggregations. Hosted docs
#' live at <https://docs.hubocean.earth/r_sdk/>. If you install the accompanying
#' vignettes they are accessible via `vignette("odp")` and
#' `vignette("odp-tabular")`.
#'
#' @docType package
#' @name odp
#' @aliases odp-package OceanDataPlatform
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
