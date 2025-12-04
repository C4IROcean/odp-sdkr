#' Create an Ocean Data Platform client
#'
#' The helper mirrors the Python SDK entry point while defaulting to the
#' production HubOcean endpoint.
#'
#' @param api_key Optional API key. Falls back to the `ODP_API_KEY`
#'   environment variable when omitted.
#' @param base_url Optional base URL. Defaults to the public API endpoint or
#'   `ODP_BASE_URL` when set.
#'
#' @return An `OdpClient` instance.
#' @export
odp_client <- function(api_key = NULL, base_url = NULL) {
  OdpClient$new(api_key = api_key, base_url = base_url)
}

# Public entry points are documented in R/odp-package.R
