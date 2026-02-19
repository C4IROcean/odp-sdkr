fake_arrow_stream <- function(schema) {
  sink <- arrow::BufferOutputStream$create()
  writer <- arrow::RecordBatchStreamWriter$create(sink, schema)
  writer$close()
  sink$finish()$data()
}

FakeClient <- R6::R6Class(
  "FakeClient",
  public = list(
    arrow_payload = NULL,
    json_payload = NULL,
    request_log = NULL,
    initialize = function(arrow_payload = raw(0), json_payload = NULL) {
      self$arrow_payload <- arrow_payload
      self$json_payload <- json_payload
      self$request_log <- list()
    },
    request_arrow = function(path, query = NULL, body = NULL, ...) {
      self$request_log[[length(self$request_log) + 1]] <- list(
        path = path, query = query, body_length = length(body)
      )
      self$arrow_payload
    },
    request_json = function(...) {
      self$json_payload
    }
  )
)


test_that("schema returns Schema object when backend supplies Arrow stream", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(
    id = arrow::int64(),
    value = arrow::float64()
  )
  client <- FakeClient$new(arrow_payload = fake_arrow_stream(schema))
  table <- OdpTable$new(client, "demo.table")
  result <- table$schema()
  expect_s3_class(result, "Schema")
  expect_true(schema$Equals(result))
})

test_that("schema returns NULL when backend sends empty payload", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeClient$new(arrow_payload = raw(0))
  table <- OdpTable$new(client, "demo.table")
  expect_null(table$schema())
})

test_that("stats parses JSON payload into typed helper", {
  payload <- list(
    num_rows = 123,
    size = 2048,
    columns = list(
      list(
        name = "value",
        type = "float64",
        null_count = 0,
        num_values = 123,
        min = 0.1,
        max = 9.9
      )
    )
  )
  client <- FakeClient$new(json_payload = payload)
  table <- OdpTable$new(client, "demo.table")
  stats <- table$stats()
  expect_s3_class(stats, "odp_table_stats")
  expect_equal(stats$num_rows, 123)
  expect_equal(stats$size, 2048)
  expect_length(stats$columns, 1)
  expect_s3_class(stats$columns[[1]], "odp_column_stats")
  expect_equal(stats$columns[[1]]$name, "value")
})

test_that("create with Schema creates empty table", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int32(), y = arrow::string())
  client <- FakeClient$new()
  table <- OdpTable$new(client, "demo.table")
  
  result <- table$create(schema)
  
  expect_true(inherits(result, "OdpTable"))
  expect_length(client$request_log, 1)
  expect_equal(client$request_log[[1]]$path, "/api/table/v2/sdk/create")
})

test_that("create with empty dataframe creates empty table", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeClient$new()
  table <- OdpTable$new(client, "demo.table")
  df <- data.frame(x = integer(), y = character())
  
  result <- table$create(df)
  
  expect_true(inherits(result, "OdpTable"))
  expect_length(client$request_log, 1)
  expect_equal(client$request_log[[1]]$path, "/api/table/v2/sdk/create")
})
