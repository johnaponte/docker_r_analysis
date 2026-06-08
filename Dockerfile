# By JJAV 2025
ARG R_VERSION=4.4.3
ARG NAMESPACE_FROM=rocker
FROM ${NAMESPACE_FROM}/verse:${R_VERSION}

# Install Java, JAGS, sf dependencies and renv
RUN apt-get update && apt-get install -y \
    default-jdk \
    jags \
    htop \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libgsl0-dev \
 && rm -rf /var/lib/apt/lists/* \
 && Rscript -e "install.packages('renv')"

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

# Copy rstudio-server config file
COPY rserver.conf /etc/rstudio/rserver.conf
    
# Customized entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh




CMD ["/entrypoint.sh"]
