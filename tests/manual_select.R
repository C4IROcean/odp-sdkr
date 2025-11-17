# Ensure the following packages are installed before running:
# arrow, cli, ggplot2, httr2, jsonlite, maps, R6, sf, tibble

install.packages(
  "~/dev/app-odcat/r_sdk",
  repos = NULL,
  type = "source"
)

# Ensure no stale namespace stays attached before loading the freshly installed build.
if ("odp" %in% loadedNamespaces()) {
  unloadNamespace("odp")
}
library(odp)

api_key <- "sk_590ea8c96ad3b462cdd820c0"
# dataset_id <- "f3a1c9e2-7b6e-4c3e-9f3b-1e2d4a9f8c6d" # gebco
# dataset_id <- "a608f54b-75c7-4df9-a3a8-cedbfa391873"
dataset_id <- "21b630bb-06b2-48de-a172-97a7a67e30ba" # amazon reef

client <- odp_client(
  api_key = api_key,
  base_url = "https://api.hubocean.earth"
)

ds <- client$dataset(dataset_id)
table <- ds$table

print("Selecting first 5 rows as tibble...")
tibble_df <- table$select()$tibble()
print(utils::head(tibble_df, 5))

print("Iterating over chunks ...")
cursor <- table$select()
while (!is.null(batch <- cursor$next_batch())) {
  batch_df <- as.data.frame(batch, stringsAsFactors = FALSE)
  print("Number of rows for batch: {nrow(batch_df)}")
}

print("Fetching table stats...")
print(table$stats())

print("\nFetching table schema...")
print(table$schema())

print("Filtering on type == 'Rhodolith bed' and counting rows...")
cursor <- table$select(filter = "type == 'Rhodolith bed'")
print(nrow(cursor$collect()))


print("Aggregating by type on count...")
print(table$aggregate(
  group_by = "type",
  aggr = list(
    type = "count"
  )
))

cat("\nDone ✅\n")
