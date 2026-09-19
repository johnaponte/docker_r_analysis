# Reproducible R Analysis Container

This repository provides a Docker container for reproducible R analyses, based on the [`rocker/verse`](https://hub.docker.com/r/rocker/verse) image (built by default from `jjserver/verse`, a community rebuild with arm64 support).

## Key Features

- Based on `jjserver/verse` (a community `rocker/verse` rebuild with arm64 support), with every version pinned via `docker-bake.hcl` — see [Versioning](#versioning).
- Adds the following to the base image:
  - **Java**
  - **JAGS**
  - **[renv](https://rstudio.github.io/renv/)** for project-level package reproducibility
  - **[pak](https://pak.r-lib.org/)** for fast and reliable package installation
  - **[R-INLA](https://www.r-inla.org/)** for Bayesian inference using INLA, pinned to a specific release (R package and compiled binary match by construction); compiled from source on arm64
  - **[targets](https://docs.ropensci.org/targets/) + [tarchetypes](https://docs.ropensci.org/tarchetypes/)** for pipeline-based analysis
  - **[repana](https://cran.r-project.org/package=repana)** for reproducible analysis workflows
  - **Quarto CLI**, pinned to a specific release (not inherited from the base image, whose bundled version drifts on every rebuild), plus the **quarto** R package
  - **Geo stack**: `terra`, `spdep`, `stars`, `raster`, `gstat`, `ncdf4` (`sf`/`sp` already ship with the base image)
  - **Full LaTeX base** (texlive-latex-base, texlive-latex-extra, texlive-fonts-extra, texlive-xetex, texlive-luatex, biber, and more) for Quarto PDF rendering
  - **Chromium** for headless browser support
  - **GitHub CLI (gh)**
- R packages are pinned to a dated Posit Package Manager (P3M) CRAN snapshot, so the same commit produces the same package set on every rebuild.
- Ubuntu security patches are applied at build time (`apt-get upgrade`), on top of whatever the base image shipped with.
- Sets `R_LIBS` to include the user home as the first library path.
- Creates an RStudio user with a **randomly generated password** by default.
- Supports a custom user via `USER_NAME` and `USER_PASSWORD` environment variables at runtime.

## Image Creation

The tag is automatically determined by reading the latest tag from Docker Hub and incrementing it.
R/Quarto/INLA/CRAN-snapshot versions come from `docker-bake.hcl` (see [Versioning](#versioning)); `--namespacefrom` overrides the base image org and defaults to `jjserver`.

```bash
./build_image.sh --target r4-6-1 --namespaceto <your namespace>
# or, equivalently, using the R-version alias:
./build_image.sh --rver 4.6.1 --namespaceto <your namespace>
# with no --target/--rver, the bake file's default target (currently r4-6-1) is used:
./build_image.sh --namespaceto <your namespace>
```

This will create `<your namespace>/r_analysis-4_6_1:<next tag>` and also tag it as `latest`.

When building the default target, `build_image.sh` checks that `docker-bake.hcl` and the Dockerfile's `ARG` defaults agree, and refuses to build if they've drifted (this check does not apply to non-default targets, since bake always overrides the Dockerfile's single set of defaults anyway).

> **Note:** `rocker` does not produce ARM64 images. If you need ARM64 support, build your own
> base image and pass it via `--namespacefrom`.

## Versioning

`docker-bake.hcl` is the single source of truth for R, Quarto, INLA, and CRAN-snapshot versions — one target per R version:

```bash
docker buildx bake --print              # show the default target's resolved args
docker buildx bake --print r4-6-0       # show a specific target
```

To add a new R version, add a `target` block to `docker-bake.hcl` (INLA/Quarto versions should follow the matrix in `docker_verse_mod/docker-bake.hcl`); no Dockerfile edit is needed unless that target is promoted to `default`, in which case the Dockerfile's `ARG` defaults must be updated to match (`build_image.sh` will otherwise refuse to build the default target).

Some targets (`r4-3-3`, `r4-4-3`, `r4-5-3`) currently carry a `TODO-VERIFY-CRAN-SNAPSHOT-DATE-FOR-R-*` placeholder instead of a real `CRAN_SNAPSHOT` date — both `scripts/set_cran_snapshot.sh` and `build_image.sh` refuse to build those targets until a real date is researched and filled in.

## Repository Structure

```
docker_r_analysis/
├── Dockerfile
├── docker-bake.hcl          # R/Quarto/INLA/CRAN-snapshot versions, one target per R version
├── build_image.sh           # builds + pushes a bake target, reading versions from docker-bake.hcl
├── create_r_project.sh      # scaffolds a downstream deployment directory (see below)
├── config/
│   └── rserver.conf         # copied to /etc/rstudio/rserver.conf
└── scripts/
    ├── entrypoint.sh
    ├── set_cran_snapshot.sh
    ├── install_quarto.sh
    ├── install_r_packages.sh
    └── install_inla.sh
```

## Running R from the Command Line

To use R from the container without installing it locally, add this function to your `~/.zshrc` or `~/.bashrc`:

```bash
R() {
  local image="${R_DOCKER_IMAGE:-jjserver/r_analysis-4_6_1:latest}"
  docker run --rm -it \
    -v "$(pwd):/home/rstudio/project" \
    -w /home/rstudio/project \
    "$image" R "$@"
}
```

After reloading your shell (`source ~/.zshrc`), typing `R` will launch R inside the container
with the current directory mounted as the working directory.

## Container Deployment

The container can be run using Docker Compose with an `.env` file (note: password is stored in plain text in `.env`).
The `docker-compose.yml` should be adapted to ensure the container name is unique and the host port
does not conflict with other services. The volume path for projects should be set correctly.

```bash
<path to script>/create_r_project.sh --container <your namespace>/r_analysis-4_6_1 --tag <tag>
```

### File structure
```
r-analysis-project/
├── .gitignore               # Prevents accidental Git inclusion
├── .env                     # Contains USER_NAME and USER_PASSWORD
├── docker-compose.yml       # For running the container
└── projects/                # Volume for persistent analysis work
    └── (your R project files go here)
```

### `.gitignore` file:
```
.DS_Store
.env
# Each project must have its own git repository
projects
```

### `.env` file:
```env
USER_NAME=myuser
USER_PASSWORD=mysecretpass
```

### `docker-compose.yml`:
```yaml
services:
  rstudio:
    image: <your namespace>/r_analysis-4_6_1:latest
    container_name: r_analysis_myproject
    ports:
      - "8787:8787"
    environment:
      USER_NAME: "${USER_NAME}"
      USER_PASSWORD: "${USER_PASSWORD}"
    volumes:
      - "./projects:/home/${USER_NAME}"
    restart: unless-stopped
```

This setup creates a persistent RStudio environment secured with credentials from the `.env` file.
