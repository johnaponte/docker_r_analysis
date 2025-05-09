# Reproducible R Analysis Container

This repository provides a Docker container for reproducible R analyses, based on the [`rocker/verse`](https://hub.docker.com/r/rocker/verse) image.

## Key Features

- Based on `rocker/verse`, with `R_VERSION` passed as a build argument.
- Adds the following to the base image:
  - **Java** (default in the Ubuntu-based `rocker/verse` container)
  - **JAGS** (default in the Ubuntu-based `rocker/verse` container)
  - **[pkgr](https://github.com/r-hub/pkgr)** for package management (default version: 3.1.2)
- Sets `R_LIBS` to include home as the first library path.
- Includes the appropriate `renv` package version matching `R_VERSION`.
- Creates an RStudio user with a **randomly generated password** by default.
- In addition, it can create a custom user by providing the `USER_NAME` and `USER_PASSWORD` environment variables at runtime, which should be the user for the container

## Image Creation

Container can be customized using build-time and runtime environment variables.  
Refer to the Dockerfile and entrypoint script for more details.  
Use the `build_image` utility script to simplify the process:

```bash
# /build_image R_VERSION TAG
./build_image 4.4.3 1
```

This will create the image `r_analysis-4_4_3:1`, based on the latest `rocker/verse:4.4.3` image.

## Container Deployment 

Container can be run using Docker Compose an .env file (please note password is plain in .env)
The yml file should be adapted to ensure container name is unique and the host port is not conflicting 
other services in the running environment.
The volumen for projects have the correct path

```bash
# Create the directory where to setup the project
# <path_to_executable>/create_r_project.sh <IMAGE> <TAG>
../create_r_project.sh r_analysis-4_4_3 1
```

### File structure
```
r-analysis-proyect/
├── .gitignore               # To not include in Git in case added to github
├── .env                     # Contains USER_NAME and USER_PASSWORD
├── docker-compose.yml       # For running the container
└── projects/                # Volume for persistent analysis work
    └── (your R project files go here)
```
### `.gitignore` file:
```
DS_STORE
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
    image: r_analysis_4.4.3:1
    container_name: r_analysis_ana
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
