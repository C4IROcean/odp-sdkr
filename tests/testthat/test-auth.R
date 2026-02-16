# Tests for authentication module

test_that("odp_b2c_endpoints returns correct URLs", {
  endpoints <- odp_b2c_endpoints()

  expect_true(grepl("oceandataplatform.b2clogin.com", endpoints$auth_url))
  expect_true(grepl("oceandataplatform.b2clogin.com", endpoints$token_url))
  expect_true(grepl("/oauth2/v2.0/authorize", endpoints$auth_url))
  expect_true(grepl("/oauth2/v2.0/token", endpoints$token_url))
  expect_true(grepl("b2c_1a_signup_signin_custom", endpoints$auth_url))
})

test_that("odp_get_client_id uses environment variable when set", {
  withr::local_envvar(ODP_CLIENT_ID = "custom-client-id")
  expect_equal(odp_get_client_id(), "custom-client-id")
})

test_that("odp_get_client_id uses default when env var not set", {
  withr::local_envvar(ODP_CLIENT_ID = "")
  expect_equal(odp_get_client_id(), ODP_B2C_DEFAULT_CLIENT_ID)
})

test_that("odp_oauth_client creates valid oauth_client", {
  withr::local_envvar(ODP_CLIENT_ID = "")
  client <- odp_oauth_client()

  expect_s3_class(client, "httr2_oauth_client")
  expect_equal(client$id, ODP_B2C_DEFAULT_CLIENT_ID)
  expect_equal(client$name, "odp-sdk-r")
})

test_that("resolve_auth uses explicit api_key first", {
  withr::local_envvar(ODP_API_KEY = "env-key")
  client <- OdpClient$new(api_key = "explicit-key", interactive = FALSE)

  # Access private auth_header via environment
  auth_fn <- client$.__enclos_env__$private$auth_header
  expect_equal(auth_fn(), "ApiKey explicit-key")
})

test_that("resolve_auth falls back to ODP_API_KEY env var", {
  withr::local_envvar(ODP_API_KEY = "env-key")
  client <- OdpClient$new(interactive = FALSE)

  auth_fn <- client$.__enclos_env__$private$auth_header
  expect_equal(auth_fn(), "ApiKey env-key")
})

test_that("resolve_auth errors when no auth available and interactive disabled", {
  withr::local_envvar(ODP_API_KEY = "")

  expect_error(
    OdpClient$new(interactive = FALSE),
    "Unable to authenticate"
  )
})

test_that("odp_client passes interactive parameter correctly", {
  withr::local_envvar(ODP_API_KEY = "test-key")

  # Should work with interactive = FALSE when API key is set

  client <- odp_client(interactive = FALSE)
  expect_s3_class(client, "OdpClient")
})
