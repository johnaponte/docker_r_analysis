#!/bin/bash
# Usage: ./build_image.sh \
#          --namespaceto <TARGET_NAMESPACE> \
#          [--target <BAKE_TARGET>] \
#          [--rver <R_VERSION>] \
#          [--namespacefrom <SOURCE_NAMESPACE>]
#
# R/Quarto/INLA/CRAN-snapshot versions are centralized in docker-bake.hcl.
# --target selects a bake target directly (e.g. r4-6-1).
# --rver is a convenience alias translated to --target r<version-with-dashes>;
# it errors if it conflicts with an explicitly given --target.
# With neither flag, the bake file's "default" group target is used.
#
# Tag is automatically determined from the latest Docker Hub tag for the image.
# by JJAV 20250520, updated for docker-bake.hcl version centralization

set -e

BAKE_FILE="docker-bake.hcl"
TARGET=""
R_VERSION_ARG=""
NAMESPACE_FROM_OVERRIDE=""
NAMESPACE_TO=""

usage() {
  echo "Usage: $0 --namespaceto <TARGET_NAMESPACE> [--target <BAKE_TARGET>] [--rver <R_VERSION>] [--namespacefrom <SOURCE_NAMESPACE>]"
  echo "  --namespaceto:   Namespace used when tagging/pushing image (required)"
  echo "  --target:        docker-bake.hcl target to build (e.g. r4-6-1). Defaults to the bake 'default' group target."
  echo "  --rver:          R version (e.g. 4.6.1) — resolved to a bake target (r4-6-1). Alias for --target."
  echo "  --namespacefrom: Overrides docker-bake.hcl's NAMESPACE_FROM (source of the verse image) for this build"
  exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --rver)
      R_VERSION_ARG="$2"
      shift
      ;;
    --target)
      TARGET="$2"
      shift
      ;;
    --namespacefrom)
      NAMESPACE_FROM_OVERRIDE="$2"
      shift
      ;;
    --namespaceto)
      NAMESPACE_TO="$2"
      shift
      ;;
    *)
      echo "Unknown parameter passed: $1"
      usage
      ;;
  esac
  shift
done

[ -z "$NAMESPACE_TO" ] && usage
command -v jq >/dev/null || { echo "ERROR: jq is required" >&2; exit 1; }

# `bake --print` uses Docker's own HCL parser, so nothing here has to
# understand the file format. Printed alone, it only resolves the file's
# "default" group — the right way to read what that group actually is.
DEFAULT_TARGET=$(docker buildx bake -f "$BAKE_FILE" --print 2>/dev/null | jq -r '.group.default.targets[0] // empty')
if [ -z "$DEFAULT_TARGET" ]; then
  echo "ERROR: could not resolve default target from ${BAKE_FILE}" >&2
  exit 1
fi

# To resolve --rver by R_VERSION (see below) every target must be fully
# resolved, not just the default group's — but passing every target name to
# --print makes bake treat THAT set as "default" in its output, so the real
# default group must come from the call above, not this one. Target names
# are plain identifiers (no spaces/globs), so word-splitting them is safe —
# kept as a plain string rather than an array for bash 3.2 compatibility
# (macOS ships bash 3.2, which has no mapfile/readarray).
ALL_TARGETS=$(docker buildx bake -f "$BAKE_FILE" --list=targets 2>/dev/null | tail -n +2 | awk '{print $1}')
if [ -z "$ALL_TARGETS" ]; then
  echo "ERROR: could not list targets from ${BAKE_FILE}" >&2
  exit 1
fi
BAKE_JSON=$(docker buildx bake -f "$BAKE_FILE" --print $ALL_TARGETS 2>/dev/null || true)
if [ -z "$BAKE_JSON" ]; then
  echo "ERROR: could not read ${BAKE_FILE}" >&2
  exit 1
fi

# --rver resolves to a target by matching its R_VERSION arg, not by guessing
# a target-name convention — so it still works if a target is ever named
# differently from its R_VERSION.
if [ -n "$R_VERSION_ARG" ]; then
  RVER_TARGETS=$(jq -r --arg rv "$R_VERSION_ARG" '.target | to_entries[] | select(.value.args.R_VERSION == $rv) | .key' <<<"$BAKE_JSON")
  if [ -z "$RVER_TARGETS" ]; then
    echo "ERROR: no target in ${BAKE_FILE} has R_VERSION = ${R_VERSION_ARG}" >&2
    exit 1
  fi
  if [ "$(wc -l <<<"$RVER_TARGETS" | tr -d ' ')" -gt 1 ]; then
    echo "ERROR: multiple targets in ${BAKE_FILE} have R_VERSION = ${R_VERSION_ARG}: $(tr '\n' ' ' <<<"$RVER_TARGETS")" >&2
    exit 1
  fi
  if [ -n "$TARGET" ] && [ "$TARGET" != "$RVER_TARGETS" ]; then
    echo "ERROR: --rver ${R_VERSION_ARG} (resolves to target '${RVER_TARGETS}') conflicts with --target ${TARGET}" >&2
    exit 1
  fi
  TARGET="$RVER_TARGETS"
fi
TARGET_KEY="${TARGET:-$DEFAULT_TARGET}"

if [ "$(jq -r --arg t "$TARGET_KEY" '.target | has($t)' <<<"$BAKE_JSON")" != "true" ]; then
  echo "ERROR: target '${TARGET_KEY}' not found in ${BAKE_FILE}" >&2
  exit 1
fi
get_arg() { jq -r --arg t "$TARGET_KEY" --arg a "$1" '.target[$t].args[$a] // empty' <<<"$BAKE_JSON"; }

R_VERSION=$(get_arg R_VERSION)
QUARTO_VERSION=$(get_arg QUARTO_VERSION)
INLA_VERSION=$(get_arg INLA_VERSION)
CRAN_SNAPSHOT=$(get_arg CRAN_SNAPSHOT)
NAMESPACE_FROM=$(get_arg NAMESPACE_FROM)
[ -n "$NAMESPACE_FROM_OVERRIDE" ] && NAMESPACE_FROM="$NAMESPACE_FROM_OVERRIDE"

for v in R_VERSION QUARTO_VERSION INLA_VERSION CRAN_SNAPSHOT NAMESPACE_FROM; do
  if [ -z "${!v}" ]; then
    echo "ERROR: ${v} could not be resolved for target '${TARGET_KEY}'" >&2
    exit 1
  fi
done

if [[ "$CRAN_SNAPSHOT" == TODO* ]]; then
  echo "ERROR: target '${TARGET_KEY}' has an unresolved CRAN_SNAPSHOT placeholder (${CRAN_SNAPSHOT})." >&2
  echo "       Research and set a real P3M snapshot date in ${BAKE_FILE} before building this target." >&2
  exit 1
fi

# Drift check: bake args vs Dockerfile ARG defaults. Only meaningful for the
# default target, since the Dockerfile only carries one set of defaults —
# bake always overrides them anyway, so the check would block every build
# but the default one if applied elsewhere.
if [ "$TARGET_KEY" == "$DEFAULT_TARGET" ]; then
  DRIFT=""
  for ARG_NAME in R_VERSION QUARTO_VERSION INLA_VERSION CRAN_SNAPSHOT; do
    BAKE_VAL=$(get_arg "$ARG_NAME")
    DF_VAL=$(grep -m1 "^ARG ${ARG_NAME}=" Dockerfile | cut -d= -f2- || true)
    if [[ -n "$BAKE_VAL" && -n "$DF_VAL" && "$BAKE_VAL" != "$DF_VAL" ]]; then
      DRIFT+="  ${ARG_NAME}: bake=${BAKE_VAL}  Dockerfile=${DF_VAL}"$'\n'
    fi
  done
  if [ -n "$DRIFT" ]; then
    echo "ERROR: docker-bake.hcl and the Dockerfile disagree on default-target values:" >&2
    printf '%s' "$DRIFT" >&2
    echo "       The Dockerfile defaults must mirror the default target, so a plain" >&2
    echo "       'docker build' reproduces what this script builds." >&2
    exit 1
  fi
fi

R_VERSION_FORMATTED="${R_VERSION//./_}"
REPO_NAME="r_analysis-${R_VERSION_FORMATTED}"

echo "Building target '${TARGET_KEY}': R ${R_VERSION}, Quarto ${QUARTO_VERSION}, INLA ${INLA_VERSION}, CRAN snapshot ${CRAN_SNAPSHOT}, from ${NAMESPACE_FROM}/verse"

# Read latest integer tag from Docker Hub and increment
echo "Fetching latest tag for ${NAMESPACE_TO}/${REPO_NAME} from Docker Hub..."
LATEST_TAG=$(curl -s "https://hub.docker.com/v2/repositories/${NAMESPACE_TO}/${REPO_NAME}/tags/?page_size=100" \
  | jq -r '.results[].name' 2>/dev/null \
  | grep -E '^[0-9]+$' \
  | sort -n \
  | tail -1)

if [ -z "$LATEST_TAG" ]; then
  echo "No existing tag found — starting at 1"
  NEW_TAG="1"
else
  NEW_TAG="$((LATEST_TAG + 1))"
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
  --build-arg QUARTO_VERSION="${QUARTO_VERSION}" \
  --build-arg INLA_VERSION="${INLA_VERSION}" \
  --build-arg CRAN_SNAPSHOT="${CRAN_SNAPSHOT}" \
  --label org.opencontainers.image.title="R Analysis Container" \
  --label org.opencontainers.image.version="${NEW_TAG}" \
  --label org.opencontainers.image.created="${CREATED_DATE}" \
  --label org.opencontainers.image.description="Docker image for reproducible R analysis with rocker/verse, Java, JAGS, renv, pak, Quarto ${QUARTO_VERSION}, R-INLA ${INLA_VERSION}, targets, tarchetypes, repana, geo packages (terra/spdep/stars/raster/gstat/ncdf4), chromium, and gh CLI. CRAN pinned to P3M snapshot ${CRAN_SNAPSHOT}." \
  --label org.opencontainers.image.licenses="MIT" \
  --label org.opencontainers.image.source="https://github.com/johnaponte/docker_r_analysis.git" \
  --label org.opencontainers.image.documentation="https://github.com/johnaponte/docker_r_analysis/blob/main/README.md" \
  -t "${NAMESPACE_TO}/${REPO_NAME}:${NEW_TAG}" \
  -t "${NAMESPACE_TO}/${REPO_NAME}:latest" \
  --push \
  .

echo "Image ${NAMESPACE_TO}/${REPO_NAME}:${NEW_TAG} built and pushed successfully."
