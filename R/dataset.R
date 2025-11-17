OdpDataset <- R6::R6Class(
  "OdpDataset",
  public = list(
    id = NULL,
    client = NULL,
    table = NULL,
    initialize = function(client, dataset_id) {
      self$client <- client
      self$id <- odp_validate_id(dataset_id)
      self$table <- OdpTable$new(client, self$id)
    }
  )
)
