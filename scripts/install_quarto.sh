#!/bin/bash
set -euo pipefail

# Pin Quarto instead of inheriting whatever the base image bundles. The bundled
# version drifts with every base rebuild and changes rendered output, which
# defeats the point of pinning R itself.
QUARTO_VERSION="${QUARTO_VERSION:-1.10.18}"

# Quarto publishes linux-amd64 and linux-arm64 debs under the same release tag;
# dpkg's architecture names match Quarto's exactly.
ARCH="$(dpkg --print-architecture)"

wget -q \
    "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${ARCH}.deb" \
    -O /tmp/quarto.deb
dpkg -i /tmp/quarto.deb
rm /tmp/quarto.deb

# Fail the build here rather than at render time if the pin did not take.
INSTALLED="$(quarto --version)"
if [ "${INSTALLED}" != "${QUARTO_VERSION}" ]; then
    echo "ERROR: expected Quarto ${QUARTO_VERSION}, got ${INSTALLED}" >&2
    exit 1
fi
echo "Quarto ${INSTALLED} pinned"
