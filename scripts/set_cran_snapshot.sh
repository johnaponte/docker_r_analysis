#!/bin/bash
set -euo pipefail

# Freeze CRAN to a dated Posit Package Manager snapshot.
#
# The base image points at .../noble/latest, so every rebuild resolves every R
# package to whatever is current that day. That is the same drift that broke
# INLA, applied to the whole package set at once: two builds of the same commit
# months apart do not produce the same environment.
#
# Picking the date: for the R version that is still current, use a recent date.
# For a superseded R version, use the day before its successor was released, so
# the package set matches the era that R version belongs to.
CRAN_SNAPSHOT="${CRAN_SNAPSHOT:?CRAN_SNAPSHOT must be set}"
SNAPSHOT_URL="https://p3m.dev/cran/__linux__/noble/${CRAN_SNAPSHOT}"

# Fail here with a clear message rather than leaving R to fail later with an
# opaque download error on every package.
if ! curl -sfI --max-time 30 "${SNAPSHOT_URL}/src/contrib/PACKAGES" >/dev/null; then
    echo "ERROR: no Posit snapshot at ${SNAPSHOT_URL}" >&2
    exit 1
fi

# Rewrite only the URL. Rprofile.site also sets HTTPUserAgent, which is what
# makes P3M serve prebuilt binaries instead of source — overwriting the file
# would silently turn every install into a source build.
RPROFILE=/usr/local/lib/R/etc/Rprofile.site
sed -i -E "s|https://p3m\.dev/cran/__linux__/noble/[^']*|${SNAPSHOT_URL}|g" "${RPROFILE}"

ACTIVE=$(Rscript -e 'cat(getOption("repos")[["CRAN"]])')
if [ "${ACTIVE}" != "${SNAPSHOT_URL}" ]; then
    echo "ERROR: repo pin did not take. Expected ${SNAPSHOT_URL}, got ${ACTIVE}" >&2
    exit 1
fi
echo "CRAN pinned to ${SNAPSHOT_URL}"
