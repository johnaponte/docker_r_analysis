# Single source of truth for every pinned version in this image.
#
# One target per R version. Targets coexist, so an older R can be rebuilt to
# pick up Ubuntu security patches without editing the Dockerfile or committing
# anything — which is the whole point of pinning R while keeping the base OS
# patched.
#
#   docker buildx bake                     # build the default target
#   docker buildx bake r4-6-1 --push       # build and push one target
#   docker buildx bake --print r4-6-1      # show resolved args, no build
#
# build_image.sh reads the versions from here via `--print`, so this file is
# authoritative. The ARG defaults in the Dockerfile exist only so a plain
# `docker build` still works; build_image.sh verifies the two agree (for the
# default target) and refuses to build if they have drifted.
#
# QUARTO_VERSION/INLA_VERSION come from docker_verse_mod/docker-bake.hcl,
# the repo that holds the intended R/Quarto/INLA version matrix. CRAN_SNAPSHOT
# is this repo's own addition — pick a recent date for the R version that is
# current, and for a superseded one, the day before its successor was released.

variable "REGISTRY" { default = "jjserver" }

# Docker tag for this build. build_image.sh sets it to the next sequential
# build number; it defaults to "latest" for local builds.
variable "BUILD_TAG" { default = "latest" }

# "jjserver" (amd64 + arm64) or "rocker" (amd64 only — rocker publishes no
# arm64 image).
variable "NAMESPACE_FROM" { default = "jjserver" }

target "_common" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    NAMESPACE_FROM = NAMESPACE_FROM
  }
}

target "r4-3-3" {
  inherits = ["_common"]
  args = {
    R_VERSION      = "4.3.3"
    QUARTO_VERSION = "1.9.38"
    INLA_VERSION   = "23.05.30-1"
    # Day before R 4.4.0 was released (2024-04-24, real r-project.org date),
    # so the package set matches the era when 4.3.3 was current.
    CRAN_SNAPSHOT  = "2024-04-23"
  }
  tags = [
    "${REGISTRY}/r_analysis-4_3_3:${BUILD_TAG}",
    "${REGISTRY}/r_analysis-4_3_3:latest",
  ]
}

target "r4-4-3" {
  inherits = ["_common"]
  args = {
    R_VERSION      = "4.4.3"
    QUARTO_VERSION = "1.9.38"
    INLA_VERSION   = "24.05.10"
    # Day before R 4.5.0 was released (2025-04-11, real r-project.org date),
    # so the package set matches the era when 4.4.3 was current.
    CRAN_SNAPSHOT  = "2025-04-10"
  }
  tags = [
    "${REGISTRY}/r_analysis-4_4_3:${BUILD_TAG}",
    "${REGISTRY}/r_analysis-4_4_3:latest",
  ]
}

target "r4-5-3" {
  inherits = ["_common"]
  args = {
    R_VERSION      = "4.5.3"
    QUARTO_VERSION = "1.9.38"
    INLA_VERSION   = "25.04.29"
    # Day before R 4.6.0 was released (2026-04-24, r-project.org / r-announce),
    # so the package set matches the era when 4.5.3 was current.
    CRAN_SNAPSHOT  = "2026-04-23"
  }
  tags = [
    "${REGISTRY}/r_analysis-4_5_3:${BUILD_TAG}",
    "${REGISTRY}/r_analysis-4_5_3:latest",
  ]
}

# Kept so this image can be rebuilt for Ubuntu security patches without
# changing the R environment an analysis was validated against. Not in the
# default group: build it explicitly with `./build_image.sh --target r4-6-0`.
target "r4-6-0" {
  inherits = ["_common"]
  args = {
    R_VERSION      = "4.6.0"
    QUARTO_VERSION = "1.10.18"
    INLA_VERSION   = "26.08.07"
    # Day before R 4.6.1 was released (2026-06-24), so the package set
    # matches the era when 4.6.0 was current.
    CRAN_SNAPSHOT  = "2026-06-23"
  }
  tags = [
    "${REGISTRY}/r_analysis-4_6_0:${BUILD_TAG}",
    "${REGISTRY}/r_analysis-4_6_0:latest",
  ]
}

target "r4-6-1" {
  inherits = ["_common"]
  args = {
    R_VERSION      = "4.6.1"
    QUARTO_VERSION = "1.10.18"
    INLA_VERSION   = "26.08.07"
    # Current R version — resolved to the day the image is actually built,
    # so this never needs manual bumping. Once 4.6.1 is superseded and this
    # target is frozen for reproducibility, replace this with a fixed date
    # (day before the successor's release), same as the other targets above.
    CRAN_SNAPSHOT  = formatdate("YYYY-MM-DD", timestamp())
  }
  tags = [
    "${REGISTRY}/r_analysis-4_6_1:${BUILD_TAG}",
    "${REGISTRY}/r_analysis-4_6_1:latest",
  ]
}

group "default" {
  targets = ["r4-6-1"]
}
