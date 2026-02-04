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
#' Exposes user-facing helpers: `select()` cursors, `aggregate()` for backend
#' reducers, `insert()` for writes, and read-only metadata calls.
#'
#' @section Methods:
#' \describe{
#'   \item{$select(filter = "", columns = NULL, vars = NULL, timeout = 30)$}{
#'   Return an [OdpCursor] that lazily streams batches.}
#'   \item{$aggregate(group_by, filter, aggr, vars, timeout)$}{Compute grouped
#'   statistics without downloading the entire table.}
#'   \item{$insert(data)$}{Insert a data frame and auto-commit the transaction.}
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
#' @seealso [OdpCursor], [OdpDataset], [OdpTransaction]
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
#' Transaction for inserting data
#'
#' Buffers row batches and manages transaction lifecycle. Validates data against
#' table schema on initialization. Automatically flushes when row or byte thresholds
#' are reached. Use [OdpTable]`$insert()` for direct usage.
#'
#' @section Methods:
#' \describe{
#'   \item{$insert(data)$}{Validate and buffer a data frame. Auto-flushes on size thresholds.}
#'   \item{$commit()$}{Finalize and apply all buffered changes.}
#'   \item{$rollback()$}{Discard all buffered changes without applying.}
#' }
#'
#' @examples
#' \dontrun{
#' client <- odp_client(api_key = "Sk_live_your_key")
#' tbl <- client$dataset("aea06582-fc49-4995-a9a8-2f31fcc65424")$table
#' df <- data.frame(latitude = c(10, 20), longitude = c(30, 40))
#' tbl$insert(df)
#' }
#'
#' @seealso [OdpTable]
#' @name OdpTransaction
#' @aliases OdpTransaction-class OdpTransaction
NULL
