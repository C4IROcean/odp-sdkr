odp_column_stats <- function(column = NULL, ...) {
  if (inherits(column, "odp_column_stats") && length(list(...)) == 0) {
    return(column)
  }
  if (is.null(column)) {
    column <- list()
  }
  if (length(list(...))) {
    column <- utils::modifyList(column, list(...))
  }
  if (!is.list(column)) {
    cli::cli_abort("`column` must be a list")
  }
  out <- list(
    name = as.character(column$name %||% ""),
    type = as.character(column$type %||% ""),
    null_count = as.numeric(column$null_count %||% 0),
    num_values = as.numeric(column$num_values %||% 0),
    min = column$min %||% NULL,
    max = column$max %||% NULL,
    metadata = column$metadata %||% NULL
  )
  structure(out, class = c("odp_column_stats", "list"))
}

odp_table_stats <- function(stats = NULL, ...) {
  if (inherits(stats, "odp_table_stats") && length(list(...)) == 0) {
    return(stats)
  }
  if (is.null(stats)) {
    stats <- list()
  }
  if (length(list(...))) {
    stats <- utils::modifyList(stats, list(...))
  }
  if (!is.list(stats)) {
    cli::cli_abort("`stats` must be a list")
  }
  raw_columns <- stats$columns %||% list()
  if (!is.list(raw_columns)) {
    raw_columns <- list(raw_columns)
  }
  columns <- lapply(raw_columns, odp_column_stats)
  out <- list(
    num_rows = as.numeric(stats$num_rows %||% 0),
    size = as.numeric(stats$size %||% 0),
    columns = columns
  )
  structure(out, class = c("odp_table_stats", "list"))
}
