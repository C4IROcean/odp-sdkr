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
#' @section Fields:
#' \describe{
#'   \item{$table}{An [OdpTable] handle for streaming rows and computing
#'   aggregates.}
#'   \item{$files}{An [OdpRaw] handle for uploading, downloading, and managing
#'   raw files attached to the dataset.}
#' }
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
#'
#' # Upload and manage files
#' file_id <- dataset$files$upload("data.csv", "a,b\n1,2\n")
#' dataset$files$list()
#' dataset$files$download(file_id)
#' }
#'
#' @seealso [OdpClient], [OdpTable], [OdpRaw]
#' @name OdpDataset
#' @aliases OdpDataset-class OdpDataset
NULL
#' Table helper for streaming rows and computing aggregates
#'
#' Exposes user-facing helpers: `select()` cursors, `aggregate()` for backend
#' reducers, `insert()` for writes, and read-only metadata calls.
#'
#' @section Fields:
#' \describe{
#'   \item{$raw}{An [OdpRaw] handle for managing raw files attached to this
#'   table. Also accessible as `dataset$files`.}
#' }
#'
#' @section Methods:
#' \describe{
#'   \item{$select(filter = "", columns = NULL, vars = NULL, timeout = 30)$}{
#'   Return an [OdpCursor] that lazily streams batches.}
#'   \item{$aggregate(group_by, filter, aggr, vars, timeout)$}{Compute grouped
#'   statistics without downloading the entire table.}
#'   \item{$create(arg)$}{Create table with schema from a Schema, data frame, RecordBatch, or Arrow Table.}
#'   \item{$alter(schema, from_names = list())$}{Alter table schema and re-ingest data.}
#'   \item{$truncate()$}{Remove all data while preserving schema.}
#'   \item{$drop()$}{Drop the table entirely.}
#'   \item{$begin()$}{Start a transaction and return an [OdpTransaction] handle.}
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
#' @seealso [OdpCursor], [OdpDataset], [OdpTransaction], [OdpRaw]
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
#' Transaction for inserting, replacing, and deleting data
#'
#' Buffers row batches and manages transaction lifecycle. Validates data against
#' table schema on initialization. Automatically flushes when row or byte thresholds
#' are reached. Use [OdpTable]`$insert()` for direct usage or manual transactions
#' for multi-step workflows.
#'
#' @section Methods:
#' \describe{
#'   \item{$insert(data)$}{Validate and buffer a data frame. Auto-flushes on size thresholds.}
#'   \item{$select(filter = "", vars = NULL)$}{Query rows in this transaction via a cursor.}
#'   \item{$replace(filter = "", vars = NULL)$}{Replace rows matching the filter and return them in a cursor.}
#'   \item{$delete(query = "")$}{Delete rows matching the query. Returns row count.}
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
