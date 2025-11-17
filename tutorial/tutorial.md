# Ocean Data Platform (ODP) R SDK

The Ocean Data Platform exposes curated ocean datasets through a tabular API.
This R SDK mirrors the production Python SDK for read-only workflows so that R
users can authenticate, stream Arrow batches, and transform results into native
frames and tibbles.

> **Scope**: creating tables, inserting rows, or mutating data is intentionally
> out-of-scope for the initial release. The surface area focuses on reading data
> reliably.

## Installation

The SDK is distributed as an R package within this repository. From the project
root you can install it like any other local package:

```r
install.packages("r_sdk", repos = NULL, type = "source")
```

Load the package in your session via `library(odp)`.

## Authentication

`odp_client()` expects an API key. Provide it explicitly or via the
`ODP_API_KEY` environment variable or by passing it to the client on startup.

```r
client <- odp_client(api_key="Sk_....")
```

```r
Sys.setenv(ODP_API_KEY = "Sk_live_your_key")
client <- odp_client()
```

## Selecting Data

Work with tabular datasets by instantiating a dataset handler from the client
and then referencing its `table` field. `select()` returns an `OdpCursor`,
which you can materialise into a base `data.frame` when you want the entire
result in memory. If you prefer tibbles, install the optional `tibble`
package and call `cursor$tibble()`.

```r
dataset <- client$dataset("demo.dataset")
sightings <- dataset$table

cursor <- sightings$select(
  filter = "species == $name AND depth > $min_depth",
  vars = list(name = "Blue Whale", min_depth = 200),
  columns = c("latitude", "longitude", "depth")
)

whales <- cursor$dataframe()
# tibble users can opt in with: whales <- cursor$tibble()
```

### Streaming Results

Stay in streaming mode when you prefer to handle chunks as they arrive. The
cursor transparently fetches additional pages from the backend if the response
is split across multiple transfers.

```r
cursor <- sightings$select(filter = "depth > 200")

while (!is.null(chunk <- cursor$next_batch())) {
  cat("chunk rows:", chunk$num_rows, "\n")
  # next_batch() pulls additional pages automatically when needed
  # process the Arrow RecordBatch (e.g. cast to tibble, write to disk, etc.)
}

# Materialise whenever you're ready
result_df <- cursor$dataframe()
arrow_tbl <- cursor$arrow()
# Optional tibble helper
# result_tbl <- cursor$tibble()
```

> Materialisation helpers only drain batches that have not been streamed yet.
> To collect the full result after iterating with `next_batch()`, start a new
> cursor and call `dataframe()`/`collect()` before consuming chunks.

### Aggregating Groups

```r
agg <- sightings$aggregate(
  group_by = "'TOTAL'",
  filter = "depth > 200",
  aggr = list(mean_depth = "mean", max_temp = "max")
)
print(agg)
# Optional tibble helper
# agg_tbl <- sightings$aggregate_tibble(...)
```

Each entry in `aggr` names the column and describes the aggregation (`"sum"`,
`"min"`, `"max"`, `"count"`, or `"mean"`).

### Inspecting Schemas and Stats

Schema and stats endpoints are read-only helpers that map directly to the API:

```r
arrow_schema <- sightings$schema()
print(arrow_schema)

stats <- sightings$stats()
str(stats)
```
### Geospatial Filters

Everywhere a `filter` string is accepted you can leverage the same expression
language available in the Python SDK, including the geospatial helpers.

```r
bbox <- 'geo within "POLYGON ((0 0, 0 5, 5 5, 5 0, 0 0))"'
subset <- sightings$select(filter = bbox)
```

## Troubleshooting

- Ensure `arrow` is installed; the SDK relies on Arrow IPC streams for transport
- Increase the `timeout` argument when working with large scans
- Keep the `ODP_API_KEY` secret—never commit it to source control

With these primitives you can now incorporate ODP datasets into pipelines,
notebooks, and Shiny dashboards using idiomatic R workflows.
