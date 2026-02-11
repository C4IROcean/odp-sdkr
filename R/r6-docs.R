#' HubOcean API client
#'
#' Thin wrapper around the HubOcean API powering [odp_client()]. Handles
#' authentication and exposes helpers for datasets/tables. Use
#' [odp_client()]`$dataset()` to obtain a dataset handle that exposes the tabular
#' interface.
#'
#' @section Methods:
#' \describe{
#'   \item{$new(api_key = NULL, base_url = NULL)$}{Resolve the base URL and
#'   authentication header.}
#'   \item{$dataset(dataset_id)$}{Return an [OdpDataset] handle resolved via the
#'   provided id.}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' dataset <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")
#' table <- dataset$table
#' }
#'
#' @seealso [OdpDataset], [OdpTable]
#' @name OdpClient
#' @aliases OdpClient-class OdpClient
NULL
#' Dataset handle returned by [OdpClient]
#'
#' Wraps a HubOcean dataset identifier and exposes the tabular helper via the
#' `$table` field.
#'
#' @section Methods:
#' \describe{
#'   \item{$new(client, dataset_id)$}{Validate the dataset id and eagerly create
#'   the table helper.}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' dataset <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")
#' dataset$table$schema()
#' }
#'
#' @seealso [OdpClient], [OdpTable]
#' @name OdpDataset
#' @aliases OdpDataset-class OdpDataset
NULL
#' Table helper for streaming rows and computing aggregates
#'
#' Exposes the user-facing helpers: `select()` cursors, `aggregate()` for backend
#' reducers, and read-only metadata calls.
#'
#' @section Methods:
#' \describe{
#'   \item{$select(filter = "", columns = NULL, vars = NULL, timeout = 30)$}{
#'   Return an [OdpCursor] that lazily streams batches.}
#'   \item{$aggregate(group_by, filter, aggr, vars, timeout)$}{Compute grouped
#'   statistics without downloading the entire table.}
#'   \item{$schema()` / `$stats()`}{Inspect schema details and summary
#'   statistics.}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' tbl <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")$table
#' cursor <- tbl$select(columns = c("latitude", "longitude"))
#' cursor$dataframe()
#' }
#'
#' @seealso [OdpCursor], [OdpDataset]
#' @name OdpTable
#' @aliases OdpTable-class OdpTable
NULL
#' Cursor helper powering streaming workflows
#'
#' Lazily fetches Arrow IPC pages from the backend, exposes chunk iteration
#' utilities, and materialises results into familiar data structures.
#'
#' @section Methods:
#' \describe{
#'   \item{$next_batch()$}{Return the next `RecordBatch` or `NULL` when finished.}
#'   \item{$collect()` / `$arrow()`}{Materialise unread batches as an Arrow
#'   Table.}
#'   \item{$dataframe()`}{Materialise unread batches as a base `data.frame`.}
#'   \item{$tibble()`}{Materialise unread batches as a tibble (optional
#'   dependency).}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' tbl <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")$table
#' cursor <- tbl$select(filter = "depth > 300", columns = c("latitude", "depth"))
#' while (!is.null(batch <- cursor$next_batch())) {
#'   print(batch$num_rows)
#' }
#' df <- cursor$dataframe()
#' }
#'
#' @seealso [OdpTable]
#' @name OdpCursor
#' @aliases OdpCursor-class OdpCursor
NULL
#' Raw file storage helper for upload/download/management
#'
#' Provides methods for managing raw files attached to a table. Access via
#' `$table$raw` on a dataset or `$raw` on a table. A convenience alias `$files`
#' is available on [OdpDataset].
#'
#' @section Methods:
#' \describe{
#'   \item{$list(query = NULL, vars = NULL)$}{List files, optionally filtered.}
#'   \item{$list_batches(query = NULL, vars = NULL)$}{List files as an Arrow
#'   Table.}
#'   \item{$upload(name, data)$}{Upload a file; returns the raw file ID.}
#'   \item{$download(id)$}{Download a file; returns a raw vector.}
#'   \item{$delete(id)$}{Delete a file by ID.}
#'   \item{$update_meta(id, data)$}{Update metadata for a file.}
#'   \item{$ingest(id, opt = "append")$}{Ingest a file into the table. `opt` can
#'   be "append", "truncate", or "drop".}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' ds <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")
#'
#' # Upload a file
#' file_id <- ds$files$upload("data.csv", "a,b,c\\n1,2,3\\n")
#'
#' # List files
#' ds$files$list()
#'
#' # Download
#' content <- ds$files$download(file_id)
#'
#' # Ingest into table
#' ds$files$ingest(file_id)
#'
#' # Delete
#' ds$files$delete(file_id)
#' }
#'
#' @seealso [OdpTable], [OdpDataset]
#' @name OdpRaw
#' @aliases OdpRaw-class OdpRaw
NULL
