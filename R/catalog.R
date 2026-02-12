#' Create a new dataset in the catalog
#'
#' @param client An OdpClient instance.
#' @param name Name of the dataset to create.
#' @param description Optional description for the dataset.
#'
#' @return A list with `id`, `name`, and `description` of the created dataset.
#' @export
#'
#' @examples
#' \dontrun{
#' client <- odp_client()
#' dataset <- odp_create_dataset(client, "my-dataset", "A test dataset")
#' }
odp_create_dataset <- function(client, name, description = "n/a") {
  if (!inherits(client, "OdpClient")) {
    cli::cli_abort("`client` must be an OdpClient instance.")
  }
  if (!is.character(name) || !nzchar(name)) {
    cli::cli_abort("`name` must be a non-empty string.")
  }

  body <- list(
    name = name,
    description = description %||% "n/a"
  )

  resp <- client$request_json(
    path = "/api/catalog/v2/datasets",
    body = body,
    method = "POST",
    retry = FALSE
  )

  list(
    id = resp$id,
    name = resp$name,
    description = resp$description %||% ""
  )
}

#' List all datasets in the catalog
#'
#' @param client An OdpClient instance.
#'
#' @return A data frame with columns `id`, `name`, and `description`.
#' @export
#'
#' @examples
#' \dontrun{
#' client <- odp_client()
#' datasets <- odp_list_datasets(client)
#' }
odp_list_datasets <- function(client) {
  if (!inherits(client, "OdpClient")) {
    cli::cli_abort("`client` must be an OdpClient instance.")
  }

  resp <- client$request_json(
    path = "/api/catalog/v2/datasets",
    method = "GET",
    retry = TRUE
  )

  if (!length(resp)) {
    return(data.frame(
      id = character(),
      name = character(),
      description = character(),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    id = vapply(resp, function(x) x$id %||% NA_character_, character(1)),
    name = vapply(resp, function(x) x$name %||% NA_character_, character(1)),
    description = vapply(resp, function(x) x$description %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

#' Get a dataset by name
#'
#' @param client An OdpClient instance.
#' @param name Name of the dataset to retrieve.
#'
#' @return A list with `id`, `name`, and `description`, or `NULL` if not found.
#' @export
#'
#' @examples
#' \dontrun{
#' client <- odp_client()
#' dataset <- odp_get_dataset_by_name(client, "my-dataset")
#' }
odp_get_dataset_by_name <- function(client, name) {
  if (!inherits(client, "OdpClient")) {
    cli::cli_abort("`client` must be an OdpClient instance.")
  }
  if (!is.character(name) || !nzchar(name)) {
    cli::cli_abort("`name` must be a non-empty string.")
  }

  datasets <- odp_list_datasets(client)

  match_idx <- which(datasets$name == name)
  if (!length(match_idx)) {
    return(NULL)
  }

  row <- datasets[match_idx[1], , drop = FALSE]
  list(
    id = row$id,
    name = row$name,
    description = row$description
  )
}

#' Get a dataset by UUID
#'
#' @param client An OdpClient instance.
#' @param uuid UUID of the dataset to retrieve.
#'
#' @return A list with `id`, `name`, and `description`, or `NULL` if not found.
#' @export
#'
#' @examples
#' \dontrun{
#' client <- odp_client()
#' dataset <- odp_get_dataset_by_uuid(client, "123e4567-e89b-12d3-a456-426614174000")
#' }
odp_get_dataset_by_uuid <- function(client, uuid) {
  if (!inherits(client, "OdpClient")) {
    cli::cli_abort("`client` must be an OdpClient instance.")
  }

  uuid <- odp_validate_id(as.character(uuid))

  resp <- tryCatch(
    client$request_json(
      path = sprintf("/api/catalog/v2/datasets/%s", uuid),
      method = "GET",
      retry = TRUE
    ),
    odp_http_404 = function(e) NULL,
    odp_http_not_found = function(e) NULL
  )

  if (is.null(resp)) {
    return(NULL)
  }

  list(
    id = resp$id,
    name = resp$name,
    description = resp$description %||% ""
  )
}
