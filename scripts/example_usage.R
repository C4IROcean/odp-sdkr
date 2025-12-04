# Option 1: install from local source checkout
# install.packages(
#   "~/dev/app-odcat/r_sdk",
#   repos = NULL,
#   type = "source"
# )

# Option 2: install latest GitHub build
# if (!requireNamespace("remotes", quietly = TRUE)) {
#   install.packages("remotes")
# }
# remotes::install_github("C4IROcean/odp-sdkr")

if (!requireNamespace("arrow", quietly = TRUE)) {
  install.packages("arrow")
}
if (!requireNamespace("tibble", quietly = TRUE)) {
  install.packages("tibble")
}

# If working locally:
# Ensure no stale namespace stays attached before loading the freshly installed build.
# if ("odp" %in% loadedNamespaces()) {
#   unloadNamespace("odp")
# }

# Load the odp package
library(odp)

api_key <- "sk_your_api_key_here"
dataset_id <- "21b630bb-06b2-48de-a172-97a7a67e30ba" # amazon reef

# Initialize the client; for now we only support api_keys as auth
client <- odp_client(api_key = api_key)

# Selecting the dataset and table in the same way we do for the python sdk
ds <- client$dataset(dataset_id)
table <- ds$table

print("Selecting first 5 rows as tibble...")
# select return a cursor that fetches the data. The data is fetched from
# the server by calling collect() or by iterating over the batches
tibble_df <- table$select()$tibble()
# arrow_table <- table$select()$arrow()
# base_df <- table$select()$dataframe()
# base_df <- table$select()$collect()
print(utils::head(tibble_df, 5))

print("Aggregate count by type from tibble sample...")
print(table(tibble_df$type))

print("Iterating over chunks ...")
cursor <- table$select()
while (!is.null(batch <- cursor$next_batch())) {
  batch_df <- as.data.frame(batch, stringsAsFactors = FALSE)
  print(sprintf("Number of rows for batch: %d", nrow(batch_df)))
  break # Remove this break to iterate over all batches
}

print("Filtering on type == 'Rhodolith bed' and counting rows...")
# You can pass expressions to the select method to filter the data on the
# server side, similiar to how the python sdk does it.
cursor <- table$select(filter = "type == 'Rhodolith bed'")
print(nrow(cursor$collect()))

print("Aggregating by type on count...")
print(table$aggregate(
  group_by = "type",
  aggr = list(
    type = "count",
    area_km2 = "sum"
  )
))

print("Fetching table stats...")
print(table$stats())

print("\nFetching table schema...")
print(table$schema())
