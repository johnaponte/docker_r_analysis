#!/bin/bash
set -euo pipefail

# Bootstrap pak (uses r-lib's own pak repo, not CRAN — set_cran_snapshot.sh must
# already have run so every install after this one is pinned to the snapshot).
Rscript -e "install.packages('pak', repos = sprintf('https://r-lib.github.io/p/pak/stable/%s/%s/%s', .Platform\$pkgType, R.Version()\$os, R.Version()\$arch))"

# renv/repana/quarto/targets/tarchetypes: this repo's core toolchain.
# terra/spdep/stars/raster/gstat/ncdf4: geo packages absent from the
# jjserver/verse lineage (verified: sf/sp present, these are not).
# ncdf4 requires libnetcdf-dev, installed earlier in the Dockerfile.
# INLA is intentionally NOT installed here — see scripts/install_inla.sh,
# which runs after this script and needs pak already bootstrapped.
Rscript -e "pak::pkg_install(c(
  'renv',
  'repana',
  'quarto',
  'targets',
  'tarchetypes',
  'terra',
  'spdep',
  'stars',
  'raster',
  'gstat',
  'ncdf4'
), ask = FALSE)"
