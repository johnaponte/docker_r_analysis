# Reproducible R Analysis Container

This repository provides a Docker container for reproducible R analyses, based on the [`rocker/verse`](https://hub.docker.com/r/rocker/verse) image.

## Key Features

- Based on `rocker/verse`, with `R_VERSION` passed as a build argument.
- Adds the following to the base image:
  - **Java**
  - **JAGS**
  - **[renv](https://rstudio.github.io/renv/)** for project-level package reproducibility
  - **[pak](https://pak.r-lib.org/)** for fast and reliable package installation
  - **[R-INLA](https://www.r-inla.org/)** for Bayesian inference using INLA
  - **[targets](https://docs.ropensci.org/targets/) + [tarchetypes](https://docs.ropensci.org/tarchetypes/)** for pipeline-based analysis
  - **[repana](https://cran.r-project.org/package=repana)** for reproducible analysis workflows
  - **[quarto](https://quarto.org/)** R package (Quarto CLI is bundled in `rocker/verse`)
  - **Full LaTeX base** (texlive-latex-base, texlive-xetex, texlive-luatex, biber, and more) for Quarto PDF rendering
  - **Chromium** for headless browser support
  - **GitHub CLI (gh)**
- Sets `R_LIBS` to include the user home as the first library path.
- Creates an RStudio user with a **randomly generated password** by default.
- Supports a custom user via `USER_NAME` and `USER_PASSWORD` environment variables at runtime.

## Image Creation

The tag is automatically determined by reading the latest tag from Docker Hub and incrementing it.
The `--namespacefrom` defaults to `jjserver` but can be overridden.

```bash
./build_image.sh --rver 4.6.0 --namespaceto <your namespace>
```

This will create `<your namespace>/r_analysis-4_6_0:<next tag>` and also tag it as `latest`.

> **Note:** `rocker` does not produce ARM64 images. If you need ARM64 support, build your own
> base image and pass it via `--namespacefrom`.

## Running R from the Command Line

To use R from the container without installing it locally, add this function to your `~/.zshrc` or `~/.bashrc`:

```bash
R() {
  local image="${R_DOCKER_IMAGE:-jjserver/r_analysis-4_6_0:latest}"
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
<path to script>/create_r_project.sh --container <your namespace>/r_analysis-4_6_0 --tag <tag>
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
    image: <your namespace>/r_analysis-4_6_0:latest
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
