test_that("client resolves from environment", {
  withr::local_envvar(ODP_API_KEY = "test-key")
  client <- OdpClient$new()
  dataset <- client$dataset("tbl")
  expect_s3_class(dataset, "OdpDataset")
  expect_s3_class(dataset$table, "OdpTable")
  expect_equal(client$base_url, "https://api.hubocean.earth")
})
