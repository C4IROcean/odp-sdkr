# Tests for catalog module

# Create a mock OdpClient class for testing
MockOdpClient <- R6::R6Class(
  "OdpClient",
  public = list(
    base_url = "https://api.hubocean.earth",
    mock_response = NULL,
    mock_status = 200,
    initialize = function(response = list(), status = 200) {
      self$mock_response <- response
      self$mock_status <- status
    },
    request_json = function(path, query = NULL, body = NULL, method = "GET", retry = TRUE) {
      if (self$mock_status == 404) {
        cli::cli_abort(
          "Not found",
          class = c("odp_http_404", "odp_http_not_found", "odp_http_error")
        )
      }
      self$mock_response
    }
  )
)

mock_client <- function(response = list(), status = 200) {
  MockOdpClient$new(response = response, status = status)
}

test_that("odp_create_dataset returns dataset metadata", {
  mock_response <- list(
    id = "test-uuid-123",
    name = "test-dataset",
    description = "A test dataset"
  )

  client <- mock_client(mock_response)

  result <- odp_create_dataset(client, "test-dataset", "A test dataset")

  expect_type(result, "list")
  expect_equal(result$id, "test-uuid-123")
  expect_equal(result$name, "test-dataset")
  expect_equal(result$description, "A test dataset")
})

test_that("odp_create_dataset requires valid client", {
  expect_error(
    odp_create_dataset("not-a-client", "name"),
    "must be an OdpClient"
  )
})

test_that("odp_create_dataset requires non-empty name", {
  client <- mock_client()

  expect_error(odp_create_dataset(client, ""), "non-empty string")
  expect_error(odp_create_dataset(client, NULL), "non-empty string")
})

test_that("odp_list_datasets returns data frame", {
  mock_response <- list(
    list(id = "uuid-1", name = "dataset-1", description = "First"),
    list(id = "uuid-2", name = "dataset-2", description = "Second")
  )

  client <- mock_client(mock_response)

  result <- odp_list_datasets(client)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_equal(result$id, c("uuid-1", "uuid-2"))
  expect_equal(result$name, c("dataset-1", "dataset-2"))
  expect_equal(result$description, c("First", "Second"))
})

test_that("odp_list_datasets returns empty data frame when no datasets", {
  client <- mock_client(list())

  result <- odp_list_datasets(client)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("id", "name", "description"))
})

test_that("odp_get_dataset_by_name returns matching dataset", {
  mock_response <- list(
    list(id = "uuid-1", name = "dataset-1", description = "First"),
    list(id = "uuid-2", name = "target-dataset", description = "Target")
  )

  client <- mock_client(mock_response)

  result <- odp_get_dataset_by_name(client, "target-dataset")

  expect_type(result, "list")
  expect_equal(result$id, "uuid-2")
  expect_equal(result$name, "target-dataset")
  expect_equal(result$description, "Target")
})

test_that("odp_get_dataset_by_name returns NULL when not found", {
  mock_response <- list(
    list(id = "uuid-1", name = "dataset-1", description = "First")
  )

  client <- mock_client(mock_response)

  result <- odp_get_dataset_by_name(client, "nonexistent")

  expect_null(result)
})

test_that("odp_get_dataset_by_uuid returns dataset metadata", {
  mock_response <- list(
    id = "123e4567-e89b-12d3-a456-426614174000",
    name = "test-dataset",
    description = "A test dataset"
  )

  client <- mock_client(mock_response)

  result <- odp_get_dataset_by_uuid(client, "123e4567-e89b-12d3-a456-426614174000")

  expect_type(result, "list")
  expect_equal(result$id, "123e4567-e89b-12d3-a456-426614174000")
  expect_equal(result$name, "test-dataset")
  expect_equal(result$description, "A test dataset")
})

test_that("odp_get_dataset_by_uuid returns NULL on 404", {
  client <- mock_client(status = 404)

  result <- odp_get_dataset_by_uuid(client, "123e4567-e89b-12d3-a456-426614174000")

  expect_null(result)
})

test_that("odp_get_dataset_by_uuid requires non-empty uuid", {
  client <- mock_client()

  expect_error(
    odp_get_dataset_by_uuid(client, ""),
    "non-empty"
  )
})
