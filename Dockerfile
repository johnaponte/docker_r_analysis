# By JJAV 2025
ARG R_VERSION=4.4.3
ARG NAMESPACE_FROM=rocker
FROM ${NAMESPACE_FROM}/verse:${R_VERSION}

# Set pkgr version
ENV PKGR_VERSION=3.1.2

# Install Java, JAGS, pkgr, sf dependences and renv
RUN apt-get update && apt-get install -y \
    default-jdk \
    jags \
    htop \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
 && curl -L https://github.com/metrumresearchgroup/pkgr/releases/download/v${PKGR_VERSION}/pkgr_${PKGR_VERSION}_linux_amd64.tar.gz -o /tmp/pkgr.tar.gz \
 && tar -xzf /tmp/pkgr.tar.gz pkgr \
 && mv pkgr /usr/local/bin/pkgr \
 && chmod +x /usr/local/bin/pkgr \
 && rm /tmp/pkgr.tar.gz \
 && rm -rf /var/lib/apt/lists/* \
 && Rscript -e "install.packages('renv')"

 # Install chromium and dependencies
 RUN apt-get update && \
    apt-get install -y wget gnupg2 software-properties-common ca-certificates --no-install-recommends && \
    add-apt-repository -y ppa:xtradeb/apps && \
    apt-get update && \
    apt-get install -y chromium chromium-driver --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
    
# Customized entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
