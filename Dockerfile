# By JJAV 2025
ARG NAMESPACE_FROM=jjserver
ARG R_VERSION=4.6.1
FROM ${NAMESPACE_FROM}/verse:${R_VERSION}

# Re-declare so values are available in RUN layers after the FROM.
ARG NAMESPACE_FROM
ARG R_VERSION
# Quarto CLI; pinned rather than inherited from the base image, whose bundled
# version drifts on every rebuild and changes rendered output.
ARG QUARTO_VERSION=1.10.18
# INLA date-based version; pins the R package and the binary (they must match).
# The R/Quarto/INLA matrix lives in docker_verse_mod/docker-bake.hcl.
ARG INLA_VERSION=26.08.07
# Dated Posit snapshot that freezes every R package version. Without it the
# base image's .../noble/latest resolves packages to whatever is current on
# build day, so the same commit produces a different environment each time.
# This default is a static fallback for a plain `docker build`; building via
# docker-bake.hcl resolves the current R version's target to the actual
# build day instead (see docker-bake.hcl).
ARG CRAN_SNAPSHOT=2026-09-19

ENV DEBIAN_FRONTEND=noninteractive \
    R_VERSION=${R_VERSION} \
    NAMESPACE_FROM=${NAMESPACE_FROM} \
    QUARTO_VERSION=${QUARTO_VERSION} \
    INLA_VERSION=${INLA_VERSION} \
    CRAN_SNAPSHOT=${CRAN_SNAPSHOT} \
    CRAN=https://p3m.dev/cran/__linux__/noble/${CRAN_SNAPSHOT}

# Ubuntu security patches available at build time. The base image carries the
# patches that existed when IT was built, not when this image is built, and
# this image is rebuilt far more often than the base — so without this layer
# every fix published in between is missing. Deliberately placed before
# anything else is installed, so it only touches base packages.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Java, JAGS, sf/geo dependencies (libnetcdf-dev needed by ncdf4)
RUN apt-get update && apt-get install -y \
    default-jdk \
    jags \
    htop \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libgsl0-dev \
    libnetcdf-dev \
 && rm -rf /var/lib/apt/lists/*

# Install chromium and dependencies
RUN apt-get update && \
    apt-get install -y wget gnupg2 software-properties-common ca-certificates --no-install-recommends && \
    add-apt-repository -y ppa:xtradeb/apps && \
    apt-get update && \
    apt-get install -y chromium chromium-driver --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN apt-get update && \
    apt-get install -y gh --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Remove rocker's dummy texlive-local equivs package so apt can manage texlive,
# then install a full LaTeX base for Quarto (PDF, XeLaTeX, LuaLaTeX, bibliography)
RUN dpkg -r texlive-local \
 && apt-get update && apt-get install -y \
    texlive-latex-base \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-xetex \
    texlive-luatex \
    texlive-plain-generic \
    texlive-bibtex-extra \
    biber \
 && rm -rf /var/lib/apt/lists/*

# Freeze CRAN to a dated snapshot — must run before any R package install
COPY scripts/set_cran_snapshot.sh /tmp/set_cran_snapshot.sh
RUN bash /tmp/set_cran_snapshot.sh && rm /tmp/set_cran_snapshot.sh

# Quarto CLI, pinned to QUARTO_VERSION
COPY scripts/install_quarto.sh /tmp/install_quarto.sh
RUN bash /tmp/install_quarto.sh && rm /tmp/install_quarto.sh

# R packages: pak + renv, repana, quarto, targets, tarchetypes, geo stack
COPY scripts/install_r_packages.sh /tmp/install_r_packages.sh
RUN bash /tmp/install_r_packages.sh && rm /tmp/install_r_packages.sh

# INLA R package + native binary (compiled from source on arm64, pre-built on amd64)
COPY scripts/install_inla.sh /tmp/install_inla.sh
RUN bash /tmp/install_inla.sh && rm /tmp/install_inla.sh

# Copy rstudio-server config file
COPY config/rserver.conf /etc/rstudio/rserver.conf

# Customized entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
