# x %||% y : Return x if not NULL, else y
`%||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

odp_default_base_url <- function(candidate = NULL) {
  base <- candidate
  if (is.null(base) || !nzchar(base)) {
    env_base <- Sys.getenv("ODP_BASE_URL", unset = "")
    base <- if (nzchar(env_base)) env_base else "https://api.hubocean.earth"
  }
  base <- trimws(base)
  base <- sub("/+\\z", "", base)
  if (!nzchar(base)) {
    cli::cli_abort("`base_url` must be a non-empty string")
  }
  base
}

odp_user_agent <- function() {
  ver <- tryCatch(as.character(utils::packageVersion("odp")), error = function(...) "dev")
  sprintf("odp-sdk-r/%s", ver)
}

odp_validate_id <- function(id) {
  if (missing(id) || is.null(id) || !nzchar(id)) {
    cli::cli_abort("`table_id` must be a non-empty string")
  }
  id
}

# Convert input to character vector, allowing NULL if specified
odp_as_character_vector <- function(x, allow_null = TRUE) {
  if (is.null(x) && allow_null) {
    return(NULL)
  }
  if (is.null(x)) {
    cli::cli_abort("Expected a character vector, got NULL")
  }
  if (!is.vector(x)) {
    cli::cli_abort("Expected a vector input")
  }
  as.character(x)
}

#' Prepare bind variables for a query
#'
#' Normalises mixed inputs (named vectors, lists, or single-row data frames)
#' into a list ready for JSON encoding.
#'
#' @keywords internal
#' @noRd
odp_prepare_bindings <- function(vars) {
  if (is.null(vars)) {
    return(NULL)
  }
  if (is.data.frame(vars)) {
    if (nrow(vars) != 1) {
      cli::cli_abort("`vars` data frames must have exactly one row")
    }
    vars <- as.list(vars[1, , drop = FALSE])
  }
  if (is.atomic(vars) && is.null(names(vars))) {
    cli::cli_abort("`vars` must be a named list or data frame")
  }
  if (is.atomic(vars)) {
    vars <- as.list(vars)
  }
  if (is.list(vars) && is.null(names(vars))) {
    cli::cli_abort("`vars` must be a named list")
  }
  lapply(vars, odp_cast_binding_value)
}

odp_cast_binding_value <- function(value) {
  if (inherits(value, "POSIXt")) {
    return(format(as.POSIXct(value, tz = "UTC"), "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC"))
  }
  if (inherits(value, "Date")) {
    return(format(value, "%Y-%m-%d"))
  }
  if (inherits(value, "difftime")) {
    return(as.numeric(value, units = "secs"))
  }
  if (inherits(value, "integer64")) {
    return(as.character(value))
  }
  if (is.list(value)) {
    return(lapply(value, odp_cast_binding_value))
  }
  if (is.atomic(value)) {
    return(value)
  }
  cli::cli_abort("Unsupported type for bind variable: {class(value)}")
}

#' Validate timeout inputs
#'
#' Ensures the provided timeout is a positive numeric scalar.
#'
#' @keywords internal
#' @noRd
odp_check_timeout <- function(timeout) {
  if (!is.numeric(timeout) || length(timeout) != 1 || is.na(timeout) || timeout <= 0) {
    cli::cli_abort("`timeout` must be a single numeric value greater than zero")
  }
  timeout
}

odp_response_message <- function(resp) {
  if (is.null(resp)) {
    return("")
  }
  body <- tryCatch(httr2::resp_body_string(resp), error = function(...) "")
  if (!nzchar(body)) {
    return("")
  }
  parsed <- tryCatch(jsonlite::fromJSON(body, simplifyVector = FALSE), error = function(...) NULL)
  if (is.list(parsed)) {
    for (field in c("message", "error", "detail")) {
      value <- parsed[[field]]
      if (!is.null(value) && nzchar(as.character(value))) {
        return(as.character(value))
      }
    }
  }
  trimws(body)
}

require_dependency <- function(dep, scope) {
  if (!requireNamespace(dep, quietly = TRUE)) {
    cli::cli_abort("Install the `{dep}` package to use: {scope}")
  }
}
