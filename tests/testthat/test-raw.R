FakeRawClient <- R6::R6Class(
  "FakeRawClient",
  public = list(
    last_path = NULL,
    last_query = NULL,
    last_body = NULL,
    last_method = NULL,
    last_retry = NULL,
    json_response = NULL,
    arrow_response = NULL,
    raw_response = NULL,
    initialize = function(json_response = NULL, arrow_response = raw(0),
                          raw_response = raw(0)) {
      self$json_response <- json_response
      self$arrow_response <- arrow_response
      self$raw_response <- raw_response
    },
    request_json = function(path, query = NULL, body = NULL, method = "POST",
                            retry = TRUE) {
      self$last_path <- path
      self$last_query <- query
      self$last_body <- body
      self$last_method <- method
      self$last_retry <- retry
      self$json_response
    },
    request_arrow = function(path, query = NULL, body = NULL, method = "POST",
                             retry = TRUE) {
      self$last_path <- path
      self$last_query <- query
      self$last_body <- body
      self$last_retry <- retry
      self$arrow_response
    },
    request_raw = function(path, query = NULL, body = NULL, method = "POST",
                           retry = TRUE) {
      self$last_path <- path
      self$last_query <- query
      self$last_body <- body
      self$last_retry <- retry
      self$raw_response
    }
  )
)

test_that("list returns files from JSON response", {
  client <- FakeRawClient$new(json_response = list(
    files = list(
      list(id = "abc", name = "test.txt"),
      list(id = "def", name = "data.csv")
    )
  ))
  table <- OdpTable$new(client, "demo.table")
  files <- table$raw$list()
  expect_length(files, 2)
  expect_equal(files[[1]]$name, "test.txt")
  expect_equal(files[[2]]$name, "data.csv")
  expect_equal(client$last_path, "/api/table/v2/raw/list")
  expect_equal(client$last_query$table_id, "demo.table")
})

test_that("list passes query and vars", {
  client <- FakeRawClient$new(json_response = list(
    files = list(list(id = "abc", name = "test.csv"))
  ))
  table <- OdpTable$new(client, "demo.table")
  files <- table$raw$list(query = "name == $n", vars = list(n = "test.csv"))
  expect_length(files, 1)
  expect_equal(client$last_body$query, "name == 'test.csv'")
  expect_null(client$last_body$vars)
})

test_that("list returns empty list when no files exist", {
  client <- FakeRawClient$new(json_response = list(files = list()))
  table <- OdpTable$new(client, "demo.table")
  files <- table$raw$list()
  expect_length(files, 0)
})

test_that("upload sends raw data and returns raw_id", {
  client <- FakeRawClient$new(json_response = list(raw_id = "file-123"))
  table <- OdpTable$new(client, "demo.table")
  rid <- table$raw$upload("test.txt", charToRaw("Hello, world!"))
  expect_equal(rid, "file-123")
  expect_equal(client$last_path, "/api/table/v2/raw/upload")
  expect_equal(client$last_query$name, "test.txt")
  expect_true(is.raw(client$last_body))
  expect_false(client$last_retry)
})

test_that("upload accepts character data", {
  client <- FakeRawClient$new(json_response = list(raw_id = "file-456"))
  table <- OdpTable$new(client, "demo.table")
  rid <- table$raw$upload("test.txt", "Hello, world!")
  expect_equal(rid, "file-456")
  expect_true(is.raw(client$last_body))
  expect_equal(rawToChar(client$last_body), "Hello, world!")
})

test_that("upload rejects non-raw non-character data", {
  client <- FakeRawClient$new(json_response = list(raw_id = "x"))
  table <- OdpTable$new(client, "demo.table")
  expect_error(table$raw$upload("test.txt", 42), "raw vector or character")
})

test_that("download returns raw bytes", {
  payload <- charToRaw("file contents here")
  client <- FakeRawClient$new(raw_response = payload)
  table <- OdpTable$new(client, "demo.table")
  result <- table$raw$download("file-123")
  expect_equal(result, payload)
  expect_equal(client$last_path, "/api/table/v2/raw/download")
  expect_equal(client$last_query$id, "file-123")
  expect_true(client$last_retry)
})

test_that("delete calls correct endpoint", {
  client <- FakeRawClient$new(json_response = list())
  table <- OdpTable$new(client, "demo.table")
  result <- table$raw$delete("file-123")
  expect_null(result)
  expect_equal(client$last_path, "/api/table/v2/raw/delete")
  expect_equal(client$last_query$id, "file-123")
  expect_false(client$last_retry)
})

test_that("ingest calls correct endpoint with options", {
  client <- FakeRawClient$new(json_response = list())
  table <- OdpTable$new(client, "demo.table")
  result <- table$raw$ingest("file-123", opt = "truncate")
  expect_null(result)
  expect_equal(client$last_path, "/api/table/v2/raw/ingest")
  expect_equal(client$last_query$id, "file-123")
  expect_equal(client$last_query$opt, "truncate")
  expect_false(client$last_retry)
})

test_that("ingest defaults to append", {
  client <- FakeRawClient$new(json_response = list())
  table <- OdpTable$new(client, "demo.table")
  table$raw$ingest("file-123")
  expect_equal(client$last_query$opt, "append")
})

test_that("ingest validates opt parameter", {
  client <- FakeRawClient$new(json_response = list())
  table <- OdpTable$new(client, "demo.table")
  expect_error(table$raw$ingest("file-123", opt = "invalid"), "must be one of")
})

test_that("update_meta sends JSON-encoded body", {
  client <- FakeRawClient$new(json_response = list(ok = TRUE))
  table <- OdpTable$new(client, "demo.table")
  meta <- list(description = "updated file")
  table$raw$update_meta("file-123", meta)
  expect_equal(client$last_path, "/api/table/v2/raw/update_meta")
  expect_equal(client$last_query$id, "file-123")
  expect_true(is.raw(client$last_body))
  expect_false(client$last_retry)
  parsed <- jsonlite::fromJSON(rawToChar(client$last_body), simplifyVector = FALSE)
  expect_equal(parsed$description, "updated file")
})

test_that("dataset$files is an alias for table$raw", {
  withr::local_envvar(ODP_API_KEY = "test-key")
  client <- OdpClient$new()
  ds <- client$dataset("test-dataset")
  expect_identical(ds$files, ds$table$raw)
  expect_s3_class(ds$files, "OdpRaw")
})
