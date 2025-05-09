#!/bin/bash
# Usage: ./build_image <R_VERSION> <TAG>
# Example: ./build_image 4.4.3 latest
# by JJAV 2025

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <R_VERSION> <TAG>"
  exit 1
fi

R_VERSION="$1"
TAG="$2"
IMAGE_NAME="r_analysis_${R_VERSION}:${TAG}"

docker build \
  --build-arg R_VERSION="${R_VERSION}" \
  -t "${IMAGE_NAME}" \
  .

echo "Image ${IMAGE_NAME} built successfully."