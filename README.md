# Reproducible R Analysis Container

This repository provides a Docker container for reproducible R analyses,
 based on the [`rocker/verse`](https://hub.docker.com/r/rocker/verse) image.

## Key Features

- Based on `rocker/rverse`, with `R_VERSION` passed as a build parameter.
- Adds the following to the base image:
  - **Java**
  - **JAGS**
  - **[pkgr](https://github.com/r-hub/pkgr)** for package management.
- The default RStudio user is replaced with a **randomly generated username**.
- `USER_NAME` and `USER_PASSWORD` can be set when the container is created.
- The `R_LIBS` environment variable includes `~/home` as the first library path.
- The `renv`package is included

## Usage

You can customize the container using build-time and runtime environment variables. 
See the Dockerfile and entrypoint script for more details.
The utility `build_image`can help

`./build_image` 4.4.3

will constuct the image `r_analysis:4.4.3` based on the `rocker/verse:4.4.3` image




