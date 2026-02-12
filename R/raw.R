OdpRaw <- R6::R6Class(
  "OdpRaw",
  public = list(
    table = NULL,
    initialize = function(table) {
      self$table <- table
    },
    #' List raw files attached to the table
    #' @param query Optional filter expression.
    #' @param vars Optional bind variables for the filter.
    #' @return A list of file metadata entries.
    list = function(query = NULL, vars = NULL) {
      body <- list(
        query = odp_inline_vars(query, vars)
      )
      body <- body[!vapply(body, is.null, logical(1))]
      result <- self$table$client$request_json(
        path = "/api/table/v2/raw/list",
        query = list(table_id = self$table$id),
        body = body,
        method = "POST",
        retry = TRUE
      )
      result$files
    },
    #' List raw files as an Arrow Table
    #' @param query Optional filter expression.
    #' @param vars Optional bind variables for the filter.
    #' @return An Arrow Table with file metadata.
    list_batches = function(query = NULL, vars = NULL) {
      require_dependency("arrow", "Raw file listing as Arrow")
      body <- list(
        query = odp_inline_vars(query, vars)
      )
      body <- body[!vapply(body, is.null, logical(1))]
      raw_stream <- self$table$client$request_arrow(
        path = "/api/table/v2/raw/batch-list",
        query = list(table_id = self$table$id),
        body = body,
        retry = TRUE
      )
      arrow::read_ipc_stream(raw_stream, as_data_frame = FALSE)
    },
    #' Upload a file
    #' @param name The file name.
    #' @param data Raw vector or character string with the file contents.
    #' @return The raw file identifier (character).
    upload = function(name, data) {
      if (is.character(data)) {
        data <- charToRaw(data)
      }
      if (!is.raw(data)) {
        cli::cli_abort("`data` must be a raw vector or character string")
      }
      result <- self$table$client$request_json(
        path = "/api/table/v2/raw/upload",
        query = list(table_id = self$table$id, name = name),
        body = data,
        method = "POST",
        retry = FALSE
      )
      result$raw_id
    },
    #' Update metadata for a raw file
    #' @param id The raw file identifier.
    #' @param data A list of metadata key-value pairs to set.
    #' @return The updated metadata as a list.
    update_meta = function(id, data) {
      body <- charToRaw(jsonlite::toJSON(data, auto_unbox = TRUE))
      self$table$client$request_json(
        path = "/api/table/v2/raw/update_meta",
        query = list(table_id = self$table$id, id = id),
        body = body,
        method = "POST",
        retry = FALSE
      )
    },
    #' Download a raw file
    #' @param id The raw file identifier.
    #' @return A raw vector with the file contents.
    download = function(id) {
      self$table$client$request_raw(
        path = "/api/table/v2/raw/download",
        query = list(table_id = self$table$id, id = id),
        retry = TRUE
      )
    },
    #' Delete a raw file
    #' @param id The raw file identifier.
    delete = function(id) {
      self$table$client$request_json(
        path = "/api/table/v2/raw/delete",
        query = list(table_id = self$table$id, id = id),
        method = "POST",
        retry = FALSE
      )
      invisible(NULL)
    },
    #' Ingest a raw file into the table
    #' @param id The raw file identifier.
    #' @param opt Ingestion mode: "append" (default), "truncate", or "drop".
    ingest = function(id, opt = "append") {
      valid_opts <- c("append", "truncate", "drop")
      if (!opt %in% valid_opts) {
        cli::cli_abort(
          "`opt` must be one of: {paste(valid_opts, collapse = ', ')}"
        )
      }
      self$table$client$request_json(
        path = "/api/table/v2/raw/ingest",
        query = list(table_id = self$table$id, id = id, opt = opt),
        body = list(),
        method = "POST",
        retry = FALSE
      )
      invisible(NULL)
    }
  )
)
