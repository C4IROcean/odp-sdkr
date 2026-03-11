FakeTxClient <- R6::R6Class(
  "FakeTxClient",
  public = list(
    responses = NULL,
    call_log = NULL,
    initialize = function(responses = list()) {
      self$responses <- responses
      self$call_log <- list()
    },
    request_json = function(path, query = NULL, body = NULL, method = "GET", retry = TRUE) {
      self$call_log[[length(self$call_log) + 1]] <- list(
        path = path, query = query, method = method
      )
      if (path == "/api/table/v2/sdk/begin") {
        return(list(tx_id = "tx-123"))
      }
      self$responses[[path]]
    },
    request_arrow = function(path, query = NULL, body = NULL, method = "POST", retry = TRUE) {
      self$call_log[[length(self$call_log) + 1]] <- list(
        path = path, query = query, method = method
      )
      raw(0)
    }
  )
)

FakeTableTx <- R6::R6Class(
  "FakeTableTx",
  public = list(
    id = "demo.table",
    client = NULL,
    schema_obj = NULL,
    initialize = function(client, schema_obj) {
      self$client <- client
      self$schema_obj <- schema_obj
    },
    schema = function() {
      self$schema_obj
    },
    select_request = function(request, cursor = "", retry = TRUE) {
      list(arrow = raw(0), cursor = NULL, trailer = NULL)
    }
  )
)

test_that("transaction fails if schema is unavailable", {
  testthat::skip_if_not_installed("arrow")
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, NULL)

  expect_error(
    OdpTransaction$new(table, "tx-123"),
    "Table schema is not available"
  )
})

test_that("transaction initializes with valid schema", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64(), y = arrow::float64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  expect_equal(tx$.__enclos_env__$private$tx_id, "tx-123")
  expect_true(!is.null(tx$.__enclos_env__$private$schema))
})

test_that("transaction rejects unnamed list input", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  expect_error(
    tx$insert(list(1, 2, 3)),
    "must be a Schema, data frame, RecordBatch, or Arrow Table"
  )
})

test_that("transaction accepts named list input", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  result <- tx$insert(list(x = 1L))
  expect_true(inherits(result, "OdpTransaction"))
})

test_that("transaction skips empty dataframes", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  result <- tx$insert(data.frame(x = integer()))
  expect_true(is.null(result) || inherits(result, "OdpTransaction"))
})

test_that("transaction prevents inserting into committed transaction", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  tx$commit()

  expect_error(
    tx$insert(data.frame(x = 1L)),
    "Cannot insert into a committed transaction"
  )
})

test_that("transaction buffers data and validates schema", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int32())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  df <- data.frame(x = 1L)
  result <- tx$insert(df)
  expect_true(inherits(result, "OdpTransaction"))
})

test_that("transaction allows multiple inserts before commit", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int32(), y = arrow::string())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  tx$insert(data.frame(x = 1L, y = "Alice"))
  tx$insert(data.frame(x = 2L, y = "Bob"))
  result <- tx$commit()
  expect_true(inherits(result, "OdpTransaction"))
})

test_that("transaction fails commit if already committed", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  tx$commit()

  expect_error(
    tx$commit(),
    "Transaction already committed"
  )
})

test_that("transaction fails rollback if already committed", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  tx$commit()

  expect_error(
    tx$rollback(),
    "Cannot rollback a committed transaction"
  )
})
test_that("transaction select returns a cursor", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64(), y = arrow::string())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  cursor <- tx$select(filter = "x > 5")
  expect_true(inherits(cursor, "OdpCursor"))
})

test_that("transaction replace requires a filter", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  expect_error(
    tx$replace(),
    "For your own safety, a filter is required"
  )
})

test_that("transaction replace with filter returns a cursor", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  cursor <- tx$replace(filter = "x > 10")
  expect_true(inherits(cursor, "OdpCursor"))
})

test_that("transaction replace accepts query parameter", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  cursor <- tx$replace(query = "x <= 5")
  expect_true(inherits(cursor, "OdpCursor"))
})

test_that("transaction delete returns row count", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(x = arrow::int64())
  client <- FakeTxClient$new()
  table <- FakeTableTx$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  count <- tx$delete(query = "x == 0")
  expect_true(is.integer(count))
  expect_equal(count, 0L)
})

test_that("transaction replace allows row-by-row iteration and modification", {
  testthat::skip_if_not_installed("arrow")
  schema <- arrow::schema(id = arrow::int64(), value = arrow::float64())
  client <- FakeTxClient$new()

  mock_batch <- arrow::RecordBatch$create(
    id = c(1L, 2L),
    value = c(5.0, 10.0),
    schema = schema
  )

  table <- R6::R6Class(
    "MockTable",
    public = list(
      id = "test.table",
      client = NULL,
      schema_obj = NULL,
      initialize = function(client, schema_obj) {
        self$client <- client
        self$schema_obj <- schema_obj
      },
      schema = function() {
        self$schema_obj
      },
      select_request = function(request, cursor = "", retry = TRUE) {
        if (request$operation == "replace") {
          buf <- arrow::BufferOutputStream$create()
          writer <- arrow::RecordBatchStreamWriter$create(buf, schema = mock_batch$schema)
          writer$write(mock_batch)
          writer$close()
          return(list(arrow = buf$finish()$data(), cursor = NULL, trailer = NULL))
        }
        list(arrow = raw(0), cursor = NULL, trailer = NULL)
      }
    )
  )$new(client, schema)

  tx <- OdpTransaction$new(table, "tx-123")
  cursor <- tx$replace(filter = "id == 1")

  rows <- cursor$rows()
  expect_true(is.list(rows))
  expect_equal(length(rows), 2)

  for (row in rows) {
    row$value <- row$value * 2
    tx$insert(row)
  }

  expect_true(TRUE)
})
