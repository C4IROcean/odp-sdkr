#' Create an Ocean Data Platform client
#'
#' The helper mirrors the Python SDK entry point while defaulting to the
#' production HubOcean endpoint.
#'
#' @param api_key Optional API key. Falls back to the `ODP_API_KEY`
#'   environment variable when omitted. If no API key is available and
#'   running interactively, browser-based authentication will be used.
#' @param base_url Optional base URL. Defaults to the public API endpoint or
#'   `ODP_BASE_URL` when set.
#' @param interactive Control interactive authentication behavior:
#'   - `NULL` (default): Use interactive auth automatically when in an
#'     interactive session and no API key is available.
#'   - `TRUE`: Force interactive authentication (will fail if not interactive).
#'   - `FALSE`: Disable interactive authentication entirely.
#'
#' @return An `OdpClient` instance.
#' @export
#'
#' @examples
#' \dontrun{
#' # Use API key from environment
#' client <- odp_client()
#'
#' # Explicit API key
#' client <- odp_client(api_key = "your-api-key")
#'
#' # Force interactive browser login
#' client <- odp_client(interactive = TRUE)
#'
#' # Disable interactive auth (error if no API key)
#' client <- odp_client(interactive = FALSE)
#' }
odp_client <- function(api_key = NULL, base_url = NULL, interactive = NULL) {
  client_ctor <- get("OdpClient", envir = asNamespace("odp"))
  client_ctor$new(api_key = api_key, base_url = base_url, interactive = interactive)
}

# Public entry points are documented in R/odp-package.R
