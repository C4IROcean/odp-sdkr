cursor_key <- function(cursor) {
  if (is.null(cursor) || length(cursor) == 0 || !nzchar(cursor)) {
    return("__initial__")
  }
  cursor
}

cursor_page_raw <- function(df) {
  tab <- arrow::Table$create(df)
  sink <- arrow::BufferOutputStream$create()
  writer <- arrow::RecordBatchStreamWriter$create(sink, tab$schema)
  writer$write_table(tab)
  writer$close()
  sink$finish()$data()
}

fake_cursor_table <- function(pages) {
  env <- new.env(parent = emptyenv())
  env$pages <- pages
  env$select_request <- function(request, cursor = "") {
    key <- cursor_key(cursor)
    entry <- env$pages[[key]]
    if (is.null(entry)) {
      return(list(arrow = raw(0), cursor = NULL, trailer = NULL))
    }
    list(arrow = entry$raw, cursor = entry$cursor, trailer = NULL)
  }
  env
}

fake_cursor_request <- function(timeout = 30) {
  list(filter = "", columns = NULL, vars = NULL, timeout = timeout)
}

test_that("cursor reads chunks across multiple pages", {
  testthat::skip_if_not_installed("arrow")
  pages <- list(
    list(raw = cursor_page_raw(data.frame(id = 1:2)), cursor = "next"),
    list(raw = cursor_page_raw(data.frame(id = 3:4)), cursor = NULL)
  )
  names(pages) <- c(cursor_key(""), cursor_key("next"))
  cursor <- OdpCursor$new(table = fake_cursor_table(pages), request = fake_cursor_request())
  chunk1 <- cursor$next_batch()
  expect_s3_class(chunk1, "RecordBatch")
  expect_equal(chunk1$num_rows, 2)
  chunk2 <- cursor$next_batch()
  expect_s3_class(chunk2, "RecordBatch")
  expect_equal(chunk2$num_rows, 2)
  expect_null(cursor$next_batch())
})

test_that("cursor converts into arrow tables, data frames, and tibbles", {
  testthat::skip_if_not_installed("arrow")
  testthat::skip_if_not_installed("tibble")
  pages <- list(list(raw = cursor_page_raw(data.frame(id = 1:2)), cursor = NULL))
  names(pages) <- cursor_key("")
  cursor_df <- OdpCursor$new(table = fake_cursor_table(pages), request = fake_cursor_request())
  df <- cursor_df$dataframe()
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 2)

  cursor_tbl <- OdpCursor$new(table = fake_cursor_table(pages), request = fake_cursor_request())
  tbl <- cursor_tbl$arrow()
  expect_s3_class(tbl, "Table")
  expect_equal(tbl$num_rows, 2)

  cursor_tibble <- OdpCursor$new(table = fake_cursor_table(pages), request = fake_cursor_request())
  tib <- cursor_tibble$tibble()
  expect_s3_class(tib, "tbl_df")
  expect_equal(nrow(tib), 2)
})

test_that("collect resets and closes the active reader", {
  testthat::skip_if_not_installed("arrow")
  pages <- list(
    list(raw = cursor_page_raw(data.frame(id = 1:2)), cursor = "next"),
    list(raw = cursor_page_raw(data.frame(id = 3:4)), cursor = NULL)
  )
  names(pages) <- c(cursor_key(""), cursor_key("next"))
  cursor <- OdpCursor$new(table = fake_cursor_table(pages), request = fake_cursor_request())

  # Consume a batch to ensure the reader is active
  first_batch <- cursor$next_batch()
  expect_s3_class(first_batch, "RecordBatch")

  private <- cursor$.__enclos_env__$private
  reader <- private$state$reader
  expect_false(is.null(reader))
  closed <- FALSE
  proxy_reader <- new.env(parent = emptyenv())
  proxy_reader$schema <- reader$schema
  proxy_reader$read_next_batch <- function(...) reader$read_next_batch(...)
  proxy_reader$close <- function(...) {
    closed <<- TRUE
    reader$close(...)
  }
  private$state$reader <- proxy_reader

  tbl <- cursor$collect()
  expect_true(closed)
  expect_s3_class(tbl, "Table")
  expect_equal(tbl$num_rows, 4)
})
