################################################################################
###  0. Setup the environment                                                ###
################################################################################

# Install latest GitHub build
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("C4IROcean/odp-sdkr")

# Load the odp package
library(odp)

# Initialize the odp client
api_key <- "sk_your_api_key_here"
client <- odp_client(api_key = api_key)
# Or simply default to interactive browser login or ODP_API_KEY env var:
# client <- odp_client()


################################################################################
###  1. Read data                                                            ###
################################################################################

ds <- client$dataset("21b630bb-06b2-48de-a172-97a7a67e30ba") # amazon reef
table <- ds$table

# Select a batch of data from the table and return as a data frame
# NOTE: if the table is large, you might want to iterate over select instead
df <- table$select()$dataframe()
print(table$stats())
print(table$schema())

# Select by column 'type'
df_reef <- table$select(filter = "type == 'Reef structure'")$dataframe()
df_sponge <- table$select(filter = "type == 'Sponge occurrence'")$dataframe()
df_rodolith <- table$select(filter = "type == 'Rhodolith bed'")$dataframe()


################################################################################
###  2. Write data                                                           ###
################################################################################

my_ds <- client$dataset("your-dataset-uuid-here")
my_table <- my_ds$table

# Create and insert coral data frame into the new table
my_table$create(df_reef)
print(my_table$stats())
print(my_table$schema())

# Insert more data (append)
my_table$insert(df_sponge)

# for multi-step workflows, open a transaction
tx <- my_table$begin()  # open
tx$delete(query = "type == 'Reef structure'")
for (row in tx$replace(filter="area_km2 > 50")$rows()) {
  row$area_km2 <- row$area_km2 + 5  # add 5 to each area_km2 > 50
  tx$insert(row)
}
tx$insert(df_rodolith)
tx$commit()   # close


################################################################################
###  3. For more advanced features (like aggregation or schema manipulation),###
###     refer to: https://docs.hubocean.earth/                               ###
################################################################################
