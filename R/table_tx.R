OdpTransaction <- R6::R6Class(
  "OdpTransaction",
  public = list(
    initialize = function(table, tx_id) {
      require_dependency("arrow", "Transactions")
      private$table <- table
      private$tx_id <- tx_id
      private$schema <- table$schema()
      if (is.null(private$schema)) {
        cli::cli_abort("Table schema is not available. Cannot create transaction.")
      }
      private$batches <- list()
      private$row_count <- 0L
      private$byte_count <- 0L
      private$committed <- FALSE
    },
    insert = function(data) {
      if (isTRUE(private$committed)) {
        cli::cli_abort("Cannot insert into a committed transaction")
      }
      data <- odp_to_arrow_table(data)
      if (data$num_rows == 0L) {
        return(invisible(self))
      }
      reader <- arrow::as_record_batch_reader(data)
      while (TRUE) {
        batch <- reader$read_next_batch()
        if (is.null(batch)) break
        private$batches[[length(private$batches) + 1]] <- batch
        private$row_count <- private$row_count + batch$num_rows
        private$byte_count <- private$byte_count + length(batch$serialize())

        if (private$row_count >= 10000L || private$byte_count >= 10000000L) {
          private$flush()
        }
      }
      invisible(self)
    },
    select = function(filter = "", vars = NULL) {
      private$flush()
      request <- list(
        filter = filter %||% "",
        vars = vars,
        tx_id = private$tx_id
      )
      OdpCursor$new(table = private$table, request = request)
    },
    replace = function(filter = "", vars = NULL, ...) {
      filter <- if (nzchar(filter %||% "")) filter else list(...)$query %||% ""
      if (!nzchar(filter)) {
        cli::cli_abort("For your own safety, a filter is required, use \"1==1\" to match all rows")
      }
      private$flush()
      request <- list(
        filter = filter,
        vars = vars,
        tx_id = private$tx_id,
        operation = "replace"
      )
      OdpCursor$new(table = private$table, request = request)
    },
    delete = function(query = "") {
      ct <- 0L
      cursor <- self$replace(filter = query)
      repeat {
        batch <- cursor$next_batch()
        if (is.null(batch)) break
        ct <- ct + batch$num_rows
      }
      ct
    },
    commit = function() {
      if (isTRUE(private$committed)) {
        cli::cli_abort("Transaction already committed")
      }
      if (private$row_count > 0L) {
        private$flush()
      }
      private$table$client$request_json(
        path = "/api/table/v2/commit",
        query = list(table_id = private$table$id, tx_id = private$tx_id),
        method = "POST",
        retry = FALSE
      )
      private$committed <- TRUE
      invisible(self)
    },
    rollback = function() {
      if (isTRUE(private$committed)) {
        cli::cli_abort("Cannot rollback a committed transaction")
      }
      private$table$client$request_json(
        path = "/api/table/v2/rollback",
        query = list(table_id = private$table$id, tx_id = private$tx_id),
        method = "POST",
        retry = FALSE
      )
      private$committed <- TRUE
      invisible(self)
    }
  ),
  private = list(
    table = NULL,
    tx_id = NULL,
    schema = NULL,
    batches = NULL,
    row_count = 0L,
    byte_count = 0L,
    committed = FALSE,
    flush = function() {
      if (private$row_count == 0L || length(private$batches) == 0L) {
        return()
      }

      # create arrow ipc stream with schema header + record batches
      buf <- arrow::BufferOutputStream$create()
      writer <- arrow::RecordBatchStreamWriter$create(buf, schema = private$schema)

      for (batch in private$batches) {
        writer$write_batch(batch)
      }
      writer$close()

      all_bytes <- buf$finish()$data()

      private$table$client$request_arrow(
        path = "/api/table/v2/sdk/insert",
        query = list(table_id = private$table$id, tx_id = private$tx_id),
        body = all_bytes,
        retry = TRUE
      )

      # reset buffers
      private$batches <- list()
      private$row_count <- 0L
      private$byte_count <- 0L
    }
  )
)
