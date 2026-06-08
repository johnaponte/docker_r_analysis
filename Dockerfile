# By JJAV 2025
ARG R_VERSION=4.4.3
ARG NAMESPACE_FROM=rocker
FROM ${NAMESPACE_FROM}/verse:${R_VERSION}

# Install Java, JAGS, sf dependencies
RUN apt-get update && apt-get install -y \
    default-jdk \
    jags \
    htop \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libgsl0-dev \
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
    texlive-xetex \
    texlive-luatex \
    texlive-plain-generic \
    texlive-bibtex-extra \
    biber \
 && rm -rf /var/lib/apt/lists/*

# Install R packages: bootstrap pak, then use pak for everything else
# INLA repo added for its pre-built amd64/arm64 binaries
RUN Rscript -e "install.packages('pak', repos = sprintf('https://r-lib.github.io/p/pak/stable/%s/%s/%s', .Platform\$pkgType, R.Version()\$os, R.Version()\$arch))" \
 && Rscript -e "pak::repo_add(INLA = 'https://inla.r-inla-download.org/R/stable'); pak::pkg_install(c('renv', 'INLA', 'repana', 'quarto', 'targets', 'tarchetypes'))"

# Copy rstudio-server config file
COPY rserver.conf /etc/rstudio/rserver.conf

# Customized entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
