# Ocean Data Platform (ODP) R SDK

The Ocean Data Platform exposes curated ocean datasets through a tabular API.
This R SDK focuses on the same read-only workflows: authenticate, stream Arrow
batches, and transform results into native `data.frame`s and tibbles.

> **Scope**: writing/mutating tables is intentionally out-of-scope for this
> first port. The helpers cover inspecting tabular metadata, streaming Arrow
> batches, and performing server-backed aggregations.

## Installation

Install straight from GitHub (the examples below use `remotes`, but `pak` or
`devtools` work the same way). If you do not have `remotes` installed yet,
install it once via `install.packages("remotes")`.

```r
install.packages("remotes")  # skip if already installed
remotes::install_github("C4IROcean/odp-sdkr")
```

Load the package in your session via `library(odp)` after the installation
finishes.

## Authentication

`odp_client()` expects an API key. Provide it explicitly or via the
`ODP_API_KEY` environment variable or by passing it to the client on startup.

```r
client <- odp_client(api_key = "Sk_....")
```

```r
Sys.setenv(ODP_API_KEY = "Sk_live_your_key")
client <- odp_client()
```

## Connecting to a Dataset

Use the dataset ID that you would normally copy from the catalog UI
(<https://app.hubocean.earth/catalog>). The snippet below targets the public
GLODAP dataset:

```r
glodap <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")
table <- glodap$table
```

If the dataset has an attached tabular store you can now work with the table
using the helpers described below. When a dataset is not tabular the table calls
will raise errors.

## Tabular helpers

### `schema()`

The schema call returns the Arrow layout for the table so you can plan your
queries:

```r
schema <- table$schema()
print(schema)
```

### `select()`

`select()` returns an `OdpCursor` that lazily streams `arrow::RecordBatch`
chunks. Iterate with `next_batch()` or materialise into a `data.frame`, Arrow
`Table`, or tibble when you need the full result.

```r
cursor <- table$select()
while (!is.null(batch <- cursor$next_batch())) {
  cat("chunk rows:", batch$num_rows, "\n")
  # process or transform each RecordBatch on the fly
}

# collect into familiar structs when ready
df <- cursor$dataframe()
arrow_tbl <- cursor$arrow()
# optional tidyverse helper
# tib_tbl <- cursor$tibble()
```

> Materialisation helpers only drain batches that have not been streamed yet.
> To collect the full result after iterating with `next_batch()`, start a new
> cursor and call `dataframe()`/`collect()` before consuming chunks.

#### `filter`

Filters use SQL/Arrow-style expressions, including geospatial helpers such as
`within`, `contains`, and `intersect`.

```r
cursor <- table$select(filter = "G2year >= 2020 AND G2year < 2025")
```

```r
bbox <- 'geometry within "POLYGON ((-10 50, -5 50, -5 55, -10 55, -10 50))"'
cursor <- table$select(filter = bbox)
```

#### `columns`

Restrict the projection when you only need specific fields:

```r
cursor <- table$select(columns = c("G2tco2", "G2year"))
```

#### `vars`

Bind parameters inside the filter using either named or positional variables:

```r
cursor <- table$select(
  filter = "G2year >= $start AND G2year < $end",
  vars = list(start = 2020, end = 2025)
)

# positional form
table$select(filter = "G2year >= ? AND G2year < ?", vars = list(2020, 2025))
```

### `stats()`

Fetch read-only stats for the table:

```r
stats <- table$stats()
str(stats)
```

### Aggregations

`table$aggregate()` performs the heavy lifting on the backend and stitches
partials together locally.

```r
agg <- table$aggregate(
  group_by = "G2year",
  filter = "G2year >= 2020 AND G2year < 2025",
  aggr = list(G2salinity = "mean", G2tco2 = "max")
)
print(agg)
```

`aggr` entries specify which aggregation to apply (`"sum"`, `"min"`, `"max"`,
`"count"`, or `"mean"`). Advanced expressions such as `h3(geometry, 6)` or
`bucket(depth, 0, 200, 400)` are accepted in `group_by`.

## Troubleshooting

- Ensure `arrow` is installed; the SDK relies on Arrow IPC streams for transport
- Increase `timeout` when scanning very large tables
- Keep the `ODP_API_KEY` secret—never commit it to source control

These primitives let pipelines, Shiny dashboards, and notebooks pull from ODP
tabular datasets using idiomatic R.
