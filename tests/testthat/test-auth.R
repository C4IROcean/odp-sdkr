# Tests for authentication resolution

test_that("resolve_auth uses explicit api_key first", {
  withr::local_envvar(ODP_API_KEY = "env-key")
  client <- OdpClient$new(api_key = "explicit-key")

  # Access private auth_header via environment
  auth_fn <- client$.__enclos_env__$private$auth_header
  expect_equal(auth_fn(), "ApiKey explicit-key")
})

test_that("resolve_auth falls back to ODP_API_KEY env var", {
  withr::local_envvar(ODP_API_KEY = "env-key")
  client <- OdpClient$new()

  auth_fn <- client$.__enclos_env__$private$auth_header
  expect_equal(auth_fn(), "ApiKey env-key")
})

test_that("resolve_auth errors when no API key is available", {
  withr::local_envvar(ODP_API_KEY = "")

  expect_error(
    OdpClient$new(),
    "Unable to authenticate"
  )
})

test_that("odp_client builds a client from the API key", {
  withr::local_envvar(ODP_API_KEY = "test-key")

  client <- odp_client()
  expect_s3_class(client, "OdpClient")
})
