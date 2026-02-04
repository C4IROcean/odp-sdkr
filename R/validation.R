odp_validate_insert_data <- function(data, schema) {
  if (is.null(schema)) {
    cli::cli_abort("Table schema is not available. Cannot insert data.")
  }

  if (!is.data.frame(data) || !nrow(data)) {
    return(invisible(NULL))
  }

  data_cols <- names(data)
  odp_check_required_fields(data_cols, schema)

  for (col_name in data_cols) {
    field <- schema$GetFieldByName(col_name)
    col_data <- data[[col_name]]

    for (row_idx in seq_len(nrow(data))) {
      value <- col_data[[row_idx]]
      if ((is.na(value) || is.null(value)) && !field$nullable) {
        cli::cli_abort(sprintf(
          "Non-nullable column '%s' has NULL value at row %d",
          col_name, row_idx
        ))
      }
    }
  }

  invisible(NULL)
}

odp_check_required_fields <- function(data_cols, schema) {
  for (field_name in schema$names) {
    field <- schema$GetFieldByName(field_name)
    if (!field_name %in% data_cols && !field$nullable) {
      cli::cli_abort(sprintf("Missing required column: '%s'", field_name))
    }
  }
}

