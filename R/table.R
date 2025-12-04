OdpTable <- R6::R6Class(
  "OdpTable",
  public = list(
    id = NULL,
    client = NULL,
    initialize = function(client, table_id) {
      require_dependency("arrow", "Tablular data")
      self$client <- client
      self$id <- odp_validate_id(table_id)
    },
    select = function(filter = "", columns = NULL, vars = NULL, timeout = 30) {
      request <- list(
        filter = filter %||% "",
        columns = columns,
        vars = vars,
        timeout = odp_check_timeout(timeout)
      )

      OdpCursor$new(table = self, request = request)
    },
    #' Aggregate rows using backend support
    #' @param group_by Expression defining the grouping key (defaults to "'TOTAL'").
    #' @param filter Optional filter expression.
    #' @param aggr Named list mapping column -> aggregation type ("sum", "min", "max", "count", "mean").
    #' @param vars Optional bind variables for the filter.
    #' @param timeout Request timeout in seconds.
    #' @return A base `data.frame` with a `group` column and aggregated values.
    aggregate = function(group_by = "'TOTAL'", filter = "", aggr = NULL, vars = NULL, timeout = 30) {
      schema <- self$schema()
      if (is.null(schema)) {
        cli::cli_abort(sprintf("Table '%s' does not exist", self$id))
      }

      infer_aggregations <- function(schema) {
        defs <- list()
        count <- schema$num_fields
        if (length(count) && count > 0) {
          for (idx in seq_len(count)) {
            field <- schema$field(idx - 1)
            meta <- tryCatch(field$metadata, error = function(...) NULL)
            if (!is.null(meta) && !is.null(meta$aggr)) {
              defs[[field$name]] <- rawToChar(meta$aggr)
            }
          }
        }
        defs
      }

      if (!is.null(aggr) && (!is.list(aggr) || is.null(names(aggr)))) {
        cli::cli_abort("`aggr` must be a named list")
      }
      aggr <- aggr %||% infer_aggregations(schema)
      if (!length(aggr)) {
        cli::cli_abort("Provide `aggr` or annotate fields with aggregation metadata")
      }

      timeout <- odp_check_timeout(timeout)
      body <- list(
        by = group_by %||% "'TOTAL'",
        query = if (nzchar(filter %||% "")) filter else NULL,
        aggr = aggr,
        vars = odp_prepare_bindings(vars),
        cursor = "",
        timeout = timeout
      )
      raw_payload <- self$client$request_arrow(
        path = "/api/table/v2/sdk/aggregate",
        query = list(table_id = self$id),
        body = body,
        retry = TRUE
      )
      payload <- private$split_arrow_trailer(raw_payload)

      read_batches <- function(stream) {
        out <- list()
        if (!length(stream)) {
          return(out)
        }
        reader <- arrow::RecordBatchStreamReader$create(stream)
        repeat {
          batch <- reader$read_next_batch()
          if (is.null(batch)) {
            break
          }
          if (batch$num_rows == 0) {
            next
          }
          out[[length(out) + 1]] <- as.data.frame(batch, stringsAsFactors = FALSE, check.names = FALSE)
        }
        out
      }

      build_plan <- function(spec) {
        plan <- list("*" = "sum")
        for (name in names(spec)) {
          kind <- spec[[name]]
          norm_kind <- if (kind %in% c("mean", "avg")) "mean" else kind
          plan <- switch(norm_kind,
            mean = {
              plan[[paste0(name, "_sum")]] <- "sum"
              plan[[paste0(name, "_count")]] <- "sum"
              plan
            },
            sum = {
              plan[[paste0(name, "_sum")]] <- "sum"
              plan
            },
            min = {
              plan[[paste0(name, "_min")]] <- "min"
              plan
            },
            max = {
              plan[[paste0(name, "_max")]] <- "max"
              plan
            },
            count = {
              plan[[paste0(name, "_count")]] <- "sum"
              plan
            },
            cli::cli_abort(sprintf("Unknown aggregation type '%s' for field '%s'", kind, name))
          )
        }
        plan
      }

      apply_fun <- function(values, fun_name) {
        if (!length(values)) {
          return(NA)
        }
        switch(fun_name,
          sum = sum(values, na.rm = TRUE),
          min = suppressWarnings(min(values, na.rm = TRUE)),
          max = suppressWarnings(max(values, na.rm = TRUE)),
          cli::cli_abort(sprintf("Unsupported aggregate function '%s'", fun_name))
        )
      }

      finalise_aggregations <- function(df, aggr, key_col) {
        if (!nrow(df)) {
          result <- data.frame(stringsAsFactors = FALSE)
          result$group <- character()
          return(result)
        }
        for (name in names(aggr)) {
          kind <- aggr[[name]]
          if (kind %in% c("mean", "avg")) {
            sum_col <- paste0(name, "_sum")
            count_col <- paste0(name, "_count")
            counts <- df[[count_col]]
            safe_div <- ifelse(counts > 0, df[[sum_col]] / counts, NA_real_)
            df[[name]] <- safe_div
            df[[sum_col]] <- NULL
            df[[count_col]] <- NULL
          } else if (identical(kind, "sum")) {
            col <- paste0(name, "_sum")
            df[[name]] <- df[[col]]
            df[[col]] <- NULL
          } else if (identical(kind, "min")) {
            col <- paste0(name, "_min")
            df[[name]] <- df[[col]]
            df[[col]] <- NULL
          } else if (identical(kind, "max")) {
            col <- paste0(name, "_max")
            df[[name]] <- df[[col]]
            df[[col]] <- NULL
          } else if (identical(kind, "count")) {
            col <- paste0(name, "_count")
            df[[name]] <- df[[col]]
            df[[col]] <- NULL
          }
        }
        if ("*" %in% names(df)) {
          df[["*"]] <- NULL
        }
        names(df)[names(df) == key_col] <- "group"
        rownames(df) <- NULL
        df
      }
      batches <- read_batches(payload$arrow)
      if (!length(batches)) {
        empty <- data.frame(group = character(), stringsAsFactors = FALSE)
        return(empty)
      }
      combined <- do.call(rbind, c(batches, list(stringsAsFactors = FALSE)))
      key_col <- names(combined)[1]
      if (!nzchar(key_col) || identical(key_col, "")) {
        key_col <- ".group"
        names(combined)[1] <- key_col
      }
      group_levels <- unique(combined[[key_col]])
      group_indices <- lapply(group_levels, function(level_value) which(combined[[key_col]] == level_value))
      plan <- build_plan(aggr)
      partials_df <- data.frame(setNames(list(group_levels), key_col), stringsAsFactors = FALSE, check.names = FALSE)
      for (col in names(plan)) {
        if (!col %in% names(combined)) {
          if (identical(col, "*")) {
            next
          }
          cli::cli_abort(sprintf("Backend aggregation payload missing column '%s'", col))
        }
        fun_name <- plan[[col]]
        column_data <- combined[[col]]
        template <- column_data[0]
        values <- rep(template, length.out = length(group_levels))
        for (idx in seq_along(group_levels)) {
          rows <- group_indices[[idx]] %||% integer(0)
          values[idx] <- apply_fun(column_data[rows], fun_name)
        }
        partials_df[[col]] <- values
      }
      finalise_aggregations(partials_df, aggr, key_col)
    },
    #' @rdname aggregate
    aggregate_tibble = function(...) {
      require_dependency("tibble", "aggregate tibble conversion")
      tibble::as_tibble(self$aggregate(...))
    },
    #' @keywords internal
    #' @noRd
    select_request = function(request, cursor = "", retry = TRUE) {
      if (missing(request) || !is.list(request)) {
        cli::cli_abort("`request` must be a list")
      }
      body <- list(
        query = request$filter %||% "",
        cols = odp_as_character_vector(request$columns, allow_null = TRUE),
        vars = odp_prepare_bindings(request$vars),
        timeout = request$timeout %||% 30,
        cursor = as.character(cursor %||% "")
      )
      body <- body[!vapply(body, is.null, logical(1))]
      raw_stream <- self$client$request_arrow(
        path = "/api/table/v2/sdk/select",
        query = list(table_id = self$id),
        body = body,
        retry = retry
      )
      if (!length(raw_stream)) {
        return(list(arrow = raw(0), cursor = NULL, trailer = NULL))
      }
      parts <- private$split_arrow_trailer(raw_stream)
      trailer <- parts$trailer
      cursor_next <- if (!is.null(trailer)) trailer$cursor else NULL
      list(arrow = parts$arrow, cursor = cursor_next, trailer = trailer)
    },
    schema = function(timeout = 5) {
      request <- list(
        filter = '"fetch" == "schema"',
        timeout = odp_check_timeout(timeout),
        columns = NULL, vars = NULL
      )
      payload <- self$select_request(request = request, cursor = "", retry = TRUE)
      if (!length(payload$arrow)) {
        return(NULL)
      }
      tbl <- tryCatch(
        arrow::read_ipc_stream(payload$arrow, as_data_frame = FALSE),
        error = function(err) {
          if (inherits(err, "ArrowInvalid")) {
            return(NULL)
          }
          stop(err)
        }
      )
      if (is.null(tbl)) {
        return(NULL)
      }
      arrow::schema(tbl)
    },
    stats = function() {
      payload <- self$client$request_json(
        path = "/api/table/v2/stats",
        query = list(table_id = self$id),
        method = "POST",
        retry = TRUE
      )
      odp_table_stats(payload)
    }
  ),
  private = list(
    split_arrow_trailer = function(raw_stream, scan_window = 262144) {
      if (!length(raw_stream)) {
        return(list(arrow = raw_stream, trailer = NULL))
      }
      brace <- charToRaw("{")
      start <- max(1, length(raw_stream) - scan_window + 1)
      for (idx in seq(length(raw_stream), start, by = -1)) {
        if (raw_stream[idx] == brace) {
          candidate <- raw_stream[idx:length(raw_stream)]
          trailer <- tryCatch(
            jsonlite::fromJSON(rawToChar(candidate), simplifyVector = FALSE),
            error = function(...) NULL
          )
          if (is.list(trailer)) {
            arrow_only <- if (idx > 1) raw_stream[seq_len(idx - 1)] else raw(0)
            return(list(arrow = arrow_only, trailer = trailer))
          }
        }
      }
      list(arrow = raw_stream, trailer = NULL)
    }
  )
)
