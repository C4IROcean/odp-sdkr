# Azure B2C OAuth2 configuration for HubOcean
# These values match the Python SDK's InteractiveTokenProvider

ODP_B2C_TENANT <- "oceandataplatform"
ODP_B2C_POLICY <- "b2c_1a_signup_signin_custom"
ODP_B2C_DEFAULT_CLIENT_ID <- "f96fc4a5-195b-43cc-adb2-10506a82bb82"
ODP_B2C_SCOPE <- "https://oceandataplatform.onmicrosoft.com/odcat/API_ACCESS"

#' Build Azure B2C OAuth2 endpoints
#'
#' @param tenant B2C tenant name
#' @param policy B2C policy name
#' @return List with auth_url and token_url
#' @keywords internal
#' @noRd
odp_b2c_endpoints <- function(tenant = ODP_B2C_TENANT, policy = ODP_B2C_POLICY) {

  base <- sprintf(
    "https://%s.b2clogin.com/%s.onmicrosoft.com/%s/oauth2/v2.0",
    tenant, tenant, policy
  )

  list(
    auth_url = paste0(base, "/authorize"),
    token_url = paste0(base, "/token")
  )
}

#' Get the OAuth2 client ID for interactive authentication
#'
#' Resolves from ODP_CLIENT_ID environment variable or uses the default.
#'
#' @return Client ID string
#' @keywords internal
#' @noRd
odp_get_client_id <- function() {
  env_id <- Sys.getenv("ODP_CLIENT_ID", unset = "")
  if (nzchar(env_id)) env_id else ODP_B2C_DEFAULT_CLIENT_ID
}

#' Create an OAuth2 client for HubOcean authentication
#'
#' @return An httr2 oauth_client object
#' @keywords internal
#' @noRd
odp_oauth_client <- function() {
  endpoints <- odp_b2c_endpoints()
  httr2::oauth_client(
    id = odp_get_client_id(),
    token_url = endpoints$token_url,
    name = "odp-sdk-r"
  )
}

#' Perform interactive OAuth2 authentication
#'
#' Opens a browser for the user to authenticate with HubOcean via Azure B2C.
#' Tokens are cached on disk to avoid repeated authentication.
#'
#' @return A function that returns the Authorization header value
#' @keywords internal
#' @noRd
odp_interactive_auth <- function() {
  if (!interactive()) {
    cli::cli_abort(
      c(
        "! Interactive authentication requires an interactive R session.",
        "i Provide an API key via `api_key` or the ODP_API_KEY environment variable."
      )
    )
  }


  client <- odp_oauth_client()
  endpoints <- odp_b2c_endpoints()


  # Use httr2's oauth_flow_auth_code for browser-based authentication

  # with disk caching for token persistence

  token <- tryCatch(
    httr2::oauth_flow_auth_code(
      client = client,
      auth_url = endpoints$auth_url,
      scope = ODP_B2C_SCOPE,
      pkce = TRUE,
      auth_params = list(
        # Azure B2C requires response_mode for some flows
        response_mode = "query"
      ),
      redirect_uri = httr2::oauth_redirect_uri()
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "! Interactive authentication failed.",
          "x {conditionMessage(e)}",
          "i Try providing an API key instead."
        ),
        parent = e
      )
    }
  )

  # Return a function that provides the bearer token
  # httr2 tokens include automatic refresh handling
  function() {
    # Check if token needs refresh (expires_at is POSIXct or NULL)
    is_expired <- !is.null(token$expires_at) && token$expires_at <= Sys.time()
    if (is_expired) {
      token <<- tryCatch(
        httr2::oauth_flow_refresh(client, token$refresh_token),
        error = function(e) {
          # If refresh fails, re-authenticate
          httr2::oauth_flow_auth_code(
            client = client,
            auth_url = endpoints$auth_url,
            scope = ODP_B2C_SCOPE,
            pkce = TRUE,
            auth_params = list(response_mode = "query"),
            redirect_uri = httr2::oauth_redirect_uri()
          )
        }
      )
    }
    paste("Bearer", token$access_token)
  }
}

#' Check if interactive authentication is available
#'
#' @return TRUE if running in an interactive session
#' @keywords internal
#' @noRd
odp_can_use_interactive <- function() {
  interactive()
}
