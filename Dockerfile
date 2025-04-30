# By JJAV 2025
ARG R_VERSION=4.4.3
FROM rocker/verse:${R_VERSION}

# Customized entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
