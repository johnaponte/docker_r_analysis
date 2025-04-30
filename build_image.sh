#!/bin/bash
# Usage: ./build_image <tag>
# Example: ./build_image 4.4.3
# by JJAV 2025

if [ -z "$1" ]; then
  echo "Usage: $0 <R_VERSION>"
  exit 1
fi

R_VERSION="$1"
IMAGE_NAME="docker_r_analysis:${R_VERSION}"

docker build \
  --build-arg R_VERSION="${R_VERSION}" \
  -t "${IMAGE_NAME}" \
  .

echo "Image ${IMAGE_NAME} built successfully."

docker run \
  -p 8787:8787 \
  -d \
  -e USER_NAME=master \
  -e USER_PASSWORD=holahola \
  -v /Users/japonte/development/rstudio_app2/projects:/home/master \
  --name borrar \
  ${IMAGE_NAME}

