odp_validate_insert_data <- function(data, schema) {
  if (is.null(schema)) {
    cli::cli_abort("Table schema is not available. Cannot insert data.")
  }

  if (!is.data.frame(data) || !nrow(data)) {
    return(invisible(NULL))
  }

  data_cols <- names(data)
  for (field_name in schema$names) {
    field <- schema$GetFieldByName(field_name)
    if (!field_name %in% data_cols && !isTRUE(field$nullable)) {
      cli::cli_abort(sprintf("Missing required column: '%s'", field_name))
    }
  }

  invisible(NULL)
}
