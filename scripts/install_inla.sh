#!/bin/bash
set -euo pipefail

# INLA_VERSION is the date-based version, e.g. "26.08.22".
# It pins BOTH the R package and the compiled binary — they must match, or the
# binary rejects the Model.ini written by the R package and aborts the fit.
# The git tag is "Version_${INLA_VERSION}"; the tarball is INLA_${INLA_VERSION}.tar.gz.
INLA_VERSION="${INLA_VERSION:-26.08.22}"
ARCH=$(uname -m)
INLA_REPO="https://inla.r-inla-download.org/R/testing"

# Install the INLA R package, pinned to ${INLA_VERSION}.
# The repo keeps every release in src/contrib, so the tarball URL is stable.
# pak's "INLA@<version>" syntax does not work against this repo (it reports a
# spurious dependency conflict), hence the explicit url:: spec.
# On amd64 this includes a working pre-built binary.
# On arm64 the R package installs fine but the bundled binary is x86-only,
# so we replace it with a natively compiled one below.
Rscript - <<REOF
pak::repo_add(INLA = "${INLA_REPO}")
pak::pkg_install("url::${INLA_REPO}/src/contrib/INLA_${INLA_VERSION}.tar.gz", ask = FALSE)
REOF

if [ "$ARCH" != "aarch64" ]; then
    echo "INLA ${INLA_VERSION} installed from repo (${ARCH})"
    exit 0
fi

echo "ARM64 detected — compiling INLA binary from source (Version_${INLA_VERSION})"

apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ gfortran make git \
    libmetis-dev libgsl-dev libblas-dev liblapack-dev \
    libmuparser-dev zlib1g-dev libltdl-dev r-mathlib rsync \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

git clone --depth 1 --recurse-submodules --shallow-submodules \
    --branch "Version_${INLA_VERSION}" \
    https://github.com/hrue/r-inla.git /tmp/r-inla

cd /tmp/r-inla

# Remove x86-only compiler flags
sed -i 's/-mfpmath=sse//g; s/-msse2//g' inlaprog/Makefile
sed -i 's/-mfpmath=sse//g; s/-msse2//g' extlibs/Makefile

# Both gmrflib and inlaprog compile files that include GMRFLib/fsort/... (uppercase)
# via -I.. pointing at the repo root. The source directory is gmrflib/ (lowercase) —
# Linux is case-sensitive. Create the alias before any make runs.
rm -rf /tmp/r-inla/GMRFLib
ln -s /tmp/r-inla/gmrflib /tmp/r-inla/GMRFLib

# Build GMRFLib (includes its own taucs — do not use extlibs/taucs-2.2)
cd gmrflib
make -j"$(nproc)"
make install
cd ..

# gmrflib/Makefile install skips the fsort/ subdirectory headers.
# Copy them explicitly so inlaprog can find quadsort.h via /usr/local/include as well.
mkdir -p /usr/local/include/GMRFLib/fsort
cp /tmp/r-inla/gmrflib/fsort/*.h /usr/local/include/GMRFLib/fsort/

# Some older INLA releases also drop headers from the Makefile's own HEADERS
# list despite the file existing in gmrflib/ — e.g. Version_24.05.10 omits
# sha.h, which graph.h includes, so inlaprog fails with "GMRFLib/sha.h: No
# such file or directory". Rather than special-case one header per version,
# copy every top-level gmrflib/*.h that `make install` didn't already place.
cp -n /tmp/r-inla/gmrflib/*.h /usr/local/include/GMRFLib/

# cgeneric-mapper.c expects external-packages/cgeneric-defs.h but the file is cgeneric.h
ln -sf /tmp/r-inla/external-packages/cgeneric.h \
       /tmp/r-inla/external-packages/cgeneric-defs.h

# Fix Makefile for R installed at /usr/local/lib/R, and add missing -lltdl
cd inlaprog
sed -i 's|RLIB_INC = .*|RLIB_INC = -DINLA_WITH_LIBR -I/usr/local/lib/R/include -I/usr/include|' Makefile
sed -i 's|RLIB_LIB = .*|RLIB_LIB = -L/usr/lib -lRmath -L/usr/local/lib/R/lib -lR|' Makefile
sed -i 's/-lmuparser/-lmuparser -lltdl/' Makefile

# Suppress clock-skew warnings from make in containers (ignore errors from unresolvable paths)
find /tmp/r-inla -type f | xargs touch 2>/dev/null || true

make -j"$(nproc)"

# Install binary to a stable system path
mkdir -p /opt/inla/bin
cp inla /opt/inla/bin/inla
chmod +x /opt/inla/bin/inla

file /opt/inla/bin/inla

# Wire INLA to use the compiled binary for every user, system-wide
echo 'if (requireNamespace("INLA", quietly = TRUE)) INLA::inla.setOption(inla.call = "/opt/inla/bin/inla")' \
    >> /usr/local/lib/R/etc/Rprofile.site

# Remove the build tree — the binary is all we need
rm -rf /tmp/r-inla

echo "INLA ${INLA_VERSION} binary installed at /opt/inla/bin/inla (arm64)"
