#!/bin/bash
# Usage: ./build_image <R_VERSION> <TAG>
# Example: ./build_image 4.4.3 latest
# by JJAV 2025d

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <R_VERSION> <TAG>"
  exit 1
fi

R_VERSION="$1"
TAG="$2"
R_VERSION_FORMATTED="${R_VERSION//./_}"
IMAGE_NAME="r_analysis-${R_VERSION_FORMATTED}:${TAG}"
CREATED_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

docker build \
  --build-arg R_VERSION="${R_VERSION}" \
  --label org.opencontainers.image.title="R Analysis Container" \
  --label org.opencontainers.image.version="${TAG}" \
  --label org.opencontainers.image.created="${CREATED_DATE}" \
  --label org.opencontainers.image.description="Docker image for reproducible R analysis with rocker/verse, Java, JAGS, and pkgr." \
  --label org.opencontainers.image.licenses="MIT" \
  --label org.opencontainers.image.source="https://github.com/johnaponte/docker_r_analysis.git" \
  --label org.opencontainers.image.documentation="https://github.com/johnaponte/docker_r_analysis/blob/main/README.md" \
  -t "${IMAGE_NAME}" \
  .

echo "Image ${IMAGE_NAME} built successfully with metadata."