stream_key <- function(cursor) {
  if (is.null(cursor) || length(cursor) == 0 || !nzchar(cursor)) {
    return("__initial__")
  }
  cursor
}

sample_stream <- function(df, cursor = NULL) {
  testthat::skip_if_not_installed("arrow")
  if (is.null(df)) {
    df <- data.frame(id = numeric(), value = character(), stringsAsFactors = FALSE)
  }
  tab <- arrow::Table$create(df)
  sink <- arrow::BufferOutputStream$create()
  writer <- arrow::RecordBatchStreamWriter$create(sink, schema = tab$schema)
  writer$write_table(tab)
  writer$close()
  trailer <- list(
    started = "2024-01-01T00:00:00Z",
    ended = "2024-01-01T00:00:01Z"
  )
  if (!is.null(cursor)) {
    trailer$cursor <- cursor
  }
  c(sink$finish()$data(), charToRaw(jsonlite::toJSON(trailer, auto_unbox = TRUE)))
}

FakeSelectClient <- R6::R6Class(
  "FakeSelectClient",
  public = list(
    streams = NULL,
    last_request = NULL,
    json_payload = NULL,
    aggregate_stream = raw(0),
    initialize = function(stream = raw(0), json_payload = NULL, streams = NULL, aggregate_stream = raw(0)) {
      if (!is.null(streams)) {
        keys <- names(streams) %||% character(length(streams))
        norm <- vapply(keys, stream_key, character(1))
        names(streams) <- norm
        self$streams <- streams
      } else {
        self$streams <- list(stream)
        names(self$streams) <- stream_key("")
      }
      self$json_payload <- json_payload
      self$aggregate_stream <- aggregate_stream
    },
    request_arrow = function(path, query = NULL, body = NULL, ...) {
      if (grepl("/aggregate$", path)) {
        self$last_request <- list(path = path, query = query, body = body)
        return(self$aggregate_stream %||% raw(0))
      }
      cursor <- stream_key(body$cursor %||% "")
      self$last_request <- list(path = path, query = query, body = body)
      stream <- self$streams[[cursor]]
      if (is.null(stream)) {
        cli::cli_abort(sprintf("No stream configured for cursor '%s'", body$cursor %||% ""))
      }
      stream
    },
    request_json = function(...) {
      self$json_payload
    }
  )
)

TestOdpTable <- R6::R6Class(
  "TestOdpTable",
  inherit = OdpTable,
  public = list(
    schema_override = NULL,
    initialize = function(client, table_id, schema_override = NULL) {
      super$initialize(client, table_id)
      self$schema_override <- schema_override
    },
    schema = function(timeout = 5) {
      if (!is.null(self$schema_override)) {
        return(self$schema_override)
      }
      super$schema(timeout = timeout)
    }
  )
)

fake_schema <- function(fields) {
  list(
    num_fields = length(fields),
    field = function(idx) {
      fields[[idx + 1]]
    }
  )
}

aggregate_stream <- function(dfs) {
  testthat::skip_if_not_installed("arrow")
  if (!length(dfs)) {
    return(raw(0))
  }
  tab <- arrow::Table$create(dfs[[1]])
  sink <- arrow::BufferOutputStream$create()
  writer <- arrow::RecordBatchStreamWriter$create(sink, schema = tab$schema)
  for (df in dfs) {
    writer$write_table(arrow::Table$create(df))
  }
  writer$close()
  sink$finish()$data()
}

test_that("select returns cursor that can collect to tibble", {
  testthat::skip_if_not_installed("arrow")
  df <- data.frame(id = 1:3, value = letters[1:3], stringsAsFactors = FALSE)
  client <- FakeSelectClient$new(stream = sample_stream(df))
  table <- OdpTable$new(client, "demo.table")
  cursor <- table$select()
  expect_s3_class(cursor, "OdpCursor")
  tbl <- cursor$collect()
  expect_s3_class(tbl, "Table")
  df_result <- as.data.frame(tbl)
  expect_equal(df_result$id, df$id)
  expect_equal(df_result$value, df$value)
})

test_that("select forwards filters, columns, and vars", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeSelectClient$new(stream = sample_stream(data.frame(id = numeric())))
  vars <- list(name = "abc", day = as.Date("2024-01-01"))
  table <- OdpTable$new(client, "demo.table")
  cursor <- table$select(filter = "value > 0", columns = c("id", "value"), vars = vars, timeout = 10)
  expect_s3_class(cursor, "OdpCursor")
  cursor$next_batch() # trigger a request
  expect_equal(client$last_request$path, "/api/table/v2/sdk/select")
  expect_equal(client$last_request$query$table_id, "demo.table")
  expect_equal(client$last_request$body$query, "value > 0")
  expect_equal(client$last_request$body$cols, c("id", "value"))
  expect_equal(client$last_request$body$timeout, 10)
  expect_equal(client$last_request$body$vars$name, "abc")
  expect_equal(client$last_request$body$vars$day, "2024-01-01")
  expect_equal(client$last_request$body$cursor, "")
})

test_that("select returns empty cursor when stream is empty", {
  testthat::skip_if_not_installed("arrow")
  empty_df <- data.frame(id = numeric(), value = character(), stringsAsFactors = FALSE)
  client <- FakeSelectClient$new(stream = sample_stream(empty_df))
  table <- OdpTable$new(client, "demo.table")
  cursor <- table$select()
  empty_tbl <- cursor$collect()
  expect_s3_class(empty_tbl, "Table")
  expect_equal(empty_tbl$num_rows, 0)
})

test_that("select follows backend cursors for additional pages", {
  testthat::skip_if_not_installed("arrow")
  df1 <- data.frame(id = 1:2, stringsAsFactors = FALSE)
  df2 <- data.frame(id = 3:4, stringsAsFactors = FALSE)
  streams <- list(
    sample_stream(df1, cursor = "next-token"),
    sample_stream(df2)
  )
  names(streams) <- c("", "next-token")
  client <- FakeSelectClient$new(streams = streams)
  table <- OdpTable$new(client, "demo.table")
  cursor <- table$select()
  chunk1 <- cursor$next_batch()
  expect_equal(chunk1$num_rows, 2)
  chunk2 <- cursor$next_batch()
  expect_equal(chunk2$num_rows, 2)
  expect_null(cursor$next_batch())
})

test_that("aggregate reduces partial batches", {
  testthat::skip_if_not_installed("arrow")
  df1 <- data.frame(
    key = c("TOTAL", "A"),
    value_sum = c(10, 4),
    value_count = c(2, 1),
    stringsAsFactors = FALSE
  )
  df2 <- data.frame(
    key = c("TOTAL", "A"),
    value_sum = c(6, 5),
    value_count = c(3, 2),
    stringsAsFactors = FALSE
  )
  names(df1)[1] <- names(df2)[1] <- ".group"
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df1, df2))
  )
  table <- OdpTable$new(client, "demo.table")
  result <- table$aggregate(group_by = "'TOTAL'", filter = "depth > 100", aggr = list(value = "mean"))
  expect_equal(client$last_request$path, "/api/table/v2/sdk/aggregate")
  expect_equal(client$last_request$body$by, "'TOTAL'")
  expect_equal(client$last_request$body$query, "depth > 100")
  expect_equal(result$group, c("TOTAL", "A"))
  expect_equal(result$value, c(3.2, 3))
})

test_that("aggregate preserves non-numeric aggregation types", {
  testthat::skip_if_not_installed("arrow")
  timestamps1 <- as.POSIXct(c("2024-01-01 00:00:00", "2024-01-02 12:00:00"), tz = "UTC")
  timestamps2 <- as.POSIXct(c("2024-01-03 00:00:00", "2024-01-01 12:30:00"), tz = "UTC")
  df1 <- data.frame(
    .group = c("TOTAL", "A"),
    name_min = c("mackerel", "herring"),
    observed_at_max = timestamps1,
    stringsAsFactors = FALSE
  )
  df2 <- data.frame(
    .group = c("TOTAL", "A"),
    name_min = c("anchovy", "salmon"),
    observed_at_max = timestamps2,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df1, df2))
  )
  schema_override <- fake_schema(list(
    list(name = "name", metadata = NULL),
    list(name = "observed_at", metadata = NULL)
  ))
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema_override)
  result <- table$aggregate(
    group_by = "geo",
    aggr = list(name = "min", observed_at = "max")
  )
  expect_equal(result$group, c("TOTAL", "A"))
  expect_equal(result$name, c("anchovy", "herring"))
  expect_s3_class(result$observed_at, "POSIXct")
  expect_equal(result$observed_at, as.POSIXct(c("2024-01-03 00:00:00", "2024-01-02 12:00:00"), tz = "UTC"))
})

test_that("aggregate forwards vars and timeout", {
  testthat::skip_if_not_installed("arrow")
  vars <- list(since = as.Date("2024-02-01"), depth = 100)
  df <- data.frame(
    .group = "TOTAL",
    value_sum = 5,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  schema_override <- fake_schema(list(list(name = "value", metadata = NULL)))
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema_override)
  result <- table$aggregate(group_by = "geo", vars = vars, timeout = 12, aggr = list(value = "sum"))
  expect_equal(client$last_request$body$vars$depth, 100)
  expect_equal(client$last_request$body$vars$since, "2024-02-01")
  expect_equal(client$last_request$body$timeout, 12)
  expect_equal(result$value, 5)
})

test_that("aggregate requires explicit aggr when schema metadata missing", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeSelectClient$new(stream = sample_stream(data.frame(id = numeric())))
  table <- OdpTable$new(client, "demo.table")
  expect_error(table$aggregate(), "Provide `aggr`")
})

test_that("aggregate handles numeric group keys", {
  testthat::skip_if_not_installed("arrow")
  df <- data.frame(
    .group = c(1L, 2L),
    value_sum = c(10, 20),
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  table <- OdpTable$new(client, "demo.table")
  res <- table$aggregate(group_by = "id", aggr = list(value = "sum"))
  expect_equal(res$group, c(1, 2))
  expect_equal(res$value, c(10, 20))
})

test_that("aggregate produces empty result with group column when backend empty", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeSelectClient$new(stream = sample_stream(data.frame(id = numeric())))
  schema_override <- fake_schema(list(list(name = "value", metadata = NULL)))
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema_override)
  res <- table$aggregate(group_by = "geo", aggr = list(value = "sum"))
  expect_true("group" %in% names(res))
  expect_equal(nrow(res), 0)
})

test_that("aggregate infers aggregations from schema metadata", {
  testthat::skip_if_not_installed("arrow")
  schema <- fake_schema(list(list(name = "value", metadata = list(aggr = charToRaw("sum")))))
  df <- data.frame(
    .group = "TOTAL",
    value_sum = 7,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema)
  res <- table$aggregate(group_by = "geo")
  expect_equal(client$last_request$body$aggr$value, "sum")
  expect_equal(res$value, 7)
})

test_that("aggregate errors for unsupported aggregation type", {
  testthat::skip_if_not_installed("arrow")
  df <- data.frame(
    .group = "TOTAL",
    value_sum = 2,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  schema_override <- fake_schema(list(list(name = "value", metadata = NULL)))
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema_override)
  expect_error(table$aggregate(aggr = list(value = "median")), "Unknown aggregation type")
})

test_that("aggregate average handles zero counts", {
  testthat::skip_if_not_installed("arrow")
  df <- data.frame(
    .group = "TOTAL",
    value_sum = 4,
    value_count = 0,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  table <- OdpTable$new(client, "demo.table")
  res <- table$aggregate(group_by = "geo", aggr = list(value = "mean"))
  expect_true(is.na(res$value))
})

test_that("aggregate fails when backend omits required columns", {
  testthat::skip_if_not_installed("arrow")
  df <- data.frame(
    .group = "TOTAL",
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  schema_override <- fake_schema(list(list(name = "value", metadata = NULL)))
  table <- TestOdpTable$new(client, "demo.table", schema_override = schema_override)
  expect_error(
    table$aggregate(group_by = "geo", aggr = list(value = "sum")),
    "missing column"
  )
})

test_that("aggregate_tibble converts results", {
  testthat::skip_if_not_installed("arrow")
  testthat::skip_if_not_installed("tibble")
  df <- data.frame(
    .group = "TOTAL",
    value_sum = 3,
    stringsAsFactors = FALSE
  )
  client <- FakeSelectClient$new(
    stream = sample_stream(data.frame(id = numeric())),
    aggregate_stream = aggregate_stream(list(df))
  )
  table <- OdpTable$new(client, "demo.table")
  tbl <- table$aggregate_tibble(group_by = "geo", aggr = list(value = "sum"))
  expect_s3_class(tbl, "tbl_df")
  expect_equal(tbl$value, 3)
})
