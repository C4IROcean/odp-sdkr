test_that("validation rejects missing schema", {
  schema <- NULL
  df <- data.frame(x = 1, y = 2)
  expect_error(
    odp_validate_insert_data(df, schema),
    "Table schema is not available"
  )
})

test_that("validation skips empty dataframes", {
  schema <- arrow::schema(x = arrow::int64())
  df <- data.frame(x = integer())
  expect_null(odp_validate_insert_data(df, schema))
})

test_that("validation detects missing required columns", {
  schema <- arrow::schema(
    arrow::field("x", arrow::int64()),
    arrow::field("y", arrow::int64(), nullable = FALSE)
  )
  df <- data.frame(x = 1L)
  expect_error(
    odp_validate_insert_data(df, schema),
    "Missing required column: 'y'"
  )
})

test_that("validation passes valid data", {
  schema <- arrow::schema(
    x = arrow::int64(),
    y = arrow::string()
  )
  df <- data.frame(x = 1L, y = "abc")
  expect_null(odp_validate_insert_data(df, schema))
})
