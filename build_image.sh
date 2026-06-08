#!/bin/bash
# Usage: ./build_image.sh \
#          --rver <R_VERSION> \
#          --namespaceto <TARGET_NAMESPACE> \
#          [--namespacefrom <SOURCE_NAMESPACE>]
#
# Tag is automatically determined from the latest Docker Hub tag for the image.
# by JJAV 20250520

set -e

# Default values
R_VERSION=""
NAMESPACE_FROM="jjserver"
NAMESPACE_TO=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --rver)
      R_VERSION="$2"
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
      echo "Usage: $0 --rver <R_VERSION> --namespaceto <TARGET_NAMESPACE> [--namespacefrom <SOURCE_NAMESPACE>]"
      echo "  --rver:          R version to use (e.g., 4.4.3)"
      echo "  --namespaceto:   Namespace used when tagging/pushing image"
      echo "  --namespacefrom: Source of verse namespace (default: jjserver)"
      exit 1
      ;;
  esac
  shift
done

if [ -z "$R_VERSION" ] || [ -z "$NAMESPACE_TO" ]; then
  echo "Usage: $0 --rver <R_VERSION> --namespaceto <TARGET_NAMESPACE> [--namespacefrom <SOURCE_NAMESPACE>]"
  echo "  --rver:          R version to use (e.g., 4.4.3)"
  echo "  --namespaceto:   Namespace used when tagging/pushing image (required)"
  echo "  --namespacefrom: Source of verse namespace (default: jjserver)"
  exit 1
fi

R_VERSION_FORMATTED="${R_VERSION//./_}"
REPO_NAME="r_analysis-${R_VERSION_FORMATTED}"

# Read latest semver tag from Docker Hub and increment patch
echo "Fetching latest tag for ${NAMESPACE_TO}/${REPO_NAME} from Docker Hub..."
LATEST_TAG=$(curl -s "https://hub.docker.com/v2/repositories/${NAMESPACE_TO}/${REPO_NAME}/tags/?page_size=100" \
  | jq -r '.results[].name' 2>/dev/null \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -1)

if [ -z "$LATEST_TAG" ]; then
  echo "No existing semver tag found — starting at 1.0.0"
  NEW_TAG="1.0.0"
else
  MAJOR=$(echo "$LATEST_TAG" | cut -d. -f1)
  MINOR=$(echo "$LATEST_TAG" | cut -d. -f2)
  PATCH=$(echo "$LATEST_TAG" | cut -d. -f3)
  NEW_TAG="${MAJOR}.${MINOR}.$((PATCH + 1))"
  echo "Latest tag: ${LATEST_TAG} → new tag: ${NEW_TAG}"
fi

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
  --label org.opencontainers.image.version="${NEW_TAG}" \
  --label org.opencontainers.image.created="${CREATED_DATE}" \
  --label org.opencontainers.image.description="Docker image for reproducible R analysis with rocker/verse, Java, JAGS, renv, pak, Quarto/LaTeX, R-INLA, targets, tarchetypes, repana, chromium, and gh CLI." \
  --label org.opencontainers.image.licenses="MIT" \
  --label org.opencontainers.image.source="https://github.com/johnaponte/docker_r_analysis.git" \
  --label org.opencontainers.image.documentation="https://github.com/johnaponte/docker_r_analysis/blob/main/README.md" \
  -t "${NAMESPACE_TO}/${REPO_NAME}:${NEW_TAG}" \
  -t "${NAMESPACE_TO}/${REPO_NAME}:latest" \
  --push \
  .

echo "Image ${NAMESPACE_TO}/${REPO_NAME}:${NEW_TAG} built and pushed successfully."
