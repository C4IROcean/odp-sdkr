# Ocean Data Platform R SDK

Lightweight R bindings for the Ocean Data Platform services.
The SDK focuses on authenticated access to tabular datasets exposed by the
HubOcean API and currently provides read-only helpers for inspecting
metadata and streaming batches into familiar R data structures.

> **Status**: read-only. Creating, inserting, or mutating tables is purposely
> unavailable in this version. Please reach out if there are capabilities that
> could be useful for you, and we will consider whether it is something we can
> support.

## Requirements

- R 4.1 or newer
- Packages declared in `DESCRIPTION` (install with `pak`, `renv`, or
  `install.packages()`)
- A valid HubOcean API key exposed as the env variable `ODP_API_KEY` or passed
directly when creating the client. The API key can be found by visiting ["My account"
in the wep app](https://app.hubocean.earth/account).

## Getting Started

```r
# install straight from GitHub (requires remotes, pak, or devtools)
install.packages("remotes")  # skip if already installed
remotes::install_github("C4IROcean/odp-sdkr")

library(odp)
client <- odp_client(api_key="Sk_....")

dataset <- client$dataset("demo.table.id")
sightings <- dataset$table
cursor <- sightings$select(
  filter = "depth > $min_depth",
  vars = list(min_depth = 300),
  columns = c("latitude", "longitude", "depth"),
  timeout = 15
)

# Materialise the cursor when you want the full result
result <- cursor$dataframe()
print(result)
# optional tidyverse helper (requires the tibble package)
# tib_result <- cursor$tibble()
```

### Streaming rows in batches
When working with a large table it can be helpful to fetch the table in batches, to do this you can use the next_batch helper to iterate over the batches one by one. The cursor will fetch the pages in chunks in the background when you need them

```r
cursor <- sightings$select()
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

```r
agg <- table$aggregate(
  group_by = "'TOTAL'",
  filter = "depth > 200",
  aggr = list(mean_depth = "mean")
)
print(agg)
# tibble support
# table$aggregate_tibble(...)
```

> Pass an `aggr` named list where each entry specifies how the column should be
> aggregated (`"sum"`, `"min"`, `"max"`, `"count"`, `"mean"`). When no
> aggregations are defined on the server schema you must supply this argument.

### Metadata helpers

```r
schema <- sightings$schema()
str(schema)

stats <- sightings$stats()
str(stats)
```

### Optional dependencies

- `tibble` (only if you want `cursor$tibble()`)

Install optional packages as needed, for example: `install.packages("tibble")`.

## Development

- Linting/tests: `R -q -e "devtools::test()"`
- Package metadata lives under `DESCRIPTION`/`NAMESPACE`
- Unit tests avoid live network calls and use small synthetic Arrow streams
