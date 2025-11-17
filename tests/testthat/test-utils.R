test_that("binding preparation handles common types", {
  vars <- list(
    value = 1,
    name = "abc",
    day = as.Date("2024-01-01"),
    ts = as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  )
  prepared <- odp_prepare_bindings(vars)
  expect_equal(prepared$value, 1)
  expect_equal(prepared$name, "abc")
  expect_equal(prepared$day, "2024-01-01")
  expect_match(prepared$ts, "2024-01-01T12:00:00")
})

test_that("binding preparation rejects unnamed atomic vectors", {
  expect_error(odp_prepare_bindings(1:3))
})

test_that("timeout validation enforces positive scalar", {
  expect_error(odp_check_timeout(-1))
  expect_equal(odp_check_timeout(5), 5)
})

test_that("arrow trailer parsing extracts cursor token", {
  testthat::skip_if_not_installed("arrow")
  fake_client <- list(
    request_arrow = function(...) raw(0),
    request_json = function(...) list()
  )
  table <- OdpTable$new(fake_client, "demo.table")
  tab <- arrow::Table$create(data.frame(id = 1:2))
  sink <- arrow::BufferOutputStream$create()
  writer <- arrow::RecordBatchStreamWriter$create(sink, tab$schema)
  writer$write_table(tab)
  writer$close()
  arrow_raw <- sink$finish()$data()
  trailer <- list(started = "2024-01-01T00:00:00Z", ended = "2024-01-01T00:00:01Z", cursor = "token-1")
  raw <- c(arrow_raw, charToRaw(jsonlite::toJSON(trailer, auto_unbox = TRUE)))
  parts <- table$.__enclos_env__$private$split_arrow_trailer(raw)
  expect_true(length(parts$arrow) < length(raw))
  expect_equal(parts$trailer$cursor, "token-1")

  plain <- table$.__enclos_env__$private$split_arrow_trailer(arrow_raw)
  expect_null(plain$trailer)
  expect_equal(length(plain$arrow), length(arrow_raw))
})
