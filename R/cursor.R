OdpCursor <- R6::R6Class(
  "OdpCursor",
  public = list(
    initialize = function(table, request) {
      require_dependency("arrow", "table cursor")
      if (missing(table) || !is.environment(table) || !is.function(table$select_request)) {
        cli::cli_abort("`table` must expose a `select_request()` method")
      }
      if (missing(request) || !is.list(request)) {
        cli::cli_abort("`request` must be a list")
      }
      private$table <- table
      private$request <- request
    },
    next_batch = function() {
      repeat {
        if (isTRUE(private$state$finished)) {
          return(NULL)
        }
        if (is.null(private$state$reader)) {
          private$open_page()
          next
        }
        batch <- private$state$reader$read_next_batch()
        if (is.null(batch)) {
          private$state$reader <- NULL
          private$state$finished <- is.null(private$state$next_cursor) || !nzchar(private$state$next_cursor)
          next
        }
        if (batch$num_rows == 0) {
          next
        }
        return(batch)
      }
    },
    collect = function() {
      # Reset the cursor so that collect() can be called multiple times and so
      # we get the full table if the cursor has been partially consumed
      private$reset_cursor()
      batches <- private$drain_batches()
      if (!length(batches)) {
        schema <- private$state$schema
        if (!is.null(schema)) {
          return(arrow::Table$create(schema = schema))
        }
        return(NULL)
      }
      reader <- do.call(arrow::RecordBatchReader$create, batches)
      reader$read_table()
    },
    arrow = function() {
      self$collect()
    },
    dataframe = function() {
      tbl <- self$collect()
      if (is.null(tbl)) {
        return(data.frame(stringsAsFactors = FALSE))
      }
      as.data.frame(tbl, stringsAsFactors = FALSE)
    },
    tibble = function() {
      require_dependency("tibble", "cursor tibble conversion")
      df <- self$dataframe()
      tibble::as_tibble(df)
    }
  ),
  private = list(
    table = NULL,
    request = NULL,
    state = list(
      reader = NULL,
      next_cursor = "",
      finished = FALSE,
      schema = NULL
    ),
    open_page = function() {
      if (isTRUE(private$state$finished)) {
        private$state$reader <- NULL
        return()
      }
      cursor <- as.character(private$state$next_cursor %||% "")
      payload <- private$table$select_request(private$request, cursor)
      private$state$next_cursor <- payload$cursor
      private$state$reader <- NULL
      if (length(payload$arrow)) {
        private$state$reader <- tryCatch(
          arrow::RecordBatchStreamReader$create(payload$arrow),
          error = function(err) {
            cli::cli_abort(conditionMessage(err))
          }
        )
      }
      if (!is.null(private$state$reader)) {
        private$state$schema <- private$state$reader$schema
        return()
      }
      if (is.null(private$state$next_cursor) || !nzchar(private$state$next_cursor)) {
        private$state$finished <- TRUE
      }
    },
    drain_batches = function() {
      batches <- list()
      repeat {
        batch <- self$next_batch()
        if (is.null(batch)) {
          break
        }
        batches[[length(batches) + 1]] <- batch
      }
      batches
    },
    reset_cursor = function() {
      reader <- private$state$reader
      if (!is.null(reader) && is.function(reader$close)) {
        try(reader$close(), silent = TRUE)
      }
      private$state <- list(
        reader = NULL,
        next_cursor = "",
        finished = FALSE,
        schema = NULL
      )
    }
  )
)
