# Ocean Data Platform R SDK

The Ocean Data Platform (ODP) is a hosted catalog of curated marine and
environmental datasets. This package provides light-weight R bindings so you can
authenticate with your HubOcean account, navigate to a dataset, pick a table,
and stream rows straight into data frames or Arrow tables without leaving your
analysis workflow. The SDK supports streaming queries, server-side aggregations,
and raw file management (upload, download, ingest).

> Status: This sdk is still considered pre-release. We are looking for feedback,
> so please reach out if you have any issues, concerns or other ideas that you
> think can improve your experience using this sdk.

## Requirements

- R 4.1 or newer
- Packages declared in `DESCRIPTION` (install with `pak`, `renv`, or
  `install.packages()`)
- Authentication: either an API key or an interactive browser session (see
  [Authentication](#authentication) below)

## Getting Started

The hosted documentation at https://docs.hubocean.earth/sdk/unified/ is the canonical
place to learn more about authentication, cursors, batching, reading/writing, and advanced
patterns. Install the package locally and lean on the official docs when you
need deeper explanations or diagrams.

- `help(package = "odp")` gives a quick index of the exported helpers

## Development

- Install the package dependencies declared in `DESCRIPTION` and keep a recent
  version of `devtools`/`pkgload` around for running checks.
- Build the package locally `Rscript -e 'devtools::build()'`
- Run the unit tests with `R -q -e "devtools::test()"` and the full
  `devtools::check()` suite locally before opening a pull request. Tests use
  small synthetic Arrow streams, so they never call the live API.
- The repo ships a `.pre-commit-config.yaml` that runs `lintr` and `styler`
  through the helper scripts in `scripts/`. Install [pre-commit](https://pre-commit.com)
  once per machine and enable the hooks with `pre-commit install` to get the
  same linting enforced in CI.
- To lint/format everything manually (matching CI), run:

  ```sh
  Rscript --vanilla scripts/precommit_lintr.R $(git ls-files -- '*.R' '*.r' '*.Rmd' '*.rmd')
  Rscript --vanilla scripts/precommit_styler.R $(git ls-files -- '*.R' '*.r' '*.Rmd' '*.rmd')
  ```

- GitHub Actions keeps parity with the local tooling:
  `.github/workflows/lint-format-test.yml` runs the linters, formatting check,
  and the package's `testthat` suite (`devtools::test()`) on every push/PR.
- Build-able vignettes (`vignette("odp")`, `vignette("odp-tabular")`) ship with
  the repo; install with `build_vignettes = TRUE` if you want those walkthroughs
  available offline.
