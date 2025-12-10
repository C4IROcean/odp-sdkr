# Ocean Data Platform R SDK

The Ocean Data Platform (ODP) is a hosted catalog of curated marine and
environmental datasets. This package provides light-weight R bindings so you can
authenticate with your HubOcean account, navigate to a dataset, pick a table,
and stream rows straight into data frames or Arrow tables without leaving your
analysis workflow. The SDK currently focuses on read-only helpers. More
capabilities will arrive as the project matures.

When you work with the SDK you will usually touch the following pieces:

- `odp_client()` — holds your API key and issues authenticated requests
- dataset object — retrieved via `client$dataset("<dataset-id>")`
- table object — accessed via `dataset$table`
- cursor — returned from `table$select()` and responsible for paging data

The sections below walk through that flow so anyone landing here (including via
`?odp`) quickly sees how to get from credentials to a usable tibble.

> Status: This sdk is still considered pre-release. We are looking for feedback,
> so please reach out if you have any issues, concerns or other ideas that you
> think can improve your experience using this sdk.

## Requirements

- R 4.1 or newer
- Packages declared in `DESCRIPTION` (install with `pak`, `renv`, or
  `install.packages()`)
- A valid HubOcean API key exposed as the env variable `ODP_API_KEY` or passed
  directly when creating the client. Grab the key from [My Account in the web
  app](https://app.hubocean.earth/account).

## Getting Started

The snippet below shows the full flow: install, authenticate, navigate to a
dataset, pick a table, and stream the columns you care about. Swap the dataset
ID for the resources you have access to in the ODP catalog.

```r
# install straight from GitHub (requires remotes, pak, or devtools)
install.packages("remotes")  # skip if already installed
remotes::install_github("C4IROcean/odp-sdkr")

# local checkout? make sure vignettes are built
# remotes::install_local("~/dev/odp_sdkr", build = TRUE, build_vignettes = TRUE)

library(odp)

# 1. Client (API key can come from ODP_API_KEY)
client <- odp_client(api_key = "Sk_....")

# 2. Dataset (see https://app.hubocean.earth/)
dataset <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")

# 3. Table (defaults to the first table in the dataset)
table <- dataset$table

# 4. Query – returns a cursor that streams rows lazily
cursor <- table$select(
  filter = "depth > $min_depth",
  vars = list(min_depth = 300),
  columns = c("latitude", "longitude", "depth"),
  timeout = 15
)

# 5. Fetch table into a dataframe that you can use for analysis
df <- cursor$dataframe()
```

## Documentation

The hosted documentation at https://docs.hubocean.earth/r_sdk/ is the canonical
place to learn more about authentication, cursors, batching, and advanced
patterns. Install the package locally and lean on the official docs when you
need deeper explanations or diagrams.

- `help(package = "odp")` gives a quick index of the exported helpers

### Streaming rows in batches
When working with a large table it can be helpful to fetch the table in batches, to do this you can use the next_batch helper to iterate over the batches one by one. The cursor will fetch the pages in chunks in the background when you need them

```r
cursor <- table$select()
while (!is.null(chunk <- cursor$next_batch())) {
  print(chunk$num_rows)
}

# Convert on demand
df <- cursor$dataframe()
arrow_tbl <- cursor$arrow()
# tibble support is optional
# tib_tbl <- cursor$tibble()
```

> `collect()`/`dataframe()`/`tibble()`/`arrow()` only materialise batches that
> have not been streamed yet. To obtain the full dataset after calling
> `next_batch()`, create a fresh cursor and collect before iterating.

### Aggregations

The sdk supports server side aggregations. This can be useful if you want to compute simple statistics without transfering all of the table data
```r
agg <- table$aggregate(
  group_by = "'TOTAL'",
  filter = "depth > 200",
  aggr = list(depth = "mean")
)
print(agg)
```

> Pass an `aggr` named list where each entry specifies how the column should be
> aggregated (`"sum"`, `"min"`, `"max"`, `"count"`, `"mean"`).

### Metadata helpers
```r
schema <- table$schema()
str(schema)

stats <- table$stats()
str(stats)
```

### Optional dependencies

- `tibble` (only if you want `cursor$tibble()`)

Install optional packages as needed, for example: `install.packages("tibble")`.

## Development

- Install the package dependencies declared in `DESCRIPTION` and keep a recent
  version of `devtools`/`pkgload` around for running checks.
- Run the unit tests with `R -q -e "devtools::test()"` and the full
  `devtools::check()` suite locally before opening a pull request. Tests use
  small synthetic Arrow streams, so they never call the live API.
- The repo ships a `.pre-commit-config.yaml` that runs `lintr` and `styler`
  through the helper scripts in `scripts/`. Install [pre-commit](https://pre-commit.com)
  once per machine and enable the hooks with `pre-commit install` to get the
  same linting enforced in CI.
- To lint/format everything manually (matching CI), run:

  ```sh
  Rscript --vanilla scripts/precommit_lintr.R $(git ls-files -- '*.R' '*.r' '*.Rmd' '*.rmd')
  Rscript --vanilla scripts/precommit_styler.R $(git ls-files -- '*.R' '*.r' '*.Rmd' '*.rmd')
  ```

- GitHub Actions keeps parity with the local tooling:
  `.github/workflows/lint-format-test.yml` runs the linters, formatting check,
  and the package's `testthat` suite (`devtools::test()`) on every push/PR.
- Build-able vignettes (`vignette("odp")`, `vignette("odp-tabular")`) ship with
  the repo; install with `build_vignettes = TRUE` if you want those walkthroughs
  available offline.
