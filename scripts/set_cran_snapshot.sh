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
#
# The Ubuntu codename is detected rather than hardcoded: jjserver/verse images
# are noble (24.04), but rocker/verse images for older R versions (e.g. 4.3.3)
# are jammy (22.04) — a wrong codename here would fetch binaries for the wrong
# Ubuntu release.
CRAN_SNAPSHOT="${CRAN_SNAPSHOT:?CRAN_SNAPSHOT must be set}"
CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
SNAPSHOT_URL="https://p3m.dev/cran/__linux__/${CODENAME}/${CRAN_SNAPSHOT}"

# Fail here with a clear message rather than leaving R to fail later with an
# opaque download error on every package.
if ! curl -sfI --max-time 30 "${SNAPSHOT_URL}/src/contrib/PACKAGES" >/dev/null; then
    echo "ERROR: no Posit snapshot at ${SNAPSHOT_URL}" >&2
    exit 1
fi

# Rewrite only the URL. Rprofile.site also sets HTTPUserAgent, which is what
# makes P3M serve prebuilt binaries instead of source — overwriting the file
# would silently turn every install into a source build.
#
# The pattern below matches any existing p3m.dev/cran URL, not just the
# __linux__/noble/<date> form: different base image builds have shipped
# different defaults (e.g. jjserver/verse:4.4.3 ships a bare
# 'https://p3m.dev/cran/<date>' with no __linux__/noble segment at all).
# Matching more narrowly silently no-ops on those images, leaving CRAN
# unpinned — this failed loudly for r4-4-3 instead of catching it early.
RPROFILE=/usr/local/lib/R/etc/Rprofile.site
sed -i -E "s|https://p3m\.dev/cran/[^']*|${SNAPSHOT_URL}|g" "${RPROFILE}"

ACTIVE=$(Rscript -e 'cat(getOption("repos")[["CRAN"]])')
if [ "${ACTIVE}" != "${SNAPSHOT_URL}" ]; then
    echo "ERROR: repo pin did not take. Expected ${SNAPSHOT_URL}, got ${ACTIVE}" >&2
    exit 1
fi
echo "CRAN pinned to ${SNAPSHOT_URL}"
