# HubOcean API client R6 generator used internally by `odp_client()`
OdpClient <- R6::R6Class(
  "OdpClient",
  public = list(
    base_url = NULL,
    initialize = function(api_key = NULL, base_url = NULL) {
      self$base_url <- odp_default_base_url(base_url)
      private$auth_header <- private$resolve_auth(api_key = api_key)
    },
    dataset = function(dataset_id) {
      dataset_id <- odp_validate_id(as.character(dataset_id))
      OdpDataset$new(self, dataset_id)
    },
    request_arrow = function(path, query = NULL, body = NULL, method = "POST", retry = TRUE) {
      resp <- private$request(
        path = path,
        query = query,
        body = body,
        method = method,
        accept = "application/vnd.apache.arrow.stream",
        retry = retry
      )
      private$handle_response(resp, context = sprintf("Arrow request to %s", path), allow_no_content = FALSE)
      httr2::resp_body_raw(resp)
    },
    request_json = function(path, query = NULL, body = NULL, method = "GET", retry = TRUE) {
      resp <- private$request(
        path = path,
        query = query,
        body = body,
        method = method,
        accept = "application/json",
        retry = retry
      )
      private$handle_response(resp, context = sprintf("JSON request to %s", path), allow_no_content = FALSE)
      httr2::resp_body_json(resp, simplifyVector = FALSE)
    }
  ),
  private = list(
    auth_header = NULL,
    request = function(path, query = NULL, body = NULL, method = "POST", accept = NULL, retry = TRUE) {
      url <- paste0(self$base_url, path)
      req <- httr2::request(url) |> httr2::req_method(method)
      if (!is.null(query)) {
        keep <- !vapply(query, is.null, logical(1))
        query <- query[keep]
        if (length(query)) {
          req <- do.call(httr2::req_url_query, c(list(req), query))
        }
      }
      headers <- c(
        Authorization = private$auth_header(),
        `User-Agent` = odp_user_agent()
      )
      if (!is.null(accept)) {
        headers[["Accept"]] <- accept
      }
      req <- do.call(httr2::req_headers, c(list(req), as.list(headers)))
      if (is.raw(body)) {
        req <- httr2::req_body_raw(req, body)
      } else if (!is.null(body)) {
        req <- httr2::req_body_json(req, body, auto_unbox = TRUE, digits = NA)
      }
      req <- httr2::req_error(req, is_error = function(resp) FALSE)
      resp <- private$perform_with_retry(req, retry = retry)
      # TODO: consider doing some status shenanigans here
      # to get the status:  status <- httr2::resp_status(resp)
      resp
    },
    resolve_auth = function(api_key = NULL) {
      if (!is.null(api_key) && nzchar(api_key)) {
        key <- api_key
      } else {
        env_key <- Sys.getenv("ODP_API_KEY", unset = "")
        if (nzchar(env_key)) {
          key <- env_key
        } else {
          key <- NULL
        }
      }
      if (!is.null(key)) {
        return(function() paste("ApiKey", key))
      }
      cli::cli_abort(
        c(
          "! Unable to authenticate with HubOcean.",
          "x Provide an API key via `api_key` or the ODP_API_KEY environment variable."
        )
      )
    },
    perform_with_retry = function(req, retry = TRUE) {
      max_tries <- if (retry) 5 else 1
      for (attempt in seq_len(max_tries)) {
        result <- tryCatch(
          list(resp = httr2::req_perform(req), err = NULL),
          error = function(err) list(resp = NULL, err = err)
        )
        if (!is.null(result$resp)) {
          return(result$resp)
        }
        err <- result$err
        if (attempt == max_tries) {
          stop(err)
        }
        wait <- 2^(attempt - 1)
        message(
          sprintf(
            "HubOcean request attempt %d failed (%s). Retrying in %s seconds...",
            attempt,
            conditionMessage(err),
            wait
          )
        )
        Sys.sleep(wait)
      }
    },
    handle_response = function(resp, context, allow_no_content = FALSE) {
      status <- httr2::resp_status(resp)
      if (status == 204 && !allow_no_content) {
        cli::cli_abort(
          c(
            sprintf("! %s returned no content.", context),
            "x The requested table or resource may not exist."
          ),
          class = c("odp_http_not_found", "odp_http_error")
        )
      }
      if (status >= 400) {
        detail <- odp_response_message(resp)
        cli::cli_abort(
          c(
            sprintf("! %s failed with HTTP %s.", context, status),
            if (nzchar(detail)) sprintf("x %s", detail)
          ),
          class = c("odp_http_error", sprintf("odp_http_%s", status))
        )
      }
      invisible(resp)
    }
  )
)
