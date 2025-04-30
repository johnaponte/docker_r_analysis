# By JJAV 2025
ARG R_VERSION=4.4.3
FROM rocker/verse:${R_VERSION}

# Customized entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Modified rsession to have default user
COPY rsession.sh /rocker_scripts/rsession.sh
RUN chmod +x /rocker_scripts/rsession.sh

# Modify default user to a random number
ENV DEFAULT_USER=username=user$(head /dev/urandom | tr -dc a-z0-9 | head -c 8) 
ENV USER=${DEFAULT_USER}
RUN <<EOF
    if grep -q "1000" /etc/passwd; then
         userdel --remove "$(id -un 1000)";
    fi
    /rocker_scripts/default_user.sh "${DEFAULT_USER}"    
EOF

ENTRYPOINT ["/entrypoint.sh"]
