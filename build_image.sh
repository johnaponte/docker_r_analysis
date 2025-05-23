#!/bin/bash
# Usage: ./build_image.sh \
#          --rver <R_VERSION> \
#          --tag <TAG> \
#          --namespacefrom <SOURCE_NAMESPACE> \
#          --namespaceto <TARGET_NAMESPACE>
# by JJAV 20250520

set -e

 # Default values
R_VERSION=""
TAG=""
NAMESPACE_FROM=""
NAMESPACE_TO=""

 # Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --rver)
      R_VERSION="$2"
      shift
      ;;
    --tag)
      TAG="$2"
      shift
      ;;
    --namespacefrom)
      NAMESPACE_FROM="$2"
      shift
      ;;
    --namespaceto)
      NAMESPACE_TO="$2"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      echo "Usage: $0 --rver <R_VERSION> --tag <TAG> --namespacefrom <SOURCE_NAMESPACE> [--namespaceto <TARGET_NAMESPACE>]"
      echo "  --rver: R version to use (e.g., 4.4.3)"
      echo "  --tag: Tag for the resulting Docker image (e.g., latest)"
      echo "  --namespacefrom: Namespace used inside the Docker build (passed as build arg)"
      echo "  --namespaceto: Namespace used when tagging/pushing image"
      exit 1
      ;;
  esac
  shift
done

if [ -z "$R_VERSION" ] || [ -z "$TAG" ] || [ -z "$NAMESPACE_TO" ]; then
  echo "Usage: $0 --rver <R_VERSION> --tag <TAG> --namespacefrom <SOURCE_NAMESPACE> --namespaceto <TARGET_NAMESPACE>"
  echo "  --rver: R version to use (e.g., 4.4.3)"
  echo "  --tag: Tag for the resulting Docker image (e.g., latest)"
  echo "  --namespacefrom: Source of verse. Namespace  passed as build arg"
  echo "  --namespaceto: Namespace used when tagging/pushing image (required)"
  exit 1
fi

R_VERSION_FORMATTED="${R_VERSION//./_}"
CREATED_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Ensure a multiarch builder is configured
if ! docker buildx inspect multiarch-builder &>/dev/null; then
  docker buildx create --name multiarch-builder --driver docker-container --use
else
  docker buildx use multiarch-builder
fi
docker buildx inspect --bootstrap

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg R_VERSION="${R_VERSION}" \
  --build-arg NAMESPACE_FROM="${NAMESPACE_FROM}" \
  --label org.opencontainers.image.title="R Analysis Container" \
  --label org.opencontainers.image.version="${TAG}" \
  --label org.opencontainers.image.created="${CREATED_DATE}" \
  --label org.opencontainers.image.description="Docker image for reproducible R analysis with rocker/verse, Java, JAGS, and pkgr." \
  --label org.opencontainers.image.licenses="MIT" \
  --label org.opencontainers.image.source="https://github.com/johnaponte/docker_r_analysis.git" \
  --label org.opencontainers.image.documentation="https://github.com/johnaponte/docker_r_analysis/blob/main/README.md" \
  -t "${NAMESPACE_TO}/r_analysis-${R_VERSION_FORMATTED}:${TAG}" \
  -t "${NAMESPACE_TO}/r_analysis-${R_VERSION_FORMATTED}:latest" \
  --push \
  .

echo "Image ${IMAGE_NAME} built successfully with metadata."