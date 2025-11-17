tests_dir <- normalizePath(testthat::test_path(), winslash = "/", mustWork = TRUE)
pkg_root <- dirname(tests_dir)
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(pkg_root, helpers = FALSE, quiet = TRUE)
} else {
  stop("The pkgload package is required to run the test suite.")
}
